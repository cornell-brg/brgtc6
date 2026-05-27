create_clock -name i_clk -period 40 [get_ports {i_clk}]
create_clock -name o_clk -period 20 [get_ports {o_clk}]
set_input_delay -clock i_clk -max 12 [get_ports {in[*]}]
set_input_delay -clock i_clk -min 5 [get_ports {in[*]}] -add_delay

