/********************************************************************************
* Reset synchroniser.
*   http://www.markharvey.info/art/reset_07.09.2016/reset_07.09.2016.html
********************************************************************************/ 
module io_reset_synchroniser (
    input wire clk, 
    input wire locked, 
    input wire cpu_reset, 
    output wire rst_sync);
    
    wire rst_async;
    reg [1:0] rst_shift_reg = 2'b11;
    
    always @(posedge clk or posedge rst_async)
        if (rst_async) rst_shift_reg <= 2'b11;
        else           rst_shift_reg <= {rst_shift_reg[0], 1'b0};
    
    assign rst_async = cpu_reset | !locked;
    assign rst_sync  = rst_shift_reg[1];
    
endmodule
