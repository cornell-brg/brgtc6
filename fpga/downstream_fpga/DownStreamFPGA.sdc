create_clock -name cred_clk -period 40 [get_ports {cred_clk}]
create_clock -name clk -period 20 [get_ports {clk}]
set_input_delay -clock cred_clk -max 12 [get_ports {cred_msg[*]}]
set_input_delay -clock cred_clk -min 5 [get_ports {cred_msg[*]}] -add_delay
set_input_delay -clock cred_clk -max 12 [get_ports {cred_val[*]}]
set_input_delay -clock cred_clk -min 5 [get_ports {cred_val[*]}] -add_delay

