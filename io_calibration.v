/*******************************************************************************
* The ADC delay calibration tunes a delay placed on ADC data input pins to 
* compensate for delays associated with the clocking logic. The calibration uses 
* the test pattern sent from the ADC. Initially the ADC is configured to 
* generate a ramp signal. Thus for calibration, each sample is checked to be +1
* from the previous sample. If not, the delay is incremented. This process is 
* contiuned until 2000 samples in a row pass the test.
*
* rst       When the ADC clock loses lock.
* clk       The ADC clock nominally 245.76MHz.
* start     Signal to start the calibration rountine.
* adc       The ADC data to calibrate against, that is the ramp signal.
* ce        The signal to increment the delay.
* done      Indication that calibration is complete.
*******************************************************************************/
module io_calibration (
    input  wire rst, 
    input  wire clk, 
    input  wire start,
    input  wire [13:0] adc,
    output wire ce, 
    output wire done);
    
    localparam IDLE  = 5'b00001, 
               INIT  = 5'b00010, 
               CHECK = 5'b00100, 
               ERROR = 5'b01000, 
               DONE  = 5'b10000;

    wire mismatch;
    reg [13:0] buffer; 
    reg [13:0] prev; 
    reg [13:0] count;
    reg [4:0] state; 
    reg [4:0] next_state;
    
    /***************************************************************************
    * Calibration state machine.
    ***************************************************************************/    
    always @(posedge clk)
        if (rst == 1)   state <= IDLE;
        else            state <= next_state;
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE  : if (start == 1)          next_state = INIT;
            INIT  : if (count == 4)          next_state = CHECK;
            CHECK : if (mismatch == 1)       next_state = ERROR;
                    else if (count == 2000)  next_state = DONE;
            ERROR : next_state = INIT;
            DONE  : next_state = DONE;
            default : next_state = IDLE;
        endcase
    end
    
    assign ce   = state == ERROR;
    assign done = state == DONE; 
    assign mismatch = buffer != prev + 1;
    
    always @(posedge clk)
        if (rst == 1) begin
            prev   <= 0;
            count  <= 0;
            buffer <= 0;
        end else begin
            prev   <= buffer;
            count  <= (state == INIT || state == CHECK) ? count + 1 : 0;
            buffer <= adc;
        end
        
endmodule
