#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/build/autoboot-tests"
mkdir -p "$out"
cd "$root/autoboot/tests"
iverilog -g2012 -s tb_boot_spi -o "$out/spi" tb_boot_spi.sv ../fpga/rtl/apb_boot_spi.sv
vvp "$out/spi"
if [ "${1:-}" = "--full" ]; then
    verilator --binary --timing -j 4 -Wno-fatal --top-module tb --Mdir "$out/obj_boot" tb.sv soc_functional.v ../fpga/rtl/apb_boot_spi.sv > "$out/build.log" 2>&1
    "$out/obj_boot/Vtb"
    "$out/obj_boot/Vtb" +corrupt
fi
