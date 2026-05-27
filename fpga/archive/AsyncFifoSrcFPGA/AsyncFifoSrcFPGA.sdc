create_clock -name clk -period 20 [get_ports {clk}]
create_generated_clock -name i_clk -source [get_ports clk] -divide_by 2 -phase 180.0 [get_ports i_clk]
set_output_delay -clock i_clk -max 2 [get_ports {out[*]}]
set_output_delay -clock i_clk -min -1 [get_ports {out[*]}] -add_delay
set_input_delay -clock clk -max 3 [get_ports {reset_n}]
set_input_delay -clock clk -min 1 [get_ports {reset_n}]
