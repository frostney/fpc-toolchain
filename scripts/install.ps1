<#
.SYNOPSIS
  Install an fpc-toolchain build side by side with other FPC versions (Windows).

.DESCRIPTION
  install.ps1 [-Identity 3.3.1+1 (or its tag 3.3.1-b1) | -Lock toolchain.lock | -From file.zip] [-Root DIR] [-Repo OWNER/NAME]
              [-HostId x86_64-win64|aarch64-win64] [-Targets i386-win32,wasm32-wasip1|all|none]
              [-SumsSha256 HEX] [-NoActivate] [-Default]

  -Targets     cross targets whose units to add (zip unit archives of the release, or next to -From);
               default: the lock's `targets`, else none (the host's own units are always installed).
  -SumsSha256  sha256 of the release's SHA256SUMS file (the lock's `sha256sums`): pins every asset.

  Layout (Root, default %LOCALAPPDATA%\fpc-toolchains):
    toolchains\<identity>\              the unpacked build (FPC Windows layout: bin\<host>\, units\<target>\)
    toolchains\<version>                junction -> <identity> (active build of that version)
    bin\fpc-<version>.cmd               front-end: the active build's fpc.exe reading only its own fpc.cfg
    bin\fpc-toolchain.ps1               helper (env / which / list / check)
  FPC on Windows looks for fpc.cfg next to the compiler (bin\<host>\fpc.cfg), after .\fpc.cfg,
  %PPC_CONFIG_PATH%, %USERPROFILE%\fpc.cfg and %ALLUSERSPROFILE%\fpc.cfg; the front-ends pass -n to
  ignore those. `fpc -V<version>` is not used on Windows: select a version with the front-end or PATH.
#>
param(
  [string]$Identity,
  [string]$Lock,
  [string]$From,
  [string]$Root = $(if ($env:FPC_TOOLCHAIN_ROOT) { $env:FPC_TOOLCHAIN_ROOT } else { Join-Path $env:LOCALAPPDATA 'fpc-toolchains' }),
  [string]$Repo,
  [string]$HostId,
  [string]$Targets,
  [string]$SumsSha256,
  [switch]$NoActivate,
  [switch]$Default
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function LockValue([string]$file, [string]$key) {
  foreach ($line in Get-Content $file) {
    if ($line -match "^\s*$([regex]::Escape($key))\s*=\s*`"?([^`"]*)`"?\s*$") { return $Matches[1] }
  }
  return $null
}

if (-not $HostId) {
  $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
  $HostId = switch ($arch) { 'X64' { 'x86_64-win64' } 'Arm64' { 'aarch64-win64' } default { throw "unsupported architecture $arch" } }
}
if ($Lock) {
  $Identity = LockValue $Lock 'identity'
  if (-not $Identity) { throw "$Lock has no identity" }
  if (-not $Repo) { $Repo = LockValue $Lock 'repo' }
  if (-not $SumsSha256) { $SumsSha256 = LockValue $Lock 'sha256sums' }
  if (-not $Targets) { $Targets = LockValue $Lock 'targets' }
}

# identity "<ver>+N" (what `fpc -iW` prints) <-> release tag "<ver>-bN"
if ($Identity -and $Identity -notmatch '\+' -and $Identity -match '-b(\d+)$') { $Identity = $Identity -replace '-b(\d+)$', '+$1' }
$Tag = if ($Identity) { $Identity.Replace('+', '-b') } else { $null }

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("fpc-toolchain-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
$script:sums = @{}
$script:base = $null
$script:srcDir = $null

function ReadSums([string]$file) {
  foreach ($l in Get-Content $file) {
    $p = $l -split '\s+'
    if ($p.Count -ge 2) { $script:sums[$p[1].TrimStart('*')] = $p[0].ToLower() }
  }
}
function Fetch([string]$asset) {
  $dst = Join-Path $tmp $asset
  if ($script:base) { Invoke-WebRequest -Uri "$($script:base)/$asset" -OutFile $dst }
  elseif (Test-Path (Join-Path $script:srcDir $asset)) { Copy-Item (Join-Path $script:srcDir $asset) $dst }
  else { throw "no $asset next to $From" }
  if ($script:sums.Count -gt 0) {
    if (-not $script:sums.ContainsKey($asset)) { throw "$asset not listed in SHA256SUMS" }
    $got = (Get-FileHash -Algorithm SHA256 $dst).Hash.ToLower()
    if ($got -ne $script:sums[$asset]) { throw "sha256 mismatch for $asset" }
  }
  return $dst
}

try {
  if (-not $From) {
    if (-not $Identity) { throw 'say what to install: -Identity, -Lock or -From' }
    $ver = ($Identity -split '[-+]')[0]
    if (-not $Repo) { $Repo = "frostney/fpc-toolchain-$ver" }
    $assetId = "fpc-$Tag"
    $script:base = "https://github.com/$Repo/releases/download/$Tag"
    $sumsFile = Join-Path $tmp 'SHA256SUMS'
    Invoke-WebRequest -Uri "$($script:base)/SHA256SUMS" -OutFile $sumsFile
    if ($SumsSha256 -and ((Get-FileHash -Algorithm SHA256 $sumsFile).Hash.ToLower() -ne $SumsSha256.ToLower())) {
      throw "SHA256SUMS of $Identity does not match the pinned sha256sums"
    }
    ReadSums $sumsFile
    Write-Host "downloading $($script:base)/$assetId-$HostId.zip"
    $archive = Fetch "$assetId-$HostId.zip"
  } else {
    $archive = (Resolve-Path $From).Path
    $script:srcDir = Split-Path -Parent $archive
    $assetId = [System.IO.Path]::GetFileNameWithoutExtension($archive) -replace "-$([regex]::Escape($HostId))$", ''
    foreach ($f in Get-ChildItem $script:srcDir -Filter 'SHA256SUMS*') { ReadSums $f.FullName }
    $name = Split-Path -Leaf $archive
    if ($script:sums.ContainsKey($name) -and ((Get-FileHash -Algorithm SHA256 $archive).Hash.ToLower() -ne $script:sums[$name])) {
      throw "sha256 mismatch for $archive"
    }
  }

  $x = Join-Path $tmp 'x'
  Expand-Archive -Path $archive -DestinationPath $x
  $src = (Get-ChildItem -Directory $x | Select-Object -First 1).FullName
  $info = @{}
  foreach ($l in Get-Content (Join-Path $src 'share\fpc-toolchain\BUILDINFO')) { $k, $v = $l -split '=', 2; $info[$k] = $v }
  $bident = $info['identity']; $bhost = $info['host']
  if ($Identity -and $Identity -ne $bident) { throw "archive is $bident, expected $Identity" }
  if ($bhost -ne $HostId) { throw "archive is for $bhost, this host is $HostId" }
  $ver = ($bident -split '[-+]')[0]

  $tc = Join-Path $Root 'toolchains'; $bin = Join-Path $Root 'bin'
  New-Item -ItemType Directory -Force -Path $tc, $bin | Out-Null
  $dest = Join-Path $tc $bident
  if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
  Move-Item $src $dest

  if ($Targets -and $Targets -ne 'none') {
    $list = if ($Targets -eq 'all') {
      # every target this host ships (targets.tsv hosts column)
      Get-Content (Join-Path $dest 'share\fpc-toolchain\targets.tsv') | Where-Object { $_ -notmatch '^#' } | ForEach-Object {
        $f = $_ -split "`t"; if ($f.Count -ge 3 -and $f[1] -ne 'excluded' -and ((',' + $f[2] + ',') -like "*,$HostId,*")) { $f[0] }
      }
    } else { $Targets -split '[, ]+' }
    foreach ($t in $list) {
      if (-not $t -or $t -eq $HostId) { continue }
      $z = Fetch "$assetId-units-$t.zip"
      Expand-Archive -Path $z -DestinationPath (Join-Path $dest 'units') -Force
      Write-Host "  + units $t"
    }
  }

  $hb = Join-Path $dest "bin\$HostId"
  $cfg = Join-Path $hb 'fpc.cfg'
  & (Join-Path $hb 'fpcmkcfg.exe') -d "basepath=$dest" -o $cfg | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'fpcmkcfg failed' }
  # cross targets shipped on Windows hosts use FPC's internal tools or clang (targets.tsv): no -XP prefix
  Add-Content -Path $cfg -Value "`n# --- fpc-toolchain ${bident}: cross targets use FPC's internal tools or clang`n#IFDEF FPC_CROSSCOMPILING`n-XP`n#ENDIF"

  if (-not $NoActivate) {
    $link = Join-Path $tc $ver
    if (Test-Path $link) { (Get-Item $link).Delete() }
    New-Item -ItemType Junction -Path $link -Target $dest | Out-Null
  }
  foreach ($j in Get-ChildItem $tc | Where-Object { $_.LinkType -eq 'Junction' }) {
    $v = $j.Name
    $exe = Join-Path $j.FullName "bin\$HostId\fpc.exe"
    $c = Join-Path $j.FullName "bin\$HostId\fpc.cfg"
    Set-Content -Path (Join-Path $bin "fpc-$v.cmd") -Encoding ASCII -Value "@echo off`r`nrem fpc-toolchain front-end for FPC $v (generated)`r`n`"$exe`" -n `"@$c`" %*`r`n"
  }
  if ($Default) {
    Set-Content -Path (Join-Path $bin 'fpc.cmd') -Encoding ASCII -Value "@echo off`r`n`"$(Join-Path $tc "$ver\bin\$HostId\fpc.exe")`" %*`r`n"
  }
  $helper = Join-Path $dest 'share\fpc-toolchain\fpc-toolchain.ps1'
  if (Test-Path $helper) { Copy-Item $helper (Join-Path $bin 'fpc-toolchain.ps1') -Force }

  $ppc = Get-ChildItem $hb -Filter 'ppc*.exe' | Where-Object { $_.Name -notlike 'ppcross*' } | Select-Object -First 1
  $got = (& $ppc.FullName -iW).Trim()
  if ($got -ne $bident) { throw "compiler reports $got, expected $bident" }
  Write-Host "installed $bident -> $dest"
  if (-not (($env:PATH -split ';') -contains $bin)) { Write-Host "add $bin to PATH (fpc-$ver)" }
  foreach ($c in @((Join-Path $env:USERPROFILE 'fpc.cfg'), (Join-Path $env:ALLUSERSPROFILE 'fpc.cfg'), '.\fpc.cfg')) {
    if (Test-Path $c) { Write-Warning "$c takes precedence over the toolchain's fpc.cfg for plain fpc calls" }
  }
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
