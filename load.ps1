param(
    [ValidateSet('outdoor','defaults')][string]$Profile = 'outdoor',
    [switch]$VerifyOnly,
    [string]$EfinityHome = 'D:\FPGA\Efinity\2025.1',
    [string]$RiscvSdk = 'D:\FPGA\Efinity\riscv-ide-2025.1',
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
& $Python (Join-Path $PSScriptRoot 'tools/verify.py')
if ($LASTEXITCODE -ne 0) { throw 'Package verification failed.' }
if ($VerifyOnly) { return }
if (Get-Process -Name openocd,riscv-none-embed-gdb -ErrorAction SilentlyContinue) {
    throw 'Close the existing board debugger before loading.'
}
$env:EFINITY_HOME = $EfinityHome
& (Join-Path $EfinityHome 'pgm/bin/ftdi_pgm.bat') (Join-Path $PSScriptRoot 'prebuilt/fit34.bit') --mode jtag
if ($LASTEXITCODE -ne 0) { throw 'JTAG loading failed.' }
if ($Profile -eq 'outdoor') {
    Start-Sleep -Seconds 5
    & $Python (Join-Path $PSScriptRoot 'tools/apply_outdoor.py') --sdk $RiscvSdk
    if ($LASTEXITCODE -ne 0) { throw 'Exposure profile failed. See build/runtime.' }
}
Write-Output 'Loading complete.'
