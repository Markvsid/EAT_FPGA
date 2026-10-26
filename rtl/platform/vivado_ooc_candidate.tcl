# Draft out-of-context entry point. Every reachable stub is rejected first.
# Usage: vivado -mode batch -source rtl/platform/vivado_ooc_candidate.tcl \
#        -tclargs eat_mac_lane <confirmed-part> <python-executable>
if {$argc != 3} {
  error "Required arguments: top, confirmed Vivado part, Python executable"
}
set top [lindex $argv 0]
set part [lindex $argv 1]
set python [lindex $argv 2]
set root [file normalize [file join [file dirname [info script]] ../..]]
if {[catch {exec $python [file join $root rtl/scripts/check_scaffold.py] --require-implemented $top} reason]} {
  error "Implementation gate failed: $reason"
}
file mkdir [file join $root rtl/build]
set manifest [open [file join $root rtl/sources.f] r]
set sources [split [string trim [read $manifest]] "\n"]
close $manifest
foreach source $sources {
  read_vhdl -vhdl2008 [file join $root $source]
}
read_xdc [file join $root rtl/constraints/core_clock_candidate.xdc]
synth_design -mode out_of_context -top $top -part $part
# Resource reports are evidence only after real implementation; no bitstream flow here.
report_utilization -hierarchical -file [file join $root rtl/build/ooc_utilization.rpt]
report_timing_summary -file [file join $root rtl/build/ooc_timing.rpt]
