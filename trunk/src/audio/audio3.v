module audio3(
  // Clock Input (50 MHz)
  input clk50, // 50 MHz
  input clk27, // 27 MHz
  //  reset
  input  RST,
  //  frequency to play at
  input  [17:0]  pitch,
  // TV Decoder
  output td_reset, // TV Decoder Reset
  // I2C
  inout  I2C_SDAT, // I2C Data
  output I2C_SCLK, // I2C Clock
  // Audio CODEC
  output/*inout*/ AUD_ADCLRCK, // Audio CODEC ADC LR Clock
  input	 AUD_ADCDAT,  // Audio CODEC ADC Data
  output /*inout*/  AUD_DACLRCK, // Audio CODEC DAC LR Clock
  output AUD_DACDAT,  // Audio CODEC DAC Data
  inout	 AUD_BCLK,    // Audio CODEC Bit-Stream Clock
  output AUD_XCK     // Audio CODEC Chip Clock
);


// reset delay gives some time for peripherals to initialize
wire DLY_RST;
Reset_Delay r0(	.iCLK(clk50),.oRESET(DLY_RST) );


assign	td_reset = 1'b1;  // Enable 27 MHz
wire VGA_CTRL_CLK;
wire AUD_CTRL_CLK;
wire VGA_CLK;
VGA_Audio_PLL 	p1 (	
	.areset(~DLY_RST),
	.inclk0(clk27),
	.c0(VGA_CTRL_CLK),
	.c1(AUD_CTRL_CLK),
	.c2(VGA_CLK)
);

I2C_AV_Config u3(	
//	Host Side
  .iCLK(clk50),
  .iRST_N(RST),
//	I2C Side
  .I2C_SCLK(I2C_SCLK),
  .I2C_SDAT(I2C_SDAT)	
);

assign	AUD_ADCLRCK	=	AUD_DACLRCK;
assign	AUD_XCK		=	AUD_CTRL_CLK;

audio_clock u4(	
//	Audio Side
   .oAUD_BCK(AUD_BCLK),
   .oAUD_LRCK(AUD_DACLRCK),
//	Control Signals
  .iCLK_18_4(AUD_CTRL_CLK),
   .iRST_N(DLY_RST)	
);

audio_converter u5(
	// Audio side
	.AUD_BCK(AUD_BCLK),       // Audio bit clock
	.AUD_LRCK(AUD_DACLRCK), // left-right clock
	.AUD_ADCDAT(AUD_ADCDAT),
	.AUD_DATA(AUD_DACDAT),
	// Controller side
	.iRST_N(DLY_RST),  // reset
	.AUD_outL(audio_outL),
	.AUD_outR(audio_outR),
	.AUD_inL(audio_inL),
	.AUD_inR(audio_inR)
);

wire [15:0] audio_inL, audio_inR;
wire [15:0] audio_outL, audio_outR;
wire [15:0] signal;




//set up DDS frequency
//Use switches to set freq
wire [31:0] dds_incr;
wire [31:0] freq = pitch[3:0]+10*pitch[7:4]+100*pitch[11:8]+1000*pitch[15:12]+10000*pitch[17:16];
assign dds_incr = freq * 91626 ; //91626 = 2^32/46875 so SW is in Hz

reg [31:0] dds_phase;

always @(negedge AUD_DACLRCK or negedge DLY_RST)
	if (!DLY_RST) dds_phase <= 0;
	else dds_phase <= dds_phase + dds_incr;

wire [7:0] index = dds_phase[31:24];

 
sine_table sig1(
	.index(index),
	.signal(audio_outR)
);

	//audio_outR <= audio_inR;

//always @(posedge AUD_DACLRCK)
assign audio_outL = audio_outR;


endmodule