<#
.SYNOPSIS
  Hello world for every target an installed fpc-toolchain build has units for (Windows hosts).
.DESCRIPTION
  smoke.ps1 -Fpc <path to fpc-<ver>.cmd> -Tree <toolchains\<ver>> -Out <dir> [-HostId x86_64-win64]
  Writes <Out>\smoke.tsv (target, compile, link, run, detail) and exits 1 on a compile failure, a link failure
  of an internal-class target, a run failure, or a missing run of a target listed in SMOKE_REQUIRE_RUN.
  Compile-only (-Cn) for embedded/freertos targets and for targets whose class is sdk or that need an Apple SDK.
  Runs: the host's own target, i386-win32 on x64, x86_64-win64 on ARM64 (emulation), wasm32 with wasmtime.
  Links every internal and binutils target (with the binutils shipped in cross\bin).
#>
param([Parameter(Mandatory)][string]$Fpc, [Parameter(Mandatory)][string]$Tree, [Parameter(Mandatory)][string]$Out,
      [string]$HostId)
$ErrorActionPreference = 'Stop'
if (-not $HostId) {
  $HostId = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -eq 'Arm64') { 'aarch64-win64' } else { 'x86_64-win64' }
}
New-Item -ItemType Directory -Force $Out | Out-Null
$cls = @{}; $margs = @{}
foreach ($l in Get-Content (Join-Path $Tree 'share\fpc-toolchain\targets.tsv')) {
  if ($l -match '^#') { continue }
  $f = $l -split "`t"; if ($f.Count -ge 5) { $cls[$f[0]] = $f[1]; $margs[$f[0]] = $f[4] }
}
$conf = Get-Content (Join-Path $Tree 'share\fpc-toolchain\toolchain.conf')
$req = (($conf | Select-String '^SMOKE_REQUIRE_RUN=(.*)$').Matches | ForEach-Object { $_.Groups[1].Value }) -split ',' | Where-Object { $_ }
$hello = "program hello; begin writeln('hello from ', {`$I %FPCTARGETCPU%}, '-', {`$I %FPCTARGETOS%}); end."
$unit = "unit hellounit; interface function Greeting: string; implementation function Greeting: string; begin Greeting := 'hello'; end; end."
$unitdir = @{}
foreach ($k in @($margs.Keys)) { foreach ($m in ($margs[$k] -split ';')) { if ($m -like 'UNITDIR=*') { $unitdir[$m.Substring(8)] = $k } } }
$rows = @("target`tcompile`tlink`trun`tdetail"); $bad = $false
foreach ($dir in Get-ChildItem (Join-Path $Tree 'units') -Directory) {
  $t = $dir.Name
  if ($unitdir.ContainsKey($t)) { $t = $unitdir[$t] }
  elseif ($t -notmatch '-') { $t = ($cls.Keys | Where-Object { $_ -like "*-$($dir.Name)" } | Select-Object -First 1) }
  if (-not $t) { continue }
  $cpu, $os = $t -split '-', 2
  $o = Join-Path $Out $t; New-Item -ItemType Directory -Force $o | Out-Null
  # compile inside the target's directory: some linker scripts name objects relative to it
  $opts = @("-P$cpu", "-T$os", '-FE.', '-FU.')
  $src = 'hello.pas'; Set-Content (Join-Path $o 'hello.pas') $hello; Set-Content (Join-Path $o 'hellounit.pas') $unit
  foreach ($m in ($margs[$t] -split ';')) {
    if ($m -like 'SUBARCH=*') { $opts += "-Cp$($m.Substring(8))" }
    if ($m -like 'CROSSOPT=*') { $opts += ($m.Substring(9) -split ' ') }
    if ($m -eq 'SMOKE=unit') { $src = 'hellounit.pas' } elseif ($m -like 'SMOKE=*') { $opts += ($m.Substring(6) -split ' ') }
  }
  $compileOnly = ($os -in @('embedded', 'freertos', 'darwin', 'ios', 'iphonesim')) -or ($cls[$t] -eq 'sdk') -or ($src -ne 'hello.pas')
  Push-Location $o
  & $Fpc @opts -Cn $src *> (Join-Path $o 'compile.log')
  $c = if ($LASTEXITCODE -eq 0) { 'ok' } else { 'FAIL' }
  $lk = '-'; $r = '-'; $detail = ''
  if ($c -eq 'ok' -and -not $compileOnly) {
    & $Fpc @opts $src *> (Join-Path $o 'link.log')
    $lk = if ($LASTEXITCODE -eq 0) { 'ok' } else { 'FAIL' }
  }
  Pop-Location
  if ($lk -eq 'ok') {
    $exe = Get-ChildItem $o -File | Where-Object { $_.Extension -in '.exe', '.wasm' } | Select-Object -First 1
    $runs = ($t -eq $HostId) -or ($t -eq 'i386-win32' -and $HostId -eq 'x86_64-win64') -or ($t -eq 'x86_64-win64' -and $HostId -eq 'aarch64-win64')
    # wasmtime 49 dropped wasi-threads, so wasip1threads binaries are linked, not run
    if ($exe -and $exe.Extension -eq '.wasm' -and $os -eq 'wasip1' -and (Get-Command wasmtime -ErrorAction SilentlyContinue)) {
      $txt = (& wasmtime run $exe.FullName) -join ' '; $r = if ($txt -match 'hello from') { 'ok' } else { 'FAIL' }; $detail = $txt
    } elseif ($exe -and $runs) {
      $txt = (& $exe.FullName) -join ' '; $r = if ($txt -match 'hello from') { 'ok' } else { 'FAIL' }; $detail = $txt
    } else { $r = 'no-emulator' }
  }
  if ($c -eq 'FAIL') { $detail = (Select-String -Path (Join-Path $o 'compile.log') -Pattern 'Error|Fatal' | Select-Object -First 1).Line }
  if ($lk -eq 'FAIL') { $detail = (Select-String -Path (Join-Path $o 'link.log') -Pattern 'Error|Fatal' | Select-Object -First 1).Line }
  if ($c -eq 'FAIL' -or $r -eq 'FAIL' -or ($lk -eq 'FAIL' -and $cls[$t] -in @('internal', 'binutils')) -or ($t -in $req -and $r -ne 'ok')) { $bad = $true }
  $rows += "$t`t$c`t$lk`t$r`t$detail"
  Write-Host ("{0,-24} compile={1,-4} link={2,-5} run={3,-11} {4}" -f $t, $c, $lk, $r, $detail)
}
$rows | Set-Content (Join-Path $Out 'smoke.tsv')
if ($bad) { Write-Error 'smoke failed'; exit 1 }
'smoke ok'
