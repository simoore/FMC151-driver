/*******************************************************************************
* rst           Set high while the ADC is unconfigured.
* clk           The clock from the ADC. Nominally 245.76MHz.
* clk_200MHz    The clock for IDELAYCTRL.
* cha_p         The ADC bus for channel A (positive).
* cha_n         The ADC bus for channel A (negative).
* chb_p         The ADC bus for channel B (positive).
* chb_n         The ADC bus for channel B (negative).
* adc_a_buf     The digitised sample for channel A.
* adc_b_buf     The digitised sample for channel B.
* start         Start delay calibration signal.
* done          Finished dealy calibration signal.
*******************************************************************************/
module io_main_adc (
    input wire rst, 
    input wire clk, 
    input wire clk_200MHz,
    input wire [6:0] cha_p, 
    input wire [6:0] cha_n, 
    input wire [6:0] chb_p, 
    input wire [6:0] chb_n,
    output reg [13:0] adc_a_buf, 
    output reg [13:0] adc_b_buf,
    input wire start,  
    output wire done);
    
    genvar ii;
    reg rst_lcl;
    wire done_a; 
    wire done_b; 
    wire ce_a; 
    wire ce_b;
    wire [6:0] cha; 
    wire [6:0] chb; 
    wire [6:0] cha_dly; 
    wire [6:0] chb_dly;
    wire [13:0] adc_a; 
    wire [13:0] adc_b;
    
    /***************************************************************************
    * Local reset.
    ***************************************************************************/
    always @(posedge clk)
        rst_lcl <= rst;
            
    /***************************************************************************
    * Buffers for the differential signals from the analog card.
    ***************************************************************************/
    generate for (ii = 0; ii < 7; ii = ii + 1) begin : adc_buffers
    
        IBUFDS #(
            .IOSTANDARD     ("LVDS_25"), 
            .IBUF_LOW_PWR   ("FALSE"), 
            .DIFF_TERM      ("TRUE")) 
        IBUFDS_cha (
            .O      (cha[ii]), 
            .I      (cha_p[ii]), 
            .IB     (cha_n[ii]));
        
        IBUFDS #(
            .IOSTANDARD     ("LVDS_25"), 
            .IBUF_LOW_PWR   ("FALSE"), 
            .DIFF_TERM      ("TRUE")) 
        IBUFDS_chb (
            .O      (chb[ii]), 
            .I      (chb_p[ii]), 
            .IB     (chb_n[ii]));
        
    end endgenerate
    
    /***************************************************************************
    * Align the timing of the ADC data. Delays are in increments of 78ps. This 
    * uses the built in IDELAYE2 logic in the FPGA. One instance of IDELAYCTRL
    * needs to be instanced when using the delay logic. A calibration rountine 
    * is used to tune the delay.
    ***************************************************************************/
    IDELAYCTRL delay_controller (
        .RST    (rst_lcl), 
        .REFCLK (clk_200MHz), 
        .RDY    ());
   
    io_calibration calibration_cha (rst_lcl, clk, start, adc_a, ce_a, done_a);
    io_calibration calibration_chb (rst_lcl, clk, start, adc_b, ce_b, done_b);
    assign done = done_a && done_b;
    
    generate for (ii = 0; ii < 7; ii = ii + 1) begin : adc_delays
    
        IDELAYE2 #(
            .CINVCTRL_SEL           ("FALSE"),      
            .DELAY_SRC              ("IDATAIN"),    
            .HIGH_PERFORMANCE_MODE  ("TRUE"),       
            .IDELAY_TYPE            ("VARIABLE"),   
            .IDELAY_VALUE           (0),           
            .PIPE_SEL               ("FALSE"),      
            .REFCLK_FREQUENCY       (200),        
            .SIGNAL_PATTERN         ("DATA"))
        delay_cha (
            .CNTVALUEOUT (),	                 
            .DATAOUT     (cha_dly[ii]),       
            .C           (clk),                  
            .CE          (ce_a),        
            .CINVCTRL    (0),				    
            .CNTVALUEIN  (0),		            
            .DATAIN      (0),					
            .IDATAIN     (cha[ii]),				
            .INC         (1),					
            .LD          (rst_lcl),        
            .LDPIPEEN    (0),					
            .REGRST      (0));					
            
        IDELAYE2 #(
            .CINVCTRL_SEL           ("FALSE"),      
            .DELAY_SRC              ("IDATAIN"),   
            .HIGH_PERFORMANCE_MODE  ("TRUE"),       
            .IDELAY_TYPE            ("VARIABLE"),      
            .IDELAY_VALUE           (0),           
            .PIPE_SEL               ("FALSE"),     
            .REFCLK_FREQUENCY       (200),        
            .SIGNAL_PATTERN         ("DATA"))
        delay_chb (
            .CNTVALUEOUT (),	                  
            .DATAOUT     (chb_dly[ii]),         
            .C           (clk),                  
            .CE          (ce_b),        
            .CINVCTRL    (0),				   
            .CNTVALUEIN  (0),		           
            .DATAIN      (0),					
            .IDATAIN     (chb[ii]),			
            .INC         (1),					
            .LD          (rst_lcl),        
            .LDPIPEEN    (0),					
            .REGRST      (0));
    
    end endgenerate;
    
    /***************************************************************************
    * Deserialise the doube data rate (DDR) ADC data.
    ***************************************************************************/
    generate for (ii = 0; ii < 7; ii = ii + 1) begin : adc_ddrs
    
        IDDR #(
            .DDR_CLK_EDGE   ("OPPOSITE_EDGE"), 
            .INIT_Q1        (1'b0), 
            .INIT_Q2        (1'b0), 
            .SRTYPE         ("SYNC")) 
        IDDR_a (
            .Q1     (adc_a[2*ii]), 
            .Q2     (adc_a[2*ii+1]), 
            .C      (clk), 
            .CE     (1), 
            .D      (cha_dly[ii]), 
            //.R      (rst_lcl), 
            .R      (0), 
            .S      (0));
        
        IDDR #(
            .DDR_CLK_EDGE   ("OPPOSITE_EDGE"), 
            .INIT_Q1        (1'b0), 
            .INIT_Q2        (1'b0), 
            .SRTYPE         ("SYNC")) 
        IDDR_b (
            .Q1     (adc_b[2*ii]), 
            .Q2     (adc_b[2*ii+1]), 
            .C      (clk), 
            .CE     (1), 
            .D      (chb_dly[ii]), 
            //.R      (rst_lcl), 
            .R      (0), 
            .S      (0));
            
    end endgenerate;
    
    /***************************************************************************
    * ADC output buffer.
    ***************************************************************************/
    always @(posedge clk)
        if (rst_lcl) begin
            adc_a_buf <= 0;
            adc_b_buf <= 0;
        end else begin
            adc_a_buf <= adc_a;
            adc_b_buf <= adc_b;
        end
        
endmodule
