module io_init_dac (
    input  wire rst,
    input  wire clk,
    input  wire init_dac_ena,
    output wire init_dac_done,
    output wire spi_sclk,
    output wire spi_sdata,
    output wire dac_n_en);
    
    localparam WIDTH        = 16; 
    localparam END_ADDR     = 31;
    localparam IDLE         = 5'b00001; 
    localparam START_SPI    = 5'b00010;
    localparam WRITE_DATA   = 5'b00100;
    localparam INC_ADDR     = 5'b01000; 
    localparam FINISHED     = 5'b10000;
    
    reg rst_lcl;
    reg start_tx;
    wire done_tx;
    wire last_addr;
    reg [7:0] rom_addr;
    reg [4:0] state; 
    reg [4:0] next_state;
    reg [WIDTH-1:0] mem [END_ADDR:0]; 
    reg [WIDTH-1:0] rom_data;

    /***************************************************************************
    * Local reset.
    ***************************************************************************/
    always @(posedge clk)
        rst_lcl <= rst;
        
    /***************************************************************************
    * SPI driver.
    ***************************************************************************/ 
    io_spi #(
        .WIDTH      (WIDTH), 
        .FLIP       (0),
        .SCLK_TIME  (4)) 
    io_spi_ads (
        .rst        (rst_lcl),
        .clk        (clk),
        .start_tx   (start_tx),
        .done_tx    (done_tx),
        .spi_clk    (spi_sclk),
        .spi_mosi   (spi_sdata),
        .spi_cs     (dac_n_en),
        .spi_miso   (1'b0),
        .tx_data    (rom_data),
        .rx_data    ());
        
    /***************************************************************************
    * DAC initialisation state machine.
    ***************************************************************************/    
    always @(posedge clk)
        if (rst_lcl)    state <= IDLE;
        else            state <= next_state;
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE       : if (init_dac_ena)        next_state = START_SPI; 
            START_SPI  :                          next_state = WRITE_DATA;
            WRITE_DATA : if (done_tx & last_addr) next_state = FINISHED;
                         else if (done_tx)        next_state = INC_ADDR;
            INC_ADDR   :                          next_state = START_SPI;
            FINISHED   : if (~init_dac_ena)       next_state = IDLE;
            default    : next_state = IDLE;
        endcase
    end
    
    assign init_dac_done = state == FINISHED;
    
    
    /***************************************************************************
    * Synchronous rom implementation.
    ***************************************************************************/
    assign last_addr = rom_addr == END_ADDR; 
        
    always @(posedge clk) begin
        if (state == IDLE)          rom_addr <= 0;
        else if (state == INC_ADDR) rom_addr <= rom_addr + 1;  
        rom_data <= mem[rom_addr];
        start_tx <= state == START_SPI;
    end
    
    initial begin
        mem[00] = 16'h0070;
        // mem[01] = 16'h0101; // lower latency, more harmonics
        mem[01] = 16'h0121; // high latency, less harmonics
        mem[02] = 16'h0200;
        mem[03] = 16'h0310;
        mem[04] = 16'h04FF;
        mem[05] = 16'h0500;
        mem[06] = 16'h0600;
        mem[07] = 16'h0700;
        mem[08] = 16'h0800;
        mem[09] = 16'h0955;
        mem[10] = 16'h0AAA;
        mem[11] = 16'h0B55;
        mem[12] = 16'h0CAA;
        mem[13] = 16'h0D55;
        mem[14] = 16'h0EAA;
        mem[15] = 16'h0F55;
        mem[16] = 16'h10AA;
        mem[17] = 16'h1124;
        mem[18] = 16'h1202;
        mem[19] = 16'h13C2;
        mem[20] = 16'h1400;
        mem[21] = 16'h1500;
        mem[22] = 16'h1600;
        mem[23] = 16'h1700;
        mem[24] = 16'h1803;
        mem[25] = 16'h1900;
        mem[26] = 16'h1A00;
        mem[27] = 16'h1B00;
        mem[28] = 16'h1C00;
        mem[29] = 16'h1D00;
        mem[30] = 16'h1E24;
        mem[31] = 16'h1F00;
    end
    
endmodule
