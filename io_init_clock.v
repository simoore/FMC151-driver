module io_init_clock (
    input  wire rst,
    input  wire clk,
    input  wire init_cdce_ena,
    output wire init_cdce_done,
    output wire spi_sclk,
    output wire spi_sdata,
    output wire cdce_n_en,
    input  wire cdce_miso,
    output wire ref_en,
    output wire cdce_n_reset,
    output wire cdce_n_pd);
    
    localparam WIDTH = 32;
    localparam END_ADDR = 12;
    localparam ENABLE_INTERNAL_CLOCK = 1;
    localparam CLOCK_NOT_RESET = 1;
    localparam CLOCK_NOT_POWER_DOWN  = 1;
    
    localparam IDLE         = 5'b00001; 
    localparam START_SPI    = 5'b00010;
    localparam WRITE_DATA   = 5'b00100;
    localparam INC_ADDR     = 5'b01000; 
    localparam FINISHED     = 5'b10000;
    
    reg [4:0] state, next_state;
    reg rst_lcl;
    reg start_tx;
    wire done_tx;
    wire last_addr;
    reg [7:0] rom_addr;
    reg [WIDTH-1:0] mem [END_ADDR:0];
    reg [WIDTH-1:0] rom_data;
    
    /***************************************************************************
    * Local reset.
    ***************************************************************************/
    always @(posedge clk)
        rst_lcl <= rst;
        
    /***************************************************************************
    * Digital IO and SPI driver.
    ***************************************************************************/
    assign ref_en         = ENABLE_INTERNAL_CLOCK;
    assign cdce_n_reset   = CLOCK_NOT_RESET;
    assign cdce_n_pd      = CLOCK_NOT_POWER_DOWN;
     
    io_spi #(
        .WIDTH      (WIDTH), 
        .FLIP       (1),
        .SCLK_TIME  (4)) 
    io_spi_cdce (
        .rst        (rst_lcl),
        .clk        (clk),
        .start_tx   (start_tx),
        .done_tx    (done_tx),
        .spi_clk    (spi_sclk),
        .spi_mosi   (spi_sdata),
        .spi_cs     (cdce_n_en),
        .spi_miso   (cdce_miso),
        .tx_data    (rom_data),
        .rx_data    ());
    
    /***************************************************************************
    * Clock initialisation state machine.
    ***************************************************************************/   
    always @(posedge clk)
        if (rst_lcl)    state <= IDLE;
        else            state <= next_state;
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE       : if (init_cdce_ena)       next_state = START_SPI; 
            START_SPI  :                          next_state = WRITE_DATA;
            WRITE_DATA : if (done_tx & last_addr) next_state = FINISHED;
                         else if (done_tx)        next_state = INC_ADDR;
            INC_ADDR   :                          next_state = START_SPI;
            FINISHED   : if (~init_cdce_ena)      next_state = IDLE;
            default    : next_state = IDLE;
        endcase
    end
    
    assign init_cdce_done = state == FINISHED;
    
    /***************************************************************************
    * The initialisation memory and address counter.
    ***************************************************************************/
    assign last_addr = rom_addr == END_ADDR; 
    
    always @(posedge clk) begin
        if (state == IDLE)          rom_addr <= 0;
        else if (state == INC_ADDR) rom_addr <= rom_addr + 1;  
        rom_data <= mem[rom_addr];
        start_tx <= state == START_SPI;
    end
    
    initial begin
        mem[00] = 32'h683C0250;
        mem[01] = 32'h68000271;
        mem[02] = 32'h83800002;
        mem[03] = 32'h68000003;
        mem[04] = 32'hE9800004;
        mem[05] = 32'h68000005;
        mem[06] = 32'h68000006;
        mem[07] = 32'h83400157;
        mem[08] = 32'h680001D8;
        mem[09] = 32'h68050C49;
        mem[10] = 32'h05FC270A;
        mem[11] = 32'h9000048B;
        mem[12] = 32'h0000180C;
    end

endmodule
