#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
root="$PWD"
out="$root/build/tests/rotation"
mkdir -p "$out"
for test in tb_rotate tb_rotation_recovery; do
  verilator --binary --timing -Wno-fatal -j 2 --top-module tb \
    --Mdir "$out/$test" "tests/rotation/$test.sv" \
    fpga/rtl/rgb_pair_display.sv fpga/rtl/async_fifo.sv fpga/rtl/p2_rgb24_stream.sv \
    > "$out/$test-build.log" 2>&1
  "$out/$test/Vtb" | tee "$out/$test.log"
done
verilator --binary --timing -Wno-fatal -j 2 --top-module tb_rotate_osd \
  --Mdir "$out/tb_rotate_osd" tests/rotation/tb_rotate_osd.sv \
  tests/rotation/fps_osd_reference.sv fpga/rtl/fps_osd.sv \
  > "$out/tb_rotate_osd-build.log" 2>&1
cd "$root/fpga"
"$out/tb_rotate_osd/Vtb_rotate_osd" | tee "$out/tb_rotate_osd.log"
