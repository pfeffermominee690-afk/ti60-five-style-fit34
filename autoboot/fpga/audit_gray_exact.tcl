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
exit
