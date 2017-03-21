# FMC151 Driver for the Xilinx KC705 Development Board

The [analog IO card FMC151](http://www.4dsp.com/FMC151.php) is a daughter card
for a Xilinx FPGA that provides two ADC channels and two DAC channels for high
speed analog IO. This project provides the HDL code to initialise and operate 
the analog card. The code was developed to operate on the 
[Xilinx KC705 developement board](https://www.xilinx.com/products/boards-and-kits/ek-k7-kc705-g.html)
which houses a Kintex-7 FPGA.

The [contraints](io_contraints.xdc) are written for the analog card to be 
inserted into the FMC LPC connector on the KC705 board. The IP blocks 
[io_clk_sys.xci](io_clk_sys.xci) and [io_clk_adc.xci](io_clk_adc.xci) configure
the clocking resources and were generated in Vivado 2015.4. io_clk_sys.xci 
configures the 200MHz differential input clock on the KC705 board to provide a 
single 200MHz clock output. io_clk_adc.xci configures the 245.76MHz 
differential input clock on the FMC151 card to provide 245.76MHz and 491.52MHz 
clock outputs.

[io_main.v](io_main.v) is the top level project file. To connect your system
to the analog card, use the signals `adc_a`, `adc_b`, `dac_a`, & `dac_b`. 
They are synchronised to the clock signal `clk_245_76MHz` and the reset 
signal `rst_sync_adc`. All the ADCs and DACs sample at 245.76MSPS with the 
initialisation modules provided in this project.


