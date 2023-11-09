create_clock -period 3.000 -name clk -waveform {0.000 2.000} [get_ports clk]
set_input_delay -clock [get_clocks clk] -min -add_delay 5.000 [get_ports scl]
set_input_delay -clock [get_clocks clk] -max -add_delay 2.000 [get_ports scl]
set_input_delay -clock [get_clocks clk] -min -add_delay 5.000 [get_ports sda]
set_input_delay -clock [get_clocks clk] -max -add_delay 2.000 [get_ports sda]
set_output_delay -clock [get_clocks clk] -min -add_delay 0.000 [get_ports led]
set_output_delay -clock [get_clocks clk] -max -add_delay -7.000 [get_ports led]
set_output_delay -clock [get_clocks clk] -min -add_delay 1.000 [get_ports scl]
set_output_delay -clock [get_clocks clk] -max -add_delay -7.000 [get_ports scl]
set_output_delay -clock [get_clocks clk] -min -add_delay 1.000 [get_ports sda]
set_output_delay -clock [get_clocks clk] -max -add_delay -7.000 [get_ports sda]


set_property IOB TRUE [get_ports sda]
set_property IOB TRUE [get_ports scl]
set_property IOB TRUE [get_ports led]

