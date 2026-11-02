param([string]$EfinityHome = 'D:\FPGA\Efinity\2025.1')
$ErrorActionPreference = 'Stop'
$env:EFINITY_HOME = $EfinityHome
Push-Location (Join-Path $PSScriptRoot 'fpga')
try {
    & (Join-Path $EfinityHome 'bin/efx_run.bat') ti60f225_oob.xml --flow compile
    if ($LASTEXITCODE -ne 0) { throw 'FPGA compilation failed.' }
} finally { Pop-Location }
