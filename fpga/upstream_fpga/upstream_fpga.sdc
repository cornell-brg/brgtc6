create_clock -name clk -period 20 [get_ports {clk}]
create_generated_clock -name cred_clk -source [get_ports clk] -divide_by 8 -phase 180.0 [get_ports cred_clk]
set_output_delay -clock cred_clk -max 2 [get_ports {cred_msg[*]}]
set_output_delay -clock cred_clk -min -1 [get_ports {cred_msg[*]}] -add_delay
set_output_delay -clock cred_clk -max 2 [get_ports cred_val]
set_output_delay -clock cred_clk -min -1 [get_ports cred_val] -add_delay
set_input_delay -clock clk -max 3 [get_ports {reset_n}]
set_input_delay -clock clk -min 1 [get_ports {reset_n}]
