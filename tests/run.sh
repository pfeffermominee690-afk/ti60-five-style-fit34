#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
gcc -std=c11 -Wall -Wextra -O2 tests/test_ae.c -o build/tests/test_ae
build/tests/test_ae
iverilog -g2012 -s tb_bayer -o build/tests/bayer tests/tb_bayer.sv fpga/rtl/debayer/raw_to_rgb.v
vvp build/tests/bayer
iverilog -g2012 -s tb -o build/tests/norm tests/tb_norm_reference.sv fpga/engine/p2_norm_reference_lane.sv
vvp build/tests/norm

gcc -std=c11 -Wall -Wextra -O2 tests/test_gesture_motion.c -o build/tests/gesture
build/tests/gesture
cd fpga
iverilog -g2012 -s tb_labels -o ../build/tests/labels ../tests/display/tb_labels.sv rtl/fps_osd.sv
vvp ../build/tests/labels
