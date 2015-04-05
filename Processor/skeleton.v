module skeleton(	CLOCK_50, CLOCK2_50,
						KEY, PS2_CLK, PS2_DAT,
						VGA_R, VGA_G, VGA_B, VGA_CLK, VGA_HS, VGA_VS, VGA_BLANK_N,
						LEDG, LEDR,
						HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7
						);

	input 			CLOCK_50, CLOCK2_50;
	input		[3:0]	KEY;
	inout 			PS2_DAT, PS2_CLK;
	
	output	[7:0]	VGA_R;
	output	[7:0]	VGA_G;
	output	[7:0]	VGA_B;
	output			VGA_CLK;
	output			VGA_HS;
	output			VGA_VS;
	output			VGA_BLANK_N;

	output   [8:0] LEDG;
	output  [17:0] LEDR; 
	output 	[6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7;
	
	
	//	Not used but required by the VGA_Audio_PLL module
	wire		   AUD_CTRL_CLK;	//	For Audio Controller
	wire			mVGA_CLK;

	//	VGA Controller
	wire		   DLY_RST;
	wire		   VGA_CTRL_CLK;
	
	// dmem writes debug
	wire  [31:0] debug_word;
	wire  [11:0] debug_addr;
	
	// Processor and ps2 keyboard related
	wire			clock;
	wire			resetn;
	wire	[7:0]	ps2_key_data;
	wire			ps2_key_pressed;	// may be used to trigger an interrupt
	wire	[7:0]	ps2_out;
	
	wire [31:0] r1;
	
	// Use KEY[0] as processor reset
	assign 		resetn = KEY[0];
	
	// clock divider (50MHz/5=10MHz)
	pll div(CLOCK_50,clock);
	//assign clock = CLOCK_50;
	
	//// dmem: port a for processor writes and reads; port b for VGA controller reads
	// connections between dmem and the processor
	wire  [31:0] dmemPrgmRData; // -> dmem port a
	wire  [11:0] dmemPrgmAddr; // -> dmem port a
	wire  [31:0] dmemPrgmWData; // -> dmem port a
	wire         dmemPrgmWE;	// -> dmem port a 
	
	// connections between the dmem and the vga_controller
	wire [31:0] dmemDispRData;
	wire [11:0] dmemDispAddr;
	
	dmem	dmem_inst (
			.clock_a (~clock),
			.address_a (dmemPrgmAddr),
			.data_a (dmemPrgmWData),
			.wren_a (dmemPrgmWE),
			.q_a (dmemPrgmRData),
			
			.clock_b (VGA_CTRL_CLK),
			.address_b (dmemDispAddr),
			.data_b (32'b0),
			.wren_b (1'b0),
			.q_b (dmemDispRData)
	);
	
	// your processor
	processor myprocessor(clock, ~resetn, ps2_key_pressed, ps2_out, debug_word, debug_addr, r1, dmemPrgmAddr, dmemPrgmWData, dmemPrgmWE, dmemPrgmRData);
	
	//	Reset Delay Timer
	Reset_Delay			r0	(.iCLK(CLOCK_50),.oRESET(DLY_RST));

	VGA_Audio_PLL 		p1	(.areset(~DLY_RST),.inclk0(CLOCK2_50),.c0(VGA_CTRL_CLK),.c1(AUD_CTRL_CLK),.c2(mVGA_CLK));

	//	VGA Controller
	assign VGA_CLK = VGA_CTRL_CLK;
	vga_controller vga_ins(.iRST_n(DLY_RST),
								  .iVGA_CLK(VGA_CTRL_CLK),
								  .bgr_data_raw(dmemDispRData),
								  .oBLANK_n(VGA_BLANK_N),
								  .oHS(VGA_HS),
								  .oVS(VGA_VS),
								  .b_data(VGA_B),
								  .g_data(VGA_G),
								  .r_data(VGA_R),
								  .ADDR(dmemDispAddr));
							 
	// keyboard controller
	PS2_Interface myps2(clock, resetn, PS2_CLK, PS2_DAT, ps2_key_data, ps2_key_pressed, ps2_out);
	
	// registered output
	Hexadecimal_To_Seven_Segment hex1(ps2_out[3:0], HEX0);
	Hexadecimal_To_Seven_Segment hex2(ps2_out[7:4], HEX1);
	// un-registered output
	Hexadecimal_To_Seven_Segment hex3(ps2_key_data[3:0], HEX2);
	Hexadecimal_To_Seven_Segment hex4(ps2_key_data[7:4], HEX3);
	
	// the other seven segment displays are currently set to 0
	Hexadecimal_To_Seven_Segment hex5(4'b0, HEX4);
	Hexadecimal_To_Seven_Segment hex6(4'b0, HEX5);
	Hexadecimal_To_Seven_Segment hex7(4'b0, HEX6);
	Hexadecimal_To_Seven_Segment hex8(4'b0, HEX7);
	
	assign LEDG[7:0] = r1[7:0];
	
	assign LEDR[0] = ps2_key_pressed;
	
endmodule
