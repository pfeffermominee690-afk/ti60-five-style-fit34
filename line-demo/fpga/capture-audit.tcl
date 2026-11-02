set_timing_model I3
reset_timing
read_sdc audited.sdc
if {[get_timing_model] ne "I3"} {error "Wrong timing model"}
report_timing_summary -file capture-timing.rpt
report_timing -setup -npaths 30 -detail full_path -file capture-setup.rpt
report_timing -hold -npaths 20 -detail full_path -file capture-hold.rpt
report_cdc -details -file capture-cdc.rpt
check_timing -verbose -file capture-coverage.rpt
