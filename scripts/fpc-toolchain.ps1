<#
.SYNOPSIS
  Select and check side-by-side FPC toolchains installed by install.ps1.
.DESCRIPTION
  fpc-toolchain.ps1 list
  fpc-toolchain.ps1 env <version|identity> | env -Lock toolchain.lock   -> prints a PATH assignment
  fpc-toolchain.ps1 which <version|identity>
  fpc-toolchain.ps1 check -Lock toolchain.lock                          -> exit 1 unless `fpc -iW` matches
  Usage: Invoke-Expression (& fpc-toolchain.ps1 env -Lock toolchain.lock)
#>
param([Parameter(Position = 0)][string]$Command = 'list', [Parameter(Position = 1)][string]$Which, [string]$Lock)
$ErrorActionPreference = 'Stop'
$root = if ($env:FPC_TOOLCHAIN_ROOT) { $env:FPC_TOOLCHAIN_ROOT } else { Split-Path -Parent $PSScriptRoot }
$tc = Join-Path $root 'toolchains'
function LockValue([string]$file, [string]$key) {
  foreach ($line in Get-Content $file) { if ($line -match "^\s*$([regex]::Escape($key))\s*=\s*`"?([^`"]*)`"?\s*$") { return $Matches[1] } }
}
function TreeBin([string]$id) {
  $d = Join-Path $tc $id
  if (-not (Test-Path $d)) { throw "$id is not installed under $root" }
  $h = (Get-ChildItem (Join-Path $d 'bin') -Directory | Select-Object -First 1).Name
  return (Join-Path $d "bin\$h")
}
if ($Lock) { $Which = LockValue $Lock 'identity' }
switch ($Command) {
  'list' { Get-ChildItem $tc | ForEach-Object { if ($_.LinkType -eq 'Junction') { "* $($_.Name) -> $($_.Target)" } else { "  $($_.Name)" } } }
  'env' { "`$env:PATH = '$(TreeBin $Which);' + `$env:PATH" }
  'which' { TreeBin $Which }
  'check' {
    $want = LockValue $Lock 'identity'
    $got = (& fpc -iW).Trim()
    if ($got -ne $want) { Write-Error "fpc on PATH is $got, toolchain.lock wants $want"; exit 1 }
    "ok $got"
  }
  default { throw "unknown command $Command" }
}
