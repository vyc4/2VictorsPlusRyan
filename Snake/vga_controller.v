module vga_controller(iRST_n, iVGA_CLK, bgr_data_raw, oBLANK_n, oHS, oVS, b_data, g_data, r_data, ADDR);

	input iRST_n;
	input iVGA_CLK;
	output reg oBLANK_n;
	output reg oHS;
	output reg oVS;
	output [7:0] b_data;
	output [7:0] g_data;  
	output [7:0] r_data; 
					

	// connections to dmem
	input  [31:0] bgr_data_raw;
	output reg [11:0] ADDR;
	
	////// some reg values                     
	//reg [8:0] ADDR;
	reg [4:0] h_sub_cnt;
	reg [4:0] v_sub_cnt;
	reg [2:0] bgr_data;

	////// video_sync_generator: generates cHS and cVS
	wire 		   cBLANK_n,cHS,cVS,rst;
	wire [10:0] h_cnt;
	wire  [9:0] v_cnt;
	assign rst = ~iRST_n;

	video_sync_generator LTM_ins (.vga_clk(iVGA_CLK),
											.reset(rst),
											.blank_n(cBLANK_n),
											.HS(cHS),
											.VS(cVS),
											.h_cnt(h_cnt),
											.v_cnt(v_cnt));

	////// Constants copied from video_sync_generator
	parameter hori_line  = 800;                           
	parameter hori_back  = 144;
	parameter hori_front = 16;
	parameter vert_line  = 525;
	parameter vert_back  = 34;
	parameter vert_front = 11;
	parameter H_sync_cycle = 96;
	parameter V_sync_cycle = 2;

	// some additional constants for addres calculation
	parameter blockSize = 32;
	parameter h_num_blocks = 20;
	parameter v_num_blocks = 15;

	//////Addresss generator
	always@(posedge iVGA_CLK,negedge iRST_n)
	begin
		// reset is the top priority
		if (!iRST_n)	
		begin
			ADDR<=12'd0;
			h_sub_cnt<=5'd0;
			v_sub_cnt<=5'd0;
		end
		
		// starting a new frame comes next
		else if (v_cnt==10'd0)	
		begin
			ADDR<=12'd0;
			h_sub_cnt<=5'd0;
			v_sub_cnt<=5'd0;
		end
		
		// v_cnt==34 is the first visible line
		// starting at the next line at h_cnt==0, check to see if ADDR is not simply ADDR+1, and whether v_sub_cnt needs to be reset
		else if (h_cnt==11'd0 && v_cnt>10'd34)
		begin		
			if (v_sub_cnt==blockSize-1)
			begin
				v_sub_cnt<=5'd0;
			end
			else
			begin
				ADDR<=ADDR-h_num_blocks;
				v_sub_cnt<=v_sub_cnt+1;
			end
		end
		
		// the visible area (640*480 pixels -> 20*15 blocks)
		else if (cBLANK_n==1'b1)
		begin
			if (h_sub_cnt==blockSize-1)
			begin
				h_sub_cnt<=5'd0; // h_sub_cnt resets when h_sub_cnt==31
				ADDR<=ADDR+1;
			end
			else
				h_sub_cnt<=h_sub_cnt+1; // if h_sub_cnt!=31
		end

	end
	
	/*
	//////dispmem: 3-bit word, 512 words, separate w/r address and clock RAM
	wire  [2:0] bgr_data_raw;
	
	dispmem dispmem_inst(
		.data(3'b0),
		.rdaddress(ADDR),
		.rdclock(iVGA_CLK),
		.wraddress(9'b0),
		.wrclock(1'b0),
		.wren(1'b0),
		.q(bgr_data_raw)
	);
	*/
	
	//////latch valid data at falling edge;
	wire	VGA_CLK_n;
	assign VGA_CLK_n = ~iVGA_CLK;

	always@(posedge VGA_CLK_n) bgr_data <= bgr_data_raw[2:0];
	
	assign b_data = {bgr_data[2], bgr_data[2], bgr_data[2], bgr_data[2], bgr_data[2], bgr_data[2], bgr_data[2], bgr_data[2]};
	assign g_data = {bgr_data[1], bgr_data[1], bgr_data[1], bgr_data[1], bgr_data[1], bgr_data[1], bgr_data[1], bgr_data[1]};
	assign r_data = {bgr_data[0], bgr_data[0], bgr_data[0], bgr_data[0], bgr_data[0], bgr_data[0], bgr_data[0], bgr_data[0]};

	//////Delay the iHD, iVD,iDEN for one clock cycle;
	always@(negedge iVGA_CLK)
	begin
	  oHS<=cHS;
	  oVS<=cVS;
	  oBLANK_n<=cBLANK_n;
	end

endmodule
