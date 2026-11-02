#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
out="$root/build/line-tests"
mkdir -p "$out"
cd "$root/line-demo/fpga"
gcc -std=c11 -Wall -Wextra -O2 ../tests/test_sensor.c -o "$out/sensor"
"$out/sensor"
iverilog -g2012 -s tb_bayer -o "$out/bayer" ../tests/tb_bayer.sv rtl/debayer/raw_to_rgb.v
vvp "$out/bayer"
iverilog -g2012 -s tb_verify -o "$out/verify" ../tests/tb_verify.sv rtl/capture_verifier.sv
vvp "$out/verify"
iverilog -g2012 -s tb_osd -o "$out/osd" ../tests/tb_osd.sv rtl/capture_osd.sv
vvp "$out/osd"
verilator --binary --timing -j 4 -Wno-fatal --top-module tb_sobel_quality --Mdir "$out/obj_quality" ../tests/tb_sobel_quality.sv rtl/capture_sobel.sv > "$out/quality-build.log" 2>&1
"$out/obj_quality/Vtb_sobel_quality"
verilator --binary --timing -j 4 -Wno-fatal --top-module tb_capture --Mdir "$out/obj_capture" ../tests/tb_capture.sv rtl/capture_sobel.sv rtl/capture_pipeline.sv rtl/capture_osd.sv rtl/capture_gray_counter.sv rtl/rgb_capture640.sv rtl/video_control.sv rtl/rgb_pair_display.sv rtl/p2_rgb24_stream.sv rtl/async_fifo.sv rtl/vga/vga_gen.v > "$out/capture-build.log" 2>&1
"$out/obj_capture/Vtb_capture"
"$out/obj_capture/Vtb_capture" +LINE
