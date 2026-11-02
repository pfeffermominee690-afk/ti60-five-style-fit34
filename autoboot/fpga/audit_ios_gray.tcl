set_timing_model I3
reset_timing
if {[get_timing_model] ne "I3"} {error "Incorrect timing model"}
read_sdc audited.sdc
check_timing -verbose -file audited-coverage.rpt
reset_timing
read_sdc cdc-physical-audit.sdc
set graypins [get_pins -regexp {^(u_video/.*(rg1|wg1)|raw_stream/(rg1|wg1))\[[0-9]+\]~FF\|D$}]
puts "GRAY_ENDPOINT_COUNT=[llength $graypins]"
puts "GRAY_ENDPOINTS=$graypins"
if {[llength $graypins] != 46} {error "Missing expected FIFO Gray endpoints"}
report_timing -to $graypins -npaths 1000 -nworst 1 -detail full_path -file cdc-gray-endpoints.rpt
set counterpins [get_pins -regexp {^u_video/(cg1|mg1|display/uf1)\[[0-9]+\]~FF\|D$}]
puts "COUNTER_ENDPOINT_COUNT=[llength $counterpins]"
report_timing -to $counterpins -npaths 1000 -nworst 1 -detail full_path -file cdc-counter-endpoints.rpt
exit
