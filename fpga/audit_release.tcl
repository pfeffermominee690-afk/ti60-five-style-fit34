set_timing_model I3
reset_timing
if {[get_timing_model] ne "I3"} {error "Incorrect timing model"}
puts "AUDIT_TIMING_MODEL=[get_timing_model]"
read_sdc audited.sdc
report_clocks -file audited-clocks.rpt
report_timing_summary -file audited-timing.rpt
report_timing -setup -npaths 30 -detail full_path -file audited-paths.rpt
report_timing -hold -npaths 30 -detail full_path -file audited-hold.rpt
report_cdc -details -file audited-cdc.rpt
report_timing -from_clock core_clk -to_clock core_clk -setup -npaths 30 -detail full_path -file audited-core-paths.rpt
report_timing -from_clock hdmi_tx_slow_clk -to_clock hdmi_tx_slow_clk -setup -npaths 20 -detail full_path -file audited-hdmi-paths.rpt
check_timing

check_timing -verbose -file audited-coverage.rpt
set_timing_model I3
reset_timing
read_sdc cdc-physical-audit.sdc
set graypins {}
set p [get_pins {u_video/capture/queue/wg1[0]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/wg1[1]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/wg1[2]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/wg1[3]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/wg1[4]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/wg1[5]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/wg1[6]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/wg1[7]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/wg1[8]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/wg1[9]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/rg1[0]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/rg1[1]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/rg1[2]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/rg1[3]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/rg1[4]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/rg1[5]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/rg1[6]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/rg1[7]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/rg1[8]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/capture/queue/rg1[9]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/wg1[0]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/wg1[1]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/wg1[2]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/wg1[3]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/wg1[4]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/wg1[5]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/wg1[6]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/wg1[7]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/wg1[8]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/wg1[9]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/rg1[0]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/rg1[1]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/rg1[2]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/rg1[3]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/rg1[4]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/rg1[5]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/rg1[6]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/rg1[7]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/rg1[8]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {u_video/display/queue/rg1[9]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {raw_stream/wg1[0]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {raw_stream/wg1[1]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {raw_stream/wg1[2]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {raw_stream/rg1[0]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {raw_stream/rg1[1]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
set p [get_pins {raw_stream/rg1[2]~FF|D}]
if {[llength $p] != 1} {error "Missing FIFO endpoint"}
set graypins [concat $graypins $p]
puts "GRAY_ENDPOINT_COUNT=[llength $graypins]"
report_timing -to $graypins -npaths 1000 -nworst 1 -detail full_path -file cdc-gray-endpoints.rpt

set_timing_model I3
reset_timing
read_sdc audited.sdc
set_input_delay -clock_fall -clock jtag_inst1_TCK -max 100 [get_ports {jtag_inst1_TDI}]
set_input_delay -clock_fall -clock jtag_inst1_TCK -min 0 [get_ports {jtag_inst1_TDI}]
report_timing -from [get_ports {jtag_inst1_TDI}] -setup -npaths 10 -detail full_path -file audited-jtag-input-setup.rpt
report_timing -from [get_ports {jtag_inst1_TDI}] -hold -npaths 10 -detail full_path -file audited-jtag-input-hold.rpt
reset_timing
read_sdc cdc-physical-audit.sdc
set counterpins {}
set p [get_pins {u_video/cg1[0]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[1]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[2]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[3]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[4]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[5]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[6]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[7]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[8]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[9]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[10]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[11]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[12]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[13]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[14]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[15]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[16]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[17]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[18]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[19]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[20]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[21]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[22]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[23]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[24]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[25]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[26]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[27]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[28]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[29]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[30]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/cg1[31]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[0]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[1]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[2]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[3]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[4]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[5]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[6]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[7]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[8]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[9]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[10]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[11]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[12]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[13]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[14]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[15]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[16]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[17]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[18]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[19]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[20]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[21]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[22]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[23]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[24]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[25]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[26]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[27]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[28]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[29]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[30]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/mg1[31]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[0]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[1]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[2]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[3]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[4]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[5]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[6]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[7]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[8]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[9]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[10]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[11]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[12]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[13]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[14]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[15]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[16]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[17]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[18]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[19]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[20]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[21]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[22]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[23]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[24]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[25]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[26]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[27]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[28]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[29]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[30]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
set p [get_pins {u_video/display/uf1[31]~FF|D}]
if {[llength $p] != 1} {error "Missing counter endpoint"}
set counterpins [concat $counterpins $p]
puts "COUNTER_ENDPOINT_COUNT=[llength $counterpins]"
report_timing -to $counterpins -npaths 1000 -nworst 1 -detail full_path -file cdc-counter-endpoints.rpt
exit
