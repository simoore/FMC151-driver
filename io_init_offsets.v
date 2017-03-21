module io_init_offsets (
    input  wire rst,
    input  wire clk,
    input  wire start,
    output wire iic_rst, 
    inout  wire iic_scl, 
    inout  wire iic_sda);
    
    localparam IDLE      = 8'b00000001; 
    localparam START     = 8'b00000010;
    localparam WAIT      = 8'b00000100;
    localparam INC       = 8'b00001000;
    localparam LOAD_INC  = 8'b00010000;
    localparam WAIT_LAST = 8'b00100000;
    localparam NEXT      = 8'b01000000;
    localparam DONE      = 8'b10000000;
    
    localparam OFFSET_ADC_A = 12'h850;
    localparam OFFSET_ADC_B = 12'h840;
    localparam OFFSET_DAC_A = 12'h800;
    localparam OFFSET_DAC_B = 12'h800;
    
    reg rst_lcl;
    reg start_tx;
    wire busy;
    wire load;
    wire last_address;
    wire last_device;
    reg [7:0] data_addr;
    reg [7:0] addr_addr;
    reg [7:0] dev_addr;
    reg [7:0] addr [4:0]; 
    reg [7:0] dev [4:0];
    reg [7:0] data [12:0];
    reg [7:0] addr_buf;
    reg [7:0] data_buf;
    reg [7:0] dev_buf;
    reg [7:0] state;
    reg [7:0] next_state;

    /***************************************************************************
    * Local reset.
    ***************************************************************************/
    always @(posedge clk)
        rst_lcl <= rst;
            
    /***************************************************************************
    * I2C master module.
    ***************************************************************************/
    i2c_master #(
        .input_clk  (200_000_000),
        .bus_clk    (400_000))      
    i2c_master_inst (
        .clk        (clk), 
        .rst        (rst_lcl),            
        .ena        (start_tx),           
        .addr       (addr_buf[7:1]),     
        .rw         (addr_buf[0]),             
        .data_wr    (data_buf), 
        .busy       (busy),      
        .load       (load),          
        .data_rd    (), 
        .sda        (iic_sda),      
        .scl        (iic_scl));
    
    assign iic_rst = ~rst_lcl;
    
    /***************************************************************************
    * Offset initialisation state machine. This sends out the commands using the
    * I2C driver.
    ***************************************************************************/
    always @(posedge clk)
        if (rst_lcl)    state <= IDLE;
        else            state <= next_state;
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE        : if (start) next_state = START;
            START       : if (busy)  
                            if (last_address)       next_state = WAIT_LAST;
                            else                    next_state = WAIT;
            WAIT        : if (load)                 next_state = INC;
            INC         : next_state = LOAD_INC;
            LOAD_INC    : if (!load) 
                            if (last_address)       next_state = WAIT_LAST;
                            else                    next_state = WAIT;
            WAIT_LAST   : if (!busy)
                            if (last_device)        next_state = DONE;
                            else                    next_state = NEXT;
            NEXT        : next_state = START;
            DONE        : if (~start) next_state = IDLE;
            default     : next_state = IDLE;
        endcase
    end
    
    assign last_device  = (dev_addr == 4) && last_address;
    assign last_address = dev_buf == data_addr;
    
    always @(posedge clk)
        if (rst_lcl)                 start_tx <= 0;
        else if (state == START)     start_tx <= 1;
        else if (state == WAIT_LAST) start_tx <= 0;
       
    /***************************************************************************
    * Synchronous rom implementation.
    * There are 
    ***************************************************************************/
    always @(posedge clk) begin
        if (state == IDLE)          addr_addr <= 0;
        else if (state == NEXT)     addr_addr <= addr_addr + 1;   
        
        if (state == IDLE)          data_addr <= 0;
        else if (state == NEXT)     data_addr <= data_addr + 1;
        else if (state == INC)      data_addr <= data_addr + 1;
        
        if (state == IDLE)          dev_addr <= 0;
        else if (state == NEXT)     dev_addr <= dev_addr + 1;
        
        data_buf <= data[data_addr];
        addr_buf <= addr[addr_addr];
        dev_buf  <= dev[dev_addr];
    end
   
    initial begin
        addr[0] = {7'h74,1'b0};     // I2C bus write address
        addr[1] = {7'h10,1'b0};     // DAC write address
        addr[2] = {7'h10,1'b0};     // DAC write address
        addr[3] = {7'h10,1'b0};     // DAC write address
        addr[4] = {7'h10,1'b0};     // DAC write address
        data[0] = 8'h04;            // enable CH2 I2C bus for IO card comms
        data[1] = 8'h30;            // write to an enable DAC 0
        data[2] = OFFSET_ADC_A[11:4];
        data[3] = {OFFSET_ADC_A[3:0],4'b0};
        data[4] = 8'h31;            // write to an enable DAC 1
        data[5] = OFFSET_ADC_B[11:4];
        data[6] = {OFFSET_ADC_B[3:0],4'b0};
        data[7] = 8'h32;            // write to an enable DAC 2
        data[8] = OFFSET_DAC_A[11:4];
        data[9] = {OFFSET_DAC_A[3:0],4'b0};
        data[10] = 8'h33;           // write to an enable DAC 3
        data[11] = OFFSET_DAC_B[11:4];
        data[12] = {OFFSET_DAC_B[3:0],4'b0};
        dev[0] = 8'd0;              // this is the end addr for each device
        dev[1] = 8'd3;
        dev[2] = 8'd6;
        dev[3] = 8'd9;
        dev[4] = 8'd12;
    end
        
endmodule
