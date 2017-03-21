module io_init_monitor (
    input  wire rst,
    input  wire clk,
    input  wire init_mon_ena,
    output wire init_mon_done,
    output wire spi_clk,
    output wire spi_mosi,
    output wire mon_cs,
    output wire mon_n_reset);
    
    localparam WIDTH = 32;
    localparam END_ADDR = 11;
    localparam IDLE         = 5'b00001; 
    localparam START_SPI    = 5'b00010;
    localparam WRITE_DATA   = 5'b00100;
    localparam INC_ADDR     = 5'b01000; 
    localparam FINISHED     = 5'b10000;
    
    reg rst_lcl;
    reg [4:0] state, next_state;
    reg start_tx;
    wire done_tx;
    wire spi_clk_n;
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
    assign mon_n_reset = 0;
    assign spi_clk = ~spi_clk_n;
    
    io_spi #(
        .WIDTH      (WIDTH), 
        .FLIP       (0),
        .SCLK_TIME  (4)) 
    io_spi_monitor (
        .rst        (rst_lcl),
        .clk        (clk),
        .start_tx   (start_tx),
        .done_tx    (done_tx),
        .spi_clk    (spi_clk_n),
        .spi_mosi   (spi_mosi),
        .spi_cs     (mon_cs),
        .spi_miso   (0),
        .tx_data    (rom_data),
        .rx_data    ());
    
    /***************************************************************************
    * Monitor initialisation state machine.
    ***************************************************************************/   
    always @(posedge clk)
        if (rst_lcl)    state <= IDLE;
        else            state <= next_state;
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE       : if (init_mon_ena)        next_state = START_SPI; 
            START_SPI  :                          next_state = WRITE_DATA;
            WRITE_DATA : if (done_tx & last_addr) next_state = FINISHED;
                         else if (done_tx)        next_state = INC_ADDR;
            INC_ADDR   :                          next_state = START_SPI;
            FINISHED   : if (~init_mon_ena)       next_state = IDLE;
            default    : next_state = IDLE;
        endcase
    end
    
    assign init_mon_done = state == FINISHED;
    
    
    /***************************************************************************
    * Synchronous rom implementation.
    ***************************************************************************/
    assign last_addr = rom_addr == END_ADDR; 
        
    always @(posedge clk) begin
        if (state == IDLE)          
            rom_addr <= 0;
        else if (state == INC_ADDR) 
            rom_addr <= rom_addr + 1;  
        rom_data <= mem[rom_addr];
        start_tx <= state == START_SPI;
    end
    
    initial begin
        mem[00] = 32'h000AFFFF;
        mem[01] = 32'h010A0000;
        mem[02] = 32'h010B8080;
        mem[03] = 32'h010D8000;
        mem[04] = 32'h010E0B16;
        mem[05] = 32'h010F0A08;
        mem[06] = 32'h01100B16;
        mem[07] = 32'h01110A08;
        mem[08] = 32'h01120C18;
        mem[09] = 32'h01130AF1;
        mem[10] = 32'h01140C18;
        mem[11] = 32'h01150AF1;
    end
    
endmodule
