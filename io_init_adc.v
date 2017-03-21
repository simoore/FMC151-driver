module io_init_adc (
    input  wire rst,
    input  wire clk,
    input  wire init_ads_ena,
    output wire init_ads_done,
    output wire spi_clk,
    output wire spi_mosi,
    output wire ads_n_en,
    output wire adc_reset,
    input  wire adc_calibrated);
    
    localparam WIDTH = 16;
    localparam IDLE = 6'b000001;
    localparam RESET = 6'b000010;
    localparam START_SPI = 6'b000100; 
    localparam WRITE_DATA = 6'b001000;
    localparam INC_ADDR = 6'b010000; 
    localparam FINISHED = 6'b100000; 
    
    reg [5:0] state; 
    reg [5:0] next_state;
    reg rst_lcl;
    reg start_tx; 
    wire done_tx; 
    wire spi_clk_n;
    wire last_addr;
    reg [7:0] rom_addr;
    wire [7:0] end_addr;
    reg  [WIDTH-1:0] mem_test [18:0]; 
    reg  [WIDTH-1:0] mem_normal [1:0];
    reg  [WIDTH-1:0] rom_data;
    
    /***************************************************************************
    * Local reset.
    ***************************************************************************/
    always @(posedge clk)
        rst_lcl <= rst;
            
    /***************************************************************************
    * Digital IO and SPI Driver.
    ***************************************************************************/
    assign adc_reset = (state == RESET) && !adc_calibrated;
    assign spi_clk   = ~spi_clk_n;
          
    io_spi #(
        .WIDTH      (WIDTH), 
        .FLIP       (0),
        .SCLK_TIME  (4)) 
    io_spi_ads (
        .rst        (rst_lcl),
        .clk        (clk),
        .start_tx   (start_tx),
        .done_tx    (done_tx),
        .spi_clk    (spi_clk_n),
        .spi_mosi   (spi_mosi),
        .spi_cs     (ads_n_en),
        .spi_miso   (1'b0),
        .tx_data    (rom_data),
        .rx_data    ());
        
    /***************************************************************************
    * ADC initialisation state machine.
    ***************************************************************************/
    always @(posedge clk)
        if (rst) state <= IDLE;
        else     state <= next_state;
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE       : if (init_ads_ena)          next_state = RESET;
            RESET      :                            next_state = START_SPI;
            START_SPI  :                            next_state = WRITE_DATA;
            WRITE_DATA : if (done_tx & last_addr)   next_state = FINISHED;
                         else if (done_tx)          next_state = INC_ADDR;
            INC_ADDR   :                            next_state = START_SPI;
            FINISHED   : if (init_ads_ena == 0)     next_state = IDLE;
            default    : next_state = IDLE;
        endcase
    end
    
    assign init_ads_done = state == FINISHED;
    
    
    /***************************************************************************
    * Synchronous rom implementation.
    ***************************************************************************/
    assign end_addr = adc_calibrated ? 1 : 18;
    assign last_addr = rom_addr == end_addr; 
            
    always @(posedge clk) begin
        if (state == IDLE)          rom_addr <= 0;
        else if (state == INC_ADDR) rom_addr <= rom_addr + 1;  
        rom_data <= adc_calibrated ? mem_normal[rom_addr] : mem_test[rom_addr];
        start_tx <= state == START_SPI;
    end
            
    initial begin
        mem_test[00] = 16'h0080;
        mem_test[01] = 16'h2000;
        mem_test[02] = 16'h3F00;
        mem_test[03] = 16'h4008;
        mem_test[04] = 16'h4180;
        mem_test[05] = 16'h4400;
        mem_test[06] = 16'h5044;
        mem_test[07] = 16'h5100;
        mem_test[08] = 16'h5200;
        mem_test[09] = 16'h5300;
        mem_test[10] = 16'h55C0;
        mem_test[11] = 16'h5700;
        mem_test[12] = 16'h6204;
        mem_test[13] = 16'h6300;
        mem_test[14] = 16'h6600;
        mem_test[15] = 16'h68C0;
        mem_test[16] = 16'h6A00;
        mem_test[17] = 16'h7504;
        mem_test[18] = 16'h7600;
        mem_normal[0] = 16'h6200;
        mem_normal[1] = 16'h7500;
    end
    
endmodule
