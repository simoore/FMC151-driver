module io_main ( 
    input  wire cpu_reset, 
    input  wire sysclk_p, 
    input  wire sysclk_n,
    output wire gpio_led_0, 
    output wire gpio_led_1, 
    output wire gpio_led_2, 
    output wire gpio_led_3,      
    output wire gpio_led_4, 
    output wire gpio_led_5, 
    output wire gpio_led_6, 
    output wire gpio_led_7,      
    output wire spi_clk, 
    output wire spi_mosi,
    output wire iic_rst, 
    inout  wire iic_scl, 
    inout  wire iic_sda,
    input  wire cdce_miso, 
    input  wire pll_status,
    output wire cdce_n_en, 
    output wire cdce_n_reset, 
    output wire cdce_n_pd, 
    output wire ref_en,
    input  wire clk_ab_p, 
    input  wire clk_ab_n,                  
    input  wire [6:0] cha_p, 
    input  wire [6:0] cha_n, 
    input  wire [6:0] chb_p, 
    input  wire [6:0] chb_n,  
    output wire adc_n_en, 
    output wire adc_reset,                        
    output wire dac_clk_p, 
    output wire dac_clk_n, 
    output wire dac_frame_p, 
    output wire dac_frame_n,
    output wire dac_tx_en, 
    output wire dac_n_en,
    output wire [7:0] dac_data_p, 
    output wire [7:0] dac_data_n, 
    input  wire mon_n_int, 
    output wire mon_n_en, 
    output wire mon_n_reset);
    
    /***************************************************************************
    * Signal declarations.
    ***************************************************************************/
    wire clk_200MHz; 
    wire clk_adc; 
    wire clk_adc_ddr; 
    wire clk_sys_locked; 
    wire clk_adc_locked;
    wire init_done;
    wire adc_calibrated_fast;
    wire adc_calibrated_slow;
    wire start_calibration_slow;
    wire start_calibration_fast;
    wire [13:0] adc_a;
    wire [13:0] adc_b;
    reg [15:0] dac_a; 
    reg [15:0] dac_b;
    
    /***************************************************************************
    * Place system here. adc_a and adc_b are the two ADC channels and dac_a
    * and dac_b are the two DAC channels. They are synchronised to the 
    * clk_245_76MHz clock.
    ***************************************************************************/
    always @(posedge clk_adc) begin
        if (rst_sync_adc)   dac_a <= 16'b0;
        else                dac_a <= {adc_a,2'b0};
        if (rst_sync_adc)   dac_b <= 16'b0;
        else                dac_b <= {adc_b,2'b0};
    end
    
    /***************************************************************************
    * System clock instances and reset generation.
    ***************************************************************************/
    io_clk_sys clk_sys (
        .clk_in1_p      (sysclk_p), 
        .clk_in1_n      (sysclk_n), 
        .clk_out1       (clk_200MHz), 
        .reset          (cpu_reset), 
        .locked         (clk_sys_locked));
    
    io_clk_adc clk_adc_inst (
        .clk_in1_p      (clk_ab_p), 
        .clk_in1_n      (clk_ab_n), 
        .clk_out1       (clk_adc),
        .clk_out2       (clk_adc_ddr),
        .reset          (cpu_reset), 
        .locked         (clk_adc_locked));    
        
    io_reset_synchroniser reset_synchroniser_sys (
        .clk            (clk_200MHz), 
        .locked         (clk_sys_locked), 
        .cpu_reset      (cpu_reset), 
        .rst_sync       (rst_sync_sys));
        
    io_reset_synchroniser reset_synchroniser_adc (
        .clk            (clk_adc), 
        .locked         (clk_adc_locked), 
        .cpu_reset      (cpu_reset), 
        .rst_sync       (rst_sync_adc));
    
    /***************************************************************************
    * Initialisation of the FMC151 analog card.
    ***************************************************************************/
    io_init init_modules (
        .rst                (rst_sync_sys), 
        .clk                (clk_200MHz), 
        .init_ena           (1'b1),
        .spi_sclk           (spi_clk), 
        .spi_sdata          (spi_mosi),
        .cdce_n_en          (cdce_n_en),
        .cdce_miso          (cdce_miso),
        .cdce_n_reset       (cdce_n_reset), 
        .cdce_n_pd          (cdce_n_pd), 
        .ref_en             (ref_en),
        .ads_n_en           (adc_n_en),
        .adc_reset          (adc_reset),
        .dac_n_en           (dac_n_en),
        .amc_n_en           (mon_n_en),
        .mon_n_rst          (mon_n_reset),
        .init_done          (init_done),
        .start_calibration  (start_calibration_slow),
        .adc_calibrated     (adc_calibrated_slow));
        
    io_init_offsets init_offsets (
        .rst        (rst_sync_sys),
        .clk        (clk_200MHz),
        .start      (init_done),
        .iic_rst    (iic_rst), 
        .iic_scl    (iic_scl), 
        .iic_sda    (iic_sda));  
        
    /***************************************************************************
    * Pulse synchronizers between the 200MHz clock domain and the 245.76MHz 
    * clock domain. Used to commicate between the initialization rountine and 
    * the ADC delay calibration.
    ***************************************************************************/
    io_synchroniser done_signal ( 
        .clk_in     (clk_adc), 
        .clk_out    (clk_200MHz), 
        .data_in    (adc_calibrated_fast), 
        .data_out   (adc_calibrated_slow));
        
     io_synchroniser start_signal (
        .clk_in     (clk_200MHz), 
        .clk_out    (clk_adc), 
        .data_in    (start_calibration_slow), 
        .data_out   (start_calibration_fast));
        
    /***************************************************************************
    * Operation of the FMC151 analog card.
    ***************************************************************************/  
    io_main_adc adc_driver (
        .rst            (rst_sync_adc), 
        .clk            (clk_adc), 
        .clk_200MHz     (clk_200MHz),
        .cha_p          (cha_p), 
        .cha_n          (cha_n), 
        .chb_p          (chb_p), 
        .chb_n          (chb_n),
        .adc_a_buf      (adc_a), 
        .adc_b_buf      (adc_b),
        .start          (start_calibration_fast),  
        .done           (adc_calibrated_fast));
            
     io_main_dac dac_driver (
        .rst            (rst_sync_adc), 
        .clk            (clk_adc_ddr), 
        .clk_2          (clk_adc),
        .dac_a          (dac_a), 
        .dac_b          (dac_b),
        .dac_clk_p      (dac_clk_p), 
        .dac_clk_n      (dac_clk_n),
        .dac_frame_p    (dac_frame_p), 
        .dac_frame_n    (dac_frame_n),
        .dac_tx_en      (dac_tx_en),
        .dac_data_p     (dac_data_p), 
        .dac_data_n     (dac_data_n));

    /***************************************************************************
    * Debug logic, heartbeats and LED indicators.
    ***************************************************************************/
    reg [31:0] adc_count, sys_count;
    always @(posedge clk_200MHz)
        if (rst_sync_sys == 1)  sys_count <= 0;
        else                    sys_count <= sys_count + 1;
            
    always @(posedge clk_adc)
        if (rst_sync_adc == 1)  adc_count <= 0;
        else                    adc_count <= adc_count + 1;
            
    assign gpio_led_0 = clk_adc_locked;
    assign gpio_led_1 = init_done;
    assign gpio_led_2 = pll_status;
    assign gpio_led_3 = mon_n_int;
    assign gpio_led_4 = clk_adc_locked & adc_calibrated_fast;
    assign gpio_led_5 = clk_sys_locked & pll_status & mon_n_int & init_done;
    assign gpio_led_6 = sys_count[28];
    assign gpio_led_7 = adc_count[28];
                
endmodule
