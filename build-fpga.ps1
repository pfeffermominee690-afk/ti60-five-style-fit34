param(
    [ValidateSet('main','line','autoboot')][string]$Target = 'main',
    [string]$EfinityHome = 'D:\FPGA\Efinity\2025.1'
)
$ErrorActionPreference = 'Stop'
$env:EFINITY_HOME = $EfinityHome
$project = switch ($Target) { 'line' { 'line-demo/fpga' } 'autoboot' { 'autoboot/fpga' } default { 'fpga' } }
Push-Location (Join-Path $PSScriptRoot $project)
try {
    & (Join-Path $EfinityHome 'bin/efx_run.bat') ti60f225_oob.xml --flow compile
    if ($LASTEXITCODE -ne 0) { throw 'FPGA compilation failed.' }
} finally { Pop-Location }
