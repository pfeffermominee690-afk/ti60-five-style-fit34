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

reset_timing
if {[get_timing_model] ne "I3"} {error "Incorrect timing model"}
puts "AUDIT_TIMING_MODEL=[get_timing_model]"
read_sdc cdc-physical-audit.sdc
report_cdc -details -file uncut-cdc.rpt
report_timing -from_clock core_clk -to_clock hdmi_tx_slow_clk -npaths 100 -nworst 1 -detail full_path -file cdc-core-hdmi.rpt
report_timing -from_clock hdmi_tx_slow_clk -to_clock core_clk -npaths 100 -nworst 1 -detail full_path -file cdc-hdmi-core.rpt
report_timing -from_clock i_mipi_rx_pclk -to_clock vid_clk_dvi2 -npaths 100 -nworst 1 -detail full_path -file cdc-mipi-raw.rpt
report_timing -from_clock vid_clk_dvi2 -to_clock i_mipi_rx_pclk -npaths 100 -nworst 1 -detail full_path -file cdc-raw-mipi.rpt
exit
