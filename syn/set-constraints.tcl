# Clock period (in ns)
set CLK_PERIOD 2

# Inputs delay
# divide clk period by two
set INPUT_DELAY [expr $CLK_PERIOD / 2]

# Output delay
set OUTPUT_DELAY [expr $CLK_PERIOD / 2]

# Output load
set OLOAD [load_of tcbn65lpwc/BUFFD24/I]


# Reset signal is a false path
set_false_path -from [get_ports rst_ni]

# Clock
create_clock -name "CLK" -period $CLK_PERIOD [get_ports clk_i]

# Input and output delays
set EXCLUDED_INPUTS [get_ports {rst_ni}]
set DELAYED_INPUTS [remove_from_collection [all_inputs] $EXCLUDED_INPUTS]
set_input_delay -clock CLK -max $INPUT_DELAY $DELAYED_INPUTS
set_output_delay -clock CLK -max $OUTPUT_DELAY [all_outputs]
set_load $OLOAD [all_outputs]

# Clean up
unset INPUT_DELAY EXCLUDED_INPUTS DELAYED_INPUTS
