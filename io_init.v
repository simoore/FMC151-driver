module io_init (
    input   wire rst, 
    input   wire clk, 
    input   wire init_ena,
    output  reg  spi_sclk, 
    output  reg  spi_sdata,
    output  wire cdce_n_en,
    input   wire cdce_miso,
    output  wire cdce_n_reset, 
    output  wire cdce_n_pd, 
    output  wire ref_en,
    output  wire ads_n_en,
    output  wire adc_reset,
    output  wire dac_n_en,
    output  wire amc_n_en,
    output  wire mon_n_rst,
    output  wire init_done,
    output  wire start_calibration,
    input   wire adc_calibrated);
    
    /***************************************************************************
    * Internal signal declarations.
    ***************************************************************************/
    localparam IDLE      = 8'b00000001; 
    localparam INIT_CDCE = 8'b00000010; 
    localparam INIT_ADC  = 8'b00000100; 
    localparam INIT_DAC  = 8'b00001000;
    localparam INIT_MON  = 8'b00010000; 
    localparam FINISHED  = 8'b00100000;
    localparam CALIBRATE = 8'b01000000; 
    localparam ADC_AGAIN = 8'b10000000;
                
    reg [7:0] state, next_state;
    wire cdce_spi_sclk, cdce_spi_sdata, init_cdce_done, 
         ads_spi_sclk,  ads_spi_sdata,  init_ads_done, 
         dac_spi_sclk,  dac_spi_sdata,  init_dac_done,
         amc_spi_sdata, amc_spi_sclk,   init_amc_done,
         init_cdce_ena, init_adc_ena, init_dac_ena, init_mon_ena;
    
    /***************************************************************************
    * Route the signals of the individual SPI modules to the SPI IO.
    ***************************************************************************/
    always @(*) begin
        spi_sclk  = 0;
        spi_sdata = 0;
        case (state)
            INIT_CDCE : begin
                spi_sclk  = cdce_spi_sclk;
                spi_sdata = cdce_spi_sdata;
            end
            INIT_ADC : begin
                spi_sclk  = ads_spi_sclk;
                spi_sdata = ads_spi_sdata;
            end
            INIT_DAC : begin
                spi_sclk  = dac_spi_sclk;
                spi_sdata = dac_spi_sdata;
            end
            INIT_MON : begin
                spi_sclk  = amc_spi_sclk;
                spi_sdata = amc_spi_sdata;
            end
            ADC_AGAIN : begin
                spi_sclk  = ads_spi_sclk;
                spi_sdata = ads_spi_sdata;
            end
        endcase
    end
    
    /***************************************************************************
    * Initialisation rountine of the individual modules on the FMC151 card.
    ***************************************************************************/
    io_init_clock clock_init (rst, clk, init_cdce_ena, init_cdce_done, 
        cdce_spi_sclk, cdce_spi_sdata, cdce_n_en, cdce_miso, ref_en, 
        cdce_n_reset, cdce_n_pd);
        
    io_init_adc adc_init (rst, clk, init_adc_ena, init_ads_done, 
        ads_spi_sclk, ads_spi_sdata, ads_n_en, adc_reset, adc_calibrated);
        
    io_init_dac dac_init (rst, clk, init_dac_ena, init_dac_done, 
        dac_spi_sclk, dac_spi_sdata, dac_n_en);
        
    io_init_monitor monitor_init (rst, clk, init_mon_ena, init_amc_done, 
        amc_spi_sclk, amc_spi_sdata, amc_n_en, mon_n_rst);
    
    /***************************************************************************
    * IO initialisation state machine.
    ***************************************************************************/
    always @(posedge clk)
        if (rst) state <= IDLE;
        else     state <= next_state;
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE      : if (init_ena == 1)       next_state = INIT_CDCE;
            INIT_CDCE : if (init_cdce_done == 1) next_state = INIT_ADC;
            INIT_ADC  : if (init_ads_done == 1)  next_state = INIT_DAC;
            INIT_DAC  : if (init_dac_done == 1)  next_state = INIT_MON;
            INIT_MON  : if (init_amc_done == 1)  next_state = CALIBRATE;
            CALIBRATE : if (adc_calibrated == 1) next_state = ADC_AGAIN;
            ADC_AGAIN : if (init_ads_done == 1)  next_state = FINISHED;
            FINISHED  : if (init_ena == 0)       next_state = IDLE;
            default   : next_state = IDLE;
        endcase
    end
    
    assign init_cdce_ena = state == INIT_CDCE;
    assign init_adc_ena  = state == INIT_ADC || state == ADC_AGAIN;
    assign init_dac_ena  = state == INIT_DAC;
    assign init_mon_ena  = state == INIT_MON;
    assign init_done     = state == FINISHED;
    assign start_calibration = state == CALIBRATE;
 
endmodule
