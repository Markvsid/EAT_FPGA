# Target-specific evidence requires a confirmed part and a real Vivado installation.
# Usage: vivado -mode batch -source rtl/platform/vivado_ooc_candidate.tcl \
#        -tclargs eat_platform_wrapper <confirmed-part> <python-executable> [route]
# OOC timing does not establish PS/DMA/board timing or board power.
if {$argc < 3 || $argc > 4} {
  error "Required arguments: top, confirmed Vivado part, Python executable, optional route"
}
set top [lindex $argv 0]
set part [lindex $argv 1]
set python [lindex $argv 2]
set do_route [expr {$argc == 4}]
if {$do_route && [lindex $argv 3] ne "route"} {error "Fourth argument must be route"}
set root [file normalize [file join [file dirname [info script]] ../..]]
if {[catch {exec $python [file join $root rtl/scripts/check_scaffold.py] --require-implemented $top} reason]} {
  error "Implementation gate failed: $reason"
}
set output [file join $root rtl/build vivado $top]
file mkdir $output
set metadata [open [file join $output run_metadata.txt] w]
puts $metadata "Vivado: [version -short]\nPart: $part\nTop: $top\nRoute requested: $do_route\nCandidate period: 6.667 ns\nMode: out-of-context, no PS/DMA/board"
close $metadata
set manifest [open [file join $root rtl/sources.f] r]
set sources [split [string trim [read $manifest]] "\n"]
close $manifest
foreach source $sources {read_vhdl -vhdl2008 [file join $root $source]}
read_xdc [file join $root rtl/constraints/core_clock_candidate.xdc]
synth_design -mode out_of_context -top $top -part $part
report_utilization -hierarchical -file [file join $output synthesized_utilization.rpt]
report_timing_summary -file [file join $output synthesized_timing.rpt]
report_ram_utilization -file [file join $output synthesized_ram.rpt]
write_checkpoint -force [file join $output synthesized.dcp]
if {$do_route} {
  opt_design
  place_design
  phys_opt_design
  route_design
  report_route_status -file [file join $output route_status.rpt]
  report_utilization -hierarchical -file [file join $output routed_utilization.rpt]
  report_timing_summary -report_unconstrained -file [file join $output routed_timing.rpt]
  report_drc -file [file join $output routed_drc.rpt]
  report_methodology -file [file join $output routed_methodology.rpt]
  write_checkpoint -force [file join $output routed.dcp]
}
