# Proposed core timing target only. NOT a board/pin/clock-domain signoff.
# The template's approximate 150 MHz goal is not an achieved frequency.
create_clock -name core_clk -period 6.667 [get_ports clk_i]
# No false paths or multicycle exceptions are justified at skeleton stage.
# PS clock generation, reset, AXI clock relation and board constraints need review.
