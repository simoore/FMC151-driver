module i2c_master #(
    parameter input_clk = 200_000_000, // system clock speed in Hz
    parameter bus_clk   = 400_000      // speed the i2c bus in Hz
    ) (
    input clk,            // system clock
    input rst,            // active high reset
    input ena,            // latch in command
    input [6:0] addr,     // address of target slave
    input rw,             // '0' is write, '1' is read
    input [7:0] data_wr,  // data to write to slave
    output busy,          // indicates transaction in progress
    output load,          // load new data pulse
    output reg [7:0] data_rd, // data read from slave
    inout sda,            // serial data output of i2c bus
    inout scl);           // serial clock output of i2c bus

    localparam MAX_COUNT_CLK = input_clk/bus_clk/4;
    
    localparam READY    = 9'b000000001;
    localparam START    = 9'b000000010;
    localparam COMMAND  = 9'b000000100;
    localparam SLV_ACK1 = 9'b000001000;
    localparam WR       = 9'b000010000;
    localparam RD       = 9'b000100000;
    localparam SLV_ACK2 = 9'b001000000; 
    localparam MSTR_ACK = 9'b010000000; 
    localparam STOP     = 9'b100000000;
    
    reg rst_lcl;
    reg [8:0] state;
    reg [8:0] next_state;
    wire same_cmd;
    
    reg [7:0] count_clk; 
    reg [1:0] count_quad;   
    reg data_ce;            // clock enable for sda
    wire stretching;        
    
    reg scl_ce;         
    reg scl_ena;            // enables internal scl to output
    wire sda_int;           // internal sda
    wire sda_ena_n;         // enables internal sda to output
    
    reg [7:0] addr_rw;      // latched in address and read/write
    reg [7:0] data_tx;      // latched in data to write to slave
    reg [7:0] data_rx;      // data received from slave
    reg [7:0] bit_count;    // tracks bit number in transaction
    reg [7:0] data_rd_buf;  // latched read in data
    
    /***************************************************************************
    * Local reset.
    ***************************************************************************/
    always @(posedge clk)
        rst_lcl <= rst;
            
    /***************************************************************************
    * Generate the timing for the bus clock and the data clock. Both clocks are
    * the same frequency however they have an phase offset of 90 degrees. The
    * data clock is used for setting the data on SDA while the bus clock is for
    * SCL.
    ***************************************************************************/
    always @(posedge clk)
        if (rst_lcl) begin
            count_clk  <= 0;
            count_quad <= 0;
        end else if (count_clk == MAX_COUNT_CLK) begin
            count_clk  <= 0;    
            count_quad <= count_quad + 1;
        end else if (stretching == 0)
            count_clk  <= count_clk + 1;
            
    always @(posedge clk) begin
        if (count_clk == MAX_COUNT_CLK && count_quad == 0)  data_ce <= 1;
        else                                                data_ce <= 0;
    end
    
    assign stretching = (count_quad == 2'b10) && (scl == 0);
    
    /***************************************************************************
    * Set scl and sda outputs, when set to high impedance (1'bZ), either it will
    * be pulled high by an external resistor or the slave device will take 
    * control of the line.
    ***************************************************************************/
    assign sda = (sda_ena_n == 0) ? 0 : 1'bZ;
    assign sda_ena_n = (state == START || state == STOP) ? 0 : sda_int;
    assign sda_int = (state == COMMAND) ? addr_rw[bit_count] :
                     (state == WR)      ? data_tx[bit_count] :
                     (state == MSTR_ACK && same_cmd) ? 0 : 1;
                     
    /***************************************************************************
    * Serial clock. The serial clock must be Z to indicate start and stop 
    * states. External pull up resistors allow for the clock to go high.
    ***************************************************************************/
    always @(posedge clk) begin
        if (count_clk == MAX_COUNT_CLK && count_quad == 1)  scl_ce <= 1;
        else                                                scl_ce <= 0;
    end
        
    always @(posedge clk)
        if (rst_lcl)        scl_ena <= 0;
        else if (scl_ce)    scl_ena <= (state & (READY | STOP)) == 0; 
    
    assign scl = (scl_ena == 1 && count_quad[1] == 0) ? 0 : 1'bZ;

    /***************************************************************************
    * State machine and writing to sda and scl.
    ***************************************************************************/
    always @(posedge clk)
        if (rst_lcl)      state <= READY;
        else if (data_ce) state <= next_state;
    
    always @(*) begin
        next_state = state;
        case (state)
            READY:    if (ena == 1)         next_state = START;
            START:                          next_state = COMMAND;
            COMMAND:  if (bit_count == 0)   next_state = SLV_ACK1;
            SLV_ACK1: if (addr_rw[0] == 0)  next_state = WR;
                      else                  next_state = RD;
            WR:       if (bit_count == 0)   next_state = SLV_ACK2;
            RD:       if (bit_count == 0)   next_state = MSTR_ACK;
            SLV_ACK2: if (ena == 1)          
                        if (same_cmd == 1)  next_state = WR;
                        else                next_state = START;
                      else                  next_state = STOP;
            MSTR_ACK: if (ena == 1)          
                        if (same_cmd == 1)  next_state = WR;
                        else                next_state = START;
                      else                  next_state = STOP;
            STOP:                           next_state = READY;
        endcase
    end
    
    assign busy     = state != READY;
    assign load     = state == SLV_ACK2;
    assign same_cmd = addr_rw == {addr,rw};
    
    /***************************************************************************
    * Bit count buffer. Counts out the bits being transmitted in each byte.
    ***************************************************************************/
    always @(posedge clk) 
        if (data_ce)
            if (state == COMMAND || state == RD || state == WR) 
                    bit_count <= bit_count - 1;
            else    bit_count <= 7;
            
    /***************************************************************************
    * Command and data write buffers.
    ***************************************************************************/
    always @(posedge clk) 
        if (data_ce) begin
            if (state == START)     addr_rw <= {addr,rw};
            if (state == SLV_ACK1 || state == SLV_ACK2)  data_tx <= data_wr;
        end
    
    /***************************************************************************
    * Read data buffer.
    ***************************************************************************/
    always @(posedge clk)
        if (rst_lcl)                data_rd <= 0;
        else if (data_ce) begin
            if (state == MSTR_ACK)  data_rd <= data_rx;
            if (state == RD)        data_rx[bit_count] <= sda;
        end
    
endmodule
