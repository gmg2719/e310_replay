#
# Copyright 2018 Ettus Research, A National Instruments Company
# SPDX-License-Identifier: LGPL-3.0
#
# Description: Timing constraints for the USRP E31X
#


###############################################################################
# Input Clocks
###############################################################################

# 10MHz / PPS References
create_clock -period 100.000 -name pps_ext [get_nets PPS_EXT_IN]

create_clock -period 100.000 -name gps_pps [get_nets GPS_PPS]

# TCXO clock 40 MHz
create_clock -period 25.000 -name TCXO_CLK [get_nets TCXO_CLK]
set_input_jitter TCXO_CLK 0.100

###############################################################################
# Rename Clocks
###############################################################################

create_clock -period 10.000 -name bus_clk [get_pins {e31x_ps_bd_inst/processing_system7_0/inst/PS7_i/FCLKCLK[0]}]
set_input_jitter bus_clk 0.300

create_clock -period 25.000 -name clk40 [get_pins {e31x_ps_bd_inst/processing_system7_0/inst/PS7_i/FCLKCLK[1]}]
set_input_jitter clk40 0.750

#create_clock -period 5.000 #             -name bus_clk [get_pins {e31x_ps_bd_inst/processing_system7_0/inst/PS7_i/FCLKCLK[3]}]
#set_input_jitter bus_clk 0.150

###############################################################################
# Timing Constraints for E310 daughter board signals
###############################################################################
# CAT_DATA_CLK is the data clock from AD9361, sample rate dependent with a max rate of 61.44 MHz
create_clock -period 16.276 -name CAT_DATA_CLK [get_ports CAT_DATA_CLK]
# Model variable duty cycle as jitter.
set_input_jitter CAT_DATA_CLK 1.628

# Generate DAC output clock
create_generated_clock -name CAT_FB_CLK -source [get_pins e310_io/oddr_clk/C] -multiply_by 1 [get_ports CAT_FB_CLK]

# Asynchronous clock domains
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks CAT_DATA_CLK] -group [get_clocks -include_generated_clocks bus_clk] -group [get_clocks -include_generated_clocks TCXO_CLK]

set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks *clk_200M_o] -group [get_clocks -include_generated_clocks pps_ext] -group [get_clocks -include_generated_clocks gps_pps]


#TODO: I don't think this was getting used on E310
# Logically exclusive clocks in catcodec capture interface. These two clocks are the input to a BUFG mux that
# drives radio_clk, meaning only one of the two can drive radio_clk at a time.
#set_clock_groups -logically_exclusive #  -group [get_clocks -include_generated_clocks {clk0}] #  -group [get_clocks -include_generated_clocks {clkdv}]

# Setup ADC (AD9361) interface constraints.

set_input_delay -clock [get_clocks CAT_DATA_CLK] -max 5.700 [get_ports {CAT_P0_D* CAT_RX_FRAME}]
set_input_delay -clock [get_clocks CAT_DATA_CLK] -min 4.500 [get_ports {CAT_P0_D* CAT_RX_FRAME}]
set_input_delay -clock [get_clocks CAT_DATA_CLK] -clock_fall -max -add_delay 5.700 [get_ports {CAT_P0_D* CAT_RX_FRAME}]
set_input_delay -clock [get_clocks CAT_DATA_CLK] -clock_fall -min -add_delay 4.500 [get_ports {CAT_P0_D* CAT_RX_FRAME}]


set_output_delay -clock CAT_FB_CLK -max 5.500 [get_ports {CAT_P1_D* CAT_TX_FRAME}]
set_output_delay -clock CAT_FB_CLK -min 4.500 [get_ports {CAT_P1_D* CAT_TX_FRAME}]
set_output_delay -clock CAT_FB_CLK -clock_fall -max -add_delay 5.500 [get_ports {CAT_P1_D* CAT_TX_FRAME}]
set_output_delay -clock CAT_FB_CLK -clock_fall -min -add_delay 4.500 [get_ports {CAT_P1_D* CAT_TX_FRAME}]

# TODO: CAT SPI
# Xilinx doesn't allow you to fully constrain EMIO because the internal SPI
# clock is not accessible. So delay constraints are used to limit the delays to
# compatible values.

# Transceiver SPI
set_max_delay -datapath_only -from [get_pins e31x_ps_bd_inst/processing_system7_0/inst/PS7_i/EMIOSPI0MO] -to [get_ports CAT_MOSI] 10.000
set_min_delay -to [get_ports CAT_MOSI] 1.000
#
set_max_delay -datapath_only -from [get_pins e31x_ps_bd_inst/processing_system7_0/inst/PS7_i/EMIOSPI0SCLKO] -to [get_ports CAT_SCLK] 10.000
set_min_delay -to [get_ports CAT_SCLK] 1.000
#
set_max_delay -datapath_only -from [get_pins {e31x_ps_bd_inst/processing_system7_0/inst/PS7_i/EMIOSPI0SSON[0]}] -to [get_ports CAT_CS] 10.000
set_min_delay -to [get_ports CAT_CS] 1.000
#
set_max_delay -datapath_only -from [get_ports CAT_MISO] -to [get_pins e31x_ps_bd_inst/processing_system7_0/inst/PS7_i/EMIOSPI0MI] 10.000
set_min_delay -from [get_ports CAT_MISO] -to [get_pins e31x_ps_bd_inst/processing_system7_0/inst/PS7_i/EMIOSPI0MI] 1.000

###############################################################################
# PPS and Ref Clk Input Timing
###############################################################################

# Asynchronous clock domains
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks bus_clk] -group [get_clocks -include_generated_clocks pps_ext] -group [get_clocks -include_generated_clocks gps_pps]

# TCXO DAC SPI
# 12 MHz SPI clock rate
set_max_delay -datapath_only -from [all_registers -edge_triggered] -to [get_ports TCXO_DAC*] 40.000
set_min_delay -from [all_registers -edge_triggered] -to [get_ports TCXO_DAC*] 1.000

# User GPIO
set_max_delay -datapath_only -from [all_registers -edge_triggered] -to [get_ports PL_GPIO*] 15.000
set_min_delay -from [all_registers -edge_triggered] -to [get_ports PL_GPIO*] 5.000
set_max_delay -datapath_only -from [get_ports PL_GPIO*] -to [all_registers -edge_triggered] 15.000
set_min_delay -from [get_ports PL_GPIO*] -to [all_registers -edge_triggered] 5.000

# GPIO muxing
set_max_delay -datapath_only -from [get_pins {e31x_core_inst/fp_gpio_src_reg_reg[*]/C}] -to [get_clocks CAT_DATA_CLK] 16.276

###############################################################################
# False Paths
###############################################################################

# Synchronizer core false paths
set_false_path -to [get_pins -hierarchical -filter {NAME =~ */synchronizer_false_path/stages[0].value_reg[0][*]/D}]
set_false_path -to [get_pins -hierarchical -filter {NAME =~ */synchronizer_false_path/stages[0].value_reg[0][*]/S}]

# USR_ACCESS build date
set_false_path -through [get_pins {usr_access_i/DATA[*]}]

###############################################################################
## Asynchronous paths
###############################################################################
set_false_path -from [get_ports CAT_CTRL_OUT]
set_false_path -to [get_ports CAT_RESET]
set_false_path -to [get_ports RX*_BANDSEL*]
set_false_path -to [get_ports TX_BANDSEL*]
set_false_path -to [get_ports TX_ENABLE*]
set_false_path -to [get_ports LED_*]
set_false_path -to [get_ports VCRX*]
set_false_path -to [get_ports VCTX*]
set_false_path -from [get_ports ONSWITCH_DB]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 4 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER true [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL true [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list u_mig_7series_0/u_mig_7series_0_mig/u_ddr3_infrastructure/CLK]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 1 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list ddr3_running]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets ddr3_axi_clk]
