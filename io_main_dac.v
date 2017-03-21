/*******************************************************************************
* rst           Resets the DAC drivers registers. In the default config, this 
*               will be set when the ADC clock generator is not locked. 
* clk           The clock signal is twice the system sampling frequency. This is 
*               because it takes one clock cycle to push the data out on one 
*               channel and there are two channels. In the default config this 
*               will be at 491.52MHz.
* clk_2         The clock signal at the sampling frequency. Nominally 245.76MHz.
* dac_a         The data for channel a.
* dac_b         The data for channel b. 
* dac_dclk_p    The clock signal to the DAC (positive).
* dac_dclk_n    The clock signal to the DAC (negative).
* dac_frame_p   The frame signal to the DAC (positive).
* dac_frame_n   The frame signal to the DAC (negative).
* dac_tx_en     The transmission enable signal to the DAC.
* dac_data_p    The data bus to the DAC (positive).
* dac_data_n    The data bus to the DAC (negative).
*******************************************************************************/
module io_main_dac (
    input  wire rst, 
    input  wire clk, 
    input  wire clk_2,
    input  wire [15:0] dac_a, 
    input  wire [15:0] dac_b,
    output wire dac_clk_p, 
    output wire dac_clk_n,
    output wire dac_frame_p, 
    output wire dac_frame_n,
    output reg  dac_tx_en,
    output wire [7:0] dac_data_p, 
    output wire [7:0] dac_data_n);
    
    genvar      ii;
    reg         rst_lcl;
    wire        dac_clk;
    reg         dac_rst; 
    reg         dac_frame;
    wire [7:0]  dac_data;
    reg [10:0]  cnt;
    reg [15:0]  dac_a_buf; 
    reg [15:0]  dac_b_buf;
    wire [15:0] dac_temp; 
    wire [15:0] dac_a_neg;
    
    /***************************************************************************
    * Input buffer.
    ***************************************************************************/
    always @(posedge clk_2) begin
        rst_lcl <= rst;
        dac_a_buf <= dac_a;
        dac_b_buf <= dac_b;
    end
    
    /***************************************************************************
    * Two's comeplement safe negatation. Channel C needs to be negated due to
    * a design flaw. However full precision negation requires an extra bit
    * to accommodate the negation of the most negative value. When this occurs
    * the ADC instead saturates at the most positive value to prevent any large 
    * jumps in voltage.
    ***************************************************************************/
    assign dac_temp = ~dac_a_buf + 16'h0001;
    assign dac_a_neg = (dac_temp == 16'h8000) ? 16'h7FFF : dac_temp; 
    
    /***************************************************************************
    * Reset logic for the DAC.
    ***************************************************************************/
    always @(posedge clk_2) begin
        if (rst_lcl)                cnt <= 0;
        else if (cnt < 2047)        cnt <= cnt + 1;
        
        if (rst_lcl)                dac_rst <= 1;
        else if (cnt[10:1] == 255)  dac_rst <= 1;
        else                        dac_rst <= 0;
        
        if (cnt[10:1] == 511)       dac_frame <= 1;
        else                        dac_frame <= 0;
        
        if (cnt[10:1] == 1023)      dac_tx_en <= 1;
        else                        dac_tx_en <= 0;
    end
    
    OBUFDS #(
        .IOSTANDARD("LVDS_25"), 
        .SLEW("SLOW")) 
    OBUFDS_dac_frame (
        .O  (dac_frame_p), 
        .OB (dac_frame_n), 
        .I  (dac_frame));

    /***************************************************************************
    * Clock forwarding. The use of a double data rate (DDR) regsiter to generate 
    * the output clock signals is to prevent the additional consumption of 
    * clocking resources. The ouput clock signal is differential.
    ***************************************************************************/
    OSERDESE2 #(
        .DATA_RATE_OQ("DDR"), 
        .DATA_RATE_TQ("DDR"), 
        .DATA_WIDTH(4),
        .INIT_OQ(1'b0), 
        .INIT_TQ(1'b0), 
        .SERDES_MODE("MASTER"), 
        .SRVAL_OQ(0), 
        .SRVAL_TQ(0), 
        .TBYTE_CTL("FALSE"), 
        .TBYTE_SRC("FALSE"), 
        .TRISTATE_WIDTH(4))
    OSERDESE2_dac_clock (
        .OFB(), 
        .OQ(dac_clk),
        .SHIFTOUT1(),
        .SHIFTOUT2(),
        .TBYTEOUT(),
        .TFB(),
        .TQ(), 
        .CLK(clk), 
        .CLKDIV(clk_2),
        .D1(1),  
        .D2(0), 
        .D3(1), 
        .D4(0), 
        .D5(0), 
        .D6(0), 
        .D7(0), 
        .D8(0), 
        .OCE(1), 
        .RST(dac_rst), 
        .SHIFTIN1(0), 
        .SHIFTIN2(0), 
        .T1(0), 
        .T2(0), 
        .T3(0), 
        .T4(0), 
        .TBYTEIN(0), 
        .TCE(0));
    
    OBUFDS #(
        .IOSTANDARD("LVDS_25"), 
        .SLEW("SLOW")) 
    OBUFDS_dac_dclk (
        .O  (dac_clk_p), 
        .OB (dac_clk_n), 
        .I  (dac_clk));
    
    /***************************************************************************
    * Double data rate (DDR) registers. These registers store data on both the 
    * positive and negative edge of the clock. DDR is used for communication
    * to the DAC. The output data signals are differential.
    ***************************************************************************/
    generate for (ii = 0; ii < 8; ii = ii + 1) begin
            
        OSERDESE2 #(
            .DATA_RATE_OQ("DDR"), 
            .DATA_RATE_TQ("DDR"), 
            .DATA_WIDTH(4),
            .INIT_OQ(1'b0), 
            .INIT_TQ(1'b0), 
            .SERDES_MODE("MASTER"), 
            .SRVAL_OQ(0), 
            .SRVAL_TQ(0), 
            .TBYTE_CTL("FALSE"), 
            .TBYTE_SRC("FALSE"), 
            .TRISTATE_WIDTH(4))
        OSERDESE2_dac_data (
            .OFB(), 
            .OQ(dac_data[ii]),
            .SHIFTOUT1(),
            .SHIFTOUT2(),
            .TBYTEOUT(),
            .TFB(),
            .TQ(), 
            .CLK(clk), 
            .CLKDIV(clk_2),            
            .D1(dac_a_neg[ii + 8]), 
            .D2(dac_a_neg[ii]), 
            .D3(dac_b_buf[ii + 8]), 
            .D4(dac_b_buf[ii]),
            .D5(0), 
            .D6(0), 
            .D7(0), 
            .D8(0), 
            .OCE(1), 
            .RST(dac_rst), 
            .SHIFTIN1(0), 
            .SHIFTIN2(0), 
            .T1(0), 
            .T2(0), 
            .T3(0), 
            .T4(0), 
            .TBYTEIN(0), 
            .TCE(0));
            
        OBUFDS #(
            .IOSTANDARD("LVDS_25"), 
            .SLEW("SLOW")) 
        OBUFDS_dac_data (
            .O  (dac_data_p[ii]), 
            .OB (dac_data_n[ii]), 
            .I  (dac_data[ii]));
        
    end endgenerate
    
endmodule
