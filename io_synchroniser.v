module io_synchroniser (
    input  wire clk_in, 
    input  wire clk_out, 
    input  wire data_in, 
    output wire data_out);

    (* keep = "true" *) reg data_cross;
    (* async_reg = "true" *) reg [1:0] meta;
        
    always @(posedge clk_in)
        data_cross <= data_in;
        
    always @(posedge clk_out) begin
        meta[0] <= data_cross;
        meta[1] <= meta[0];
    end
    
    assign data_out = meta[1];
          
endmodule
