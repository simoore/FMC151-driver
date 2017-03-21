module io_spi #(
    parameter WIDTH = 32, 
    parameter FLIP = 0,
    parameter SCLK_TIME = 4     // f_spi = f_clk/(2*(SCLK_TIME + 1))
    )(
    input  wire rst,
    input  wire clk,
    input  wire start_tx,
    output reg  done_tx,
    output reg  spi_clk,
    output wire spi_mosi,
    output reg  spi_cs,
    input  wire spi_miso,
    input  wire [WIDTH-1:0] tx_data,
    output reg  [WIDTH-1:0] rx_data);
    
    localparam IDLE        = 6'b000001;
    localparam QUIET       = 6'b000010;
    localparam HIGH        = 6'b000100;
    localparam READ        = 6'b001000;
    localparam LOW         = 6'b010000;
    localparam BUFFER      = 6'b100000;

    reg rst_lcl;
    wire last_read, at_zero, shift, quiet, low, buffer, idle;
    reg  [5:0] state, next_state;
    reg  [7:0] shift_counter, state_counter;
    reg  [WIDTH-1:0] shift_reg;
    
    /****************************************************************************
    * Local reset signal.
    ****************************************************************************/
    always @(posedge clk)
        rst_lcl <= rst;
            
    /****************************************************************************
    * Chip select register.
    ****************************************************************************/
    always @(posedge clk)
        if (!quiet) spi_cs <= 0;
        else        spi_cs <= 1;
    
    /****************************************************************************
    * SPI clock generation.
    ****************************************************************************/
    always @(posedge clk)
        if (low)   spi_clk <= 0;
        else       spi_clk <= 1;
           
    /***************************************************************************
    * Shift register.
    ***************************************************************************/ 
    assign last_read = shift_counter == 0;   
    assign spi_mosi = FLIP ? shift_reg[0] : shift_reg[WIDTH-1];
    
    always @(posedge clk) begin
        if (start_tx)   shift_counter <= WIDTH - 1;
        else if (shift) shift_counter <= shift_counter - 1;
        
        if (start_tx)   shift_reg <= tx_data;
        else if (shift) 
            if (FLIP)   shift_reg <= {spi_miso,shift_reg[WIDTH-1:1]};  
            else        shift_reg <= {shift_reg[WIDTH-2:0],spi_miso};    
    end

    /****************************************************************************
    * Output buffer.
    ****************************************************************************/
    always @(posedge clk) begin
        done_tx <= buffer;
        if (buffer) rx_data <= shift_reg;
    end
    
    /****************************************************************************
    * State machine counter.
    ****************************************************************************/
    assign at_zero = state_counter == 0;
    always @(posedge clk)
        if (at_zero | idle) state_counter <= SCLK_TIME;
        else                state_counter <= state_counter - 1;
                    
    /***************************************************************************
    * SPI state machine.
    ***************************************************************************/
    always @(posedge clk)
        if (rst) state <= IDLE;
        else     state <= next_state;
       
    always @(*) begin
        next_state = state;
        case (state)
            IDLE:      if (start_tx)            next_state = QUIET;
            QUIET:     if (at_zero)             next_state = LOW;
            LOW:       if (at_zero)             next_state = HIGH;
            HIGH:      if (at_zero & last_read) next_state = BUFFER;   
                       else if (at_zero)        next_state = READ;
            READ:                               next_state = LOW;
            BUFFER:                             next_state = IDLE;
        endcase
    end
        
    assign shift = (state == READ);
    assign quiet = (state == QUIET) || (state == IDLE) || (state == BUFFER);
    assign low = (state != HIGH);
    assign buffer = (state == BUFFER);
    assign idle = (state == IDLE);
    
endmodule
