// SiDi / MiST TOP module for NEXT186.

module Next186_SoC
(
    input         CLOCK_27,   // Input clock 27 MHz

    output  [5:0] VGA_R,
    output  [5:0] VGA_G,
    output  [5:0] VGA_B,
    output        VGA_HS,
    output        VGA_VS,

    output        LED,

    output        AUDIO_L,
    output        AUDIO_R,

	input RX_EXT,
	output TX_EXT,

    input         SPI_SCK,
    output        SPI_DO,
    input         SPI_DI,
    input         SPI_SS2,
    input         SPI_SS3,
    input         CONF_DATA0,

	output	[12:0]DRAM_ADDR,
	output	[1:0]DRAM_BA,
	output	DRAM_CAS_N,
	output	DRAM_CKE,
	output	DRAM_CLK,
	output	DRAM_CS_N,
	inout		[15:0]DRAM_DQ,
	output	[1:0]DRAM_DQM,
	output	DRAM_RAS_N,
	output	DRAM_WE_N
);

parameter CONF_STR = {
        "NEXT186;;",
};

wire [1:0] scanlines = status[2:1];
wire       joyswap = status[3];
wire       rommap = status[4];
wire       autoboot = status[5];
wire			clk_sys;
// core's raw video 
wire 			core_r, core_g, core_b, core_hs, core_vs;   
wire			core_clken;

// user io
wire [7:0] status;
wire [1:0] buttons;
wire [1:0] switches;

wire        ps2_clk;
wire        ps2_dat;

// conections between user_io (implementing the SPI communication 
// to the io controller) and the legacy 
wire [31:0] sd_lba;
wire sd_rd;
wire sd_wr;
wire sd_ack;
wire sd_conf;
wire sd_sdhc; 
wire [7:0] sd_dout;
wire sd_dout_strobe;
wire [7:0] sd_din;
wire sd_din_strobe;
wire [8:0] sd_buff_addr;
wire sd_ack_conf;
wire img_mounted;
wire [31:0] img_size;

wire [7:0] joystick_0;
wire [7:0] joystick_1;
wire [15:0] joystick_analog_0;
wire [15:0] joystick_analog_1;

wire scandoubler_disable;
wire ypbpr;
wire no_csync;

user_io #(.STRLEN($size(CONF_STR)>>3)) user_io(
	.conf_str      ( CONF_STR       ),
	.clk_sys       ( clk_sys        ),
	.clk_sd        ( clk_sys        ),

	// the spi interface
	.SPI_CLK        ( SPI_SCK       ),
	.SPI_SS_IO      ( CONF_DATA0    ),
	.SPI_MISO       ( SPI_DO        ),   // tristate handling inside user_io
	.SPI_MOSI       ( SPI_DI        ),
	
	.joystick_0        ( joystick_0 ),
	.joystick_1        ( joystick_1 ),
	.joystick_analog_0 ( joystick_analog_0 ),
	.joystick_analog_1 ( joystick_analog_1 ),

	.status         ( status        ),
	.switches       ( switches      ),
	.buttons        ( buttons       ),
	.scandoubler_disable ( scandoubler_disable ),
	.ypbpr          ( ypbpr         ),
	.no_csync       ( no_csync      ),

   // interface to embedded legacy sd card wrapper
	.sd_lba     	  ( sd_lba        ),
	.sd_rd      	  ( sd_rd         ),
	.sd_wr      	  ( sd_wr         ),
	.sd_ack     	  ( sd_ack        ),
	.sd_conf    	  ( sd_conf       ),
	.sd_sdhc    	  ( sd_sdhc       ),
	.sd_dout    	  ( sd_dout       ),
	.sd_dout_strobe ( sd_dout_strobe),
	.sd_din     	  ( sd_din        ),
	.sd_din_strobe  ( sd_din_strobe ),
	.sd_buff_addr   ( sd_buff_addr  ),
	.sd_ack_conf    ( sd_ack_conf   ),

	.img_mounted    ( img_mounted   ),
	.img_size       ( img_size      ),

	.ps2_kbd_clk	  ( ps2_clk       ), 
	.ps2_kbd_data	  ( ps2_dat       )
);

// wire the sd card to the user port
wire sd_sck;
wire sd_cs;
wire sd_sdi;
wire sd_sdo;

sd_card sd_card (
	// connection to io controller
	.clk_sys(clk_sys),
	.sd_lba (sd_lba ),
	.sd_rd  (sd_rd),
	.sd_wr  (sd_wr),
	.sd_ack (sd_ack),
	.sd_ack_conf (sd_ack_conf      ),
	.sd_conf (sd_conf),
	.sd_sdhc (sd_sdhc),
	.sd_buff_dout (sd_dout),
	.sd_buff_wr (sd_dout_strobe),
	.sd_buff_din (sd_din),
	.sd_buff_addr  (sd_buff_addr     ),
	.img_mounted (img_mounted),
	.img_size (img_size),
	.allow_sdhc ( 1'b1),
 
	// connection to local CPU
	.sd_cs   ( sd_cs          ),
	.sd_sck  ( sd_sck         ),
	.sd_sdi  ( sd_sdi         ),
	.sd_sdo  ( sd_sdo         )
);

mist_video #(.COLOR_DEPTH(1), .SD_HCNT_WIDTH(10)) mist_video (
	.clk_sys     ( clk_sys    ),

	// OSD SPI interface
	.SPI_SCK     ( SPI_SCK    ),
	.SPI_SS3     ( SPI_SS3    ),
	.SPI_DI      ( SPI_DI     ),

	// scanlines (00-none 01-25% 10-50% 11-75%)
	.scanlines   ( scanlines  ),

	// non-scandoubled pixel clock divider 0 - clk_sys/4, 1 - clk_sys/2
	.ce_divider  ( 1'b0       ),

	// 0 = HVSync 31KHz, 1 = CSync 15KHz
	.scandoubler_disable ( scandoubler_disable ),
	// disable csync without scandoubler
	.no_csync    ( no_csync   ),
	// YPbPr always uses composite sync
	.ypbpr       ( ypbpr      ),
	// Rotate OSD [0] - rotate [1] - left or right
	.rotate      ( 2'b00      ),
	// composite-like blending
	.blend       ( 1'b0       ),

	// video in
	.R           ( core_r     ),
	.G           ( core_g     ),
	.B           ( core_b     ),

	.HSync       ( core_hs    ),
	.VSync       ( core_vs    ),

	// MiST video output signals "eliminado porque no queda BRAM libre"
	.VGA_R       (VGA_R),
	.VGA_G       (VGA_G),
	.VGA_B       (VGA_B),
	.VGA_VS      (VGA_VS),
	.VGA_HS      (VGA_HS)
);



//////NEXT186///////////////
	assign DRAM_CKE = 1'b1;
	wire [3:0]IO;
	wire SDR_CLK;


	dd_buf sdrclk_buf
	(
		.datain_h(1'b1),
		.datain_l(1'b0),
		.outclock(SDR_CLK),
		.dataout(DRAM_CLK)
	);
	
	assign HLLED=1'b1; // LED ROJO: apagado
	assign SDLED=LED; // LED NARANJA: actividad de la SD, a modo led HD
	assign SYLED=1'b0; // LED AZUL: apagado (es inverso)
	
	system sys_inst
	(
		.CLK_50MHZ(CLOCK_27),
		
		.VGA_R(core_r),
		.VGA_G(core_g),
		.VGA_B(core_b),
		.VGA_HSYNC(core_hs),
		.VGA_VSYNC(core_vs),
		.frame_on(),
		
		.clk_25(clk_sys),
		
		.sdr_CLK_out(SDR_CLK),
		.sdr_n_CS_WE_RAS_CAS({DRAM_CS_N, DRAM_WE_N, DRAM_RAS_N, DRAM_CAS_N}),
		.sdr_BA(DRAM_BA),
		.sdr_ADDR(DRAM_ADDR),
		.sdr_DATA(DRAM_DQ),
		.sdr_DQM({DRAM_DQM}),
		
		.LED(LED), 
		
		.BTN_RESET(1'b0), // boton de RESET negado
		.BTN_NMI(1'b0), // ~BTN_WEST), // anulo NMI, no me hace falta
		
		.RS232_DCE_RXD(RX_EXT),
		.RS232_DCE_TXD(TX_EXT),
		.RS232_EXT_RXD(),
		.RS232_EXT_TXD(),
		
		.SD_n_CS(sd_cs),
		.SD_DI(sd_sdi),
		.SD_CK(sd_sck),
		.SD_DO(sd_sdo),
		
		.AUD_L(AUDIO_L),
		.AUD_R(AUDIO_R),
		
	 	.PS2_CLK1(),
		.PS2_CLK2(),
		.PS2_DATA1(),
		.PS2_DATA2(),
		
		.RS232_HOST_RXD(),
		.RS232_HOST_TXD(),
		.RS232_HOST_RST(),
		
		.GPIO(), //{IO, GPIO}), 
		
		.I2C_SCL(),//I2C_SCLK), 
		.I2C_SDA() //I2C_SDAT)
	);
	
	
	
	
//////////////////   AUDIO   //////////////////


endmodule
