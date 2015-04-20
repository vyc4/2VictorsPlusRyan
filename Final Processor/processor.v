module processor(clock, reset, ps2_key_pressed, ps2_out, debug_data, debug_addr, debugAddrMasked, debugDataMasked,
				 statusRegRdata, fetchInstPC,
				 mdException_e_LXM, mdException_LXM_out,
				 r1, r9, r10, r11, r12);

	input 			clock, reset, ps2_key_pressed;
	input   [7:0]	ps2_out;
	
	// GRADER OUTPUTS - YOU MUST CONNECT TO YOUR DMEM
	output [31:0] debug_data;
	output [11:0] debug_addr;
	output [11:0] debugAddrMasked;   
	output [31:0] debugDataMasked;  
	output [31:0] statusRegRdata;
	output [31:0] fetchInstPC;
	output mdException_e_LXM, mdException_LXM_out;
	
	// My outputs
	output [31:0] r1, r9, r10, r11, r12;
	
	////// Processor
	////	WE and Reset signals
	wire pcReset, LFDreset, LDXreset, LXMreset, LMWreset, regfileReset, statusRegReset;
	wire pcWE, LFD_WE, LDX_WE, LXM_WE, LMW_WE, statusRegWE;
	wire writeNop_LFD, writeNop_LDX, writeNop_LXM; // writeNop_LFD: writing nop at the input to the LFD, and then it goes into decode on the next clock edge
	
	assign pcReset = reset;
	assign LFDreset = reset;
	assign LDXreset = reset;
	assign LXMreset = reset;
	assign LMWreset = reset;
	assign regfileReset = reset;
	assign statusRegReset = reset;

	assign   pcWE = ~stall_jal & ~dInstBeqBneBlt & ~stall_jr & ~stall_custj1 & ~stall_lw & ~xInstMD_dInstBEX & mdInputRDY;
	assign LFD_WE = ~stall_jr & ~stall_custj1 & ~stall_lw & ~xInstMD_dInstBEX & mdInputRDY;
	assign LDX_WE = mdInputRDY;
	assign LXM_WE = 1'b1;
	assign LMW_WE = 1'b1;
	
	assign writeNop_LFD = stall_jal | dInstBeqBneBlt | takeBranch_e_f | jumpCtrl_d_f;
	assign writeNop_LDX = stall_jr | stall_custj1 | stall_lw | xInstMD_dInstBEX | takeBranch_e_f;
	assign writeNop_LXM = ~mdInputRDY;
	
	//// Signal paths
	// pcp1: generated in fetch, and used in execute to determine new PC after jump and branch
	wire [31:0] pcp1_f_LFD, pcp1_LFD_LDX, pcp1_LDX_LXM, pcp1_LXM_LMW, pcp1_LMW_w;
	wire [31:0]             pcp1_LFD_d,   pcp1_LDX_e;
	assign pcp1_LFD_d = pcp1_LFD_LDX;
	assign pcp1_LDX_e = pcp1_LDX_LXM;
	// inst: generated in fetch, and used in decode to generate all ctrl signals
	wire [31:0] inst_f_LFD, inst_LFD_d;
	// opcode:
	wire [4:0] opcode_d_LDX, opcode_LDX_LXM, opcode_LXM_LMW, opcode_LMW_out;
	// readRegA, readRegB
	wire  [4:0] readRegA_d_LDX, readRegA_LDX_out;
	wire  [4:0] readRegB_d_LDX, readRegB_LDX_LXM, readRegB_LXM_out;
	// readDataA, readDataB, immedsx_d_LDX: readDataA and immedsx stop at the inputs to the ALU, while readDataB may be written to dmem (sw)
	wire [31:0] readDataA_d_LDX, readDataA_LDX_e;
	wire [31:0] readDataB_d_LDX, readDataB_LDX_e, readDataB_e_LXM, readDataB_LXM_m;
	wire [31:0]   immedsx_d_LDX,   immedsx_LDX_e;
	// regWE, dmemWE: generated in decode, and used in decode and memory 
	wire			regWE_d_LDX, regWE_LDX_LXM, regWE_LXM_LMW, regWE_LMW_d;
	wire			dmemWE_d_LDX, dmemWE_LDX_LXM, dmemWE_LXM_m;
	// alusrc, aluop, shamt: ctrls for the ALU
	wire 		alusrc_d_LDX, alusrc_LDX_e;
	wire  [4:0] aluop_d_LDX,  aluop_LDX_e;
	wire  [4:0] shamt_d_LDX,  shamt_LDX_e;
	// branching related(beq, bne, blt, PC)
	wire			beq_d_LDX, beq_LDX_e;
	wire 		   bne_d_LDX, bne_LDX_e;
	wire        blt_d_LDX, blt_LDX_e;
	wire [31:0] branchPC_e_f;
	wire        takeBranch_e_f;
	// jumping related(j, jr, jal)
	wire [31:0] jumpPC_d_f;
	wire		jumpCtrl_d_f;
	// memtoReg
	wire 		memtoReg_d_LDX,  memtoReg_LDX_LXM,  memtoReg_LXM_LMW,  memtoReg_LMW_w;
	// pcp1toReg
	wire 		pcp1toReg_d_LDX, pcp1toReg_LDX_LXM, pcp1toReg_LXM_LMW, pcp1toReg_LMW_w;
	// writeReg
	wire  [4:0] writeReg_d_LDX, writeReg_LDX_LXM, writeReg_LXM_LMW , writeReg_LMW_d;	
	// aluResult
	wire [31:0] aluResult_e_LXM, aluResult_LXM_m, aluResult_m_LMW, aluResult_LMW_w;
	// dmemRData
	wire [31:0] dmemRData_m_LMW, dmemRData_LMW_w; 
	// writeData
	wire [31:0] writeData_w_d;	
	// Multiply, divide
	wire multInst_d_LDX, multInst_LDX_e;
	wire divInst_d_LDX,  divInst_LDX_e;
	wire mdInputRDY;
	wire mdException_e_LXM, mdException_LXM_out;

	
	// Status Register
	wire        setxInst;
	wire [31:0] setxData;
	wire [31:0] statusRegRdata;
	statusReg statusReg1(clock, statusRegReset, setxInst, setxData, mdException_LXM_out, statusRegRdata);
	
	// wires that need to be instantiated if my own debugging outputs are disabled
	wire [31:0] fetchInstPC;
	wire [31:0] r1,r2,r3,r4,r31;
	wire [31:0] ALUinA, ALUinB;
	
	// 5 Stages and 4 Registers (PCreg is included in fetch)
	fetch fetch1(clock, pcWE, pcReset, branchPC_e_f, takeBranch_e_f, jumpPC_d_f, jumpCtrl_d_f,
				 pcp1_f_LFD, inst_f_LFD, fetchInstPC);
	
	LFD LFD1(clock, LFD_WE, LFDreset, writeNop_LFD,
			 pcp1_f_LFD,   inst_f_LFD, 
			 pcp1_LFD_LDX, inst_LFD_d);
	
	decode decode1(clock, regfileReset, inst_LFD_d, pcp1_LFD_d, regWE_LMW_d, writeReg_LMW_d, writeData_w_d, ps2_out,
				   opcode_d_LDX, readRegA_d_LDX, readRegB_d_LDX, readDataA_d_LDX, readDataB_d_LDX, immedsx_d_LDX, 
					alusrc_d_LDX, aluop_d_LDX, shamt_d_LDX, beq_d_LDX, bne_d_LDX, blt_d_LDX, dmemWE_d_LDX, memtoReg_d_LDX, pcp1toReg_d_LDX, writeReg_d_LDX, regWE_d_LDX,
				   jumpPC_d_f, jumpCtrl_d_f, statusRegRdata, setxInst, setxData, multInst_d_LDX, divInst_d_LDX,
					r1, r2, r3, r4, r9, r10, r11, r12, r31);
	
	LDX LDX1(clock, LDX_WE, LDXreset, writeNop_LDX,
			 pcp1_LFD_LDX, opcode_d_LDX,   readRegA_d_LDX,   readRegB_d_LDX,   readDataA_d_LDX, readDataB_d_LDX, immedsx_d_LDX, alusrc_d_LDX, aluop_d_LDX, shamt_d_LDX, beq_d_LDX, bne_d_LDX, blt_d_LDX, dmemWE_d_LDX,   memtoReg_d_LDX,   pcp1toReg_d_LDX,   writeReg_d_LDX,   regWE_d_LDX,   multInst_d_LDX, divInst_d_LDX,
			 pcp1_LDX_LXM, opcode_LDX_LXM, readRegA_LDX_out, readRegB_LDX_LXM, readDataA_LDX_e, readDataB_LDX_e, immedsx_LDX_e, alusrc_LDX_e, aluop_LDX_e, shamt_LDX_e, beq_LDX_e, bne_LDX_e, blt_LDX_e, dmemWE_LDX_LXM, memtoReg_LDX_LXM, pcp1toReg_LDX_LXM, writeReg_LDX_LXM, regWE_LDX_LXM, multInst_LDX_e, divInst_LDX_e);
	
	execute execute1(clock, pcp1_LDX_e, readDataA_LDX_e, readDataB_LDX_e, immedsx_LDX_e, alusrc_LDX_e, aluop_LDX_e, shamt_LDX_e, beq_LDX_e, bne_LDX_e, blt_LDX_e, bypass_aluinA, bypass_aluinB, aluResult_LXM_m, writeData_w_d, multInst_LDX_e, divInst_LDX_e,
				     ALUinA, ALUinB, aluResult_e_LXM, readDataB_e_LXM, branchPC_e_f, takeBranch_e_f, mdInputRDY, mdException_e_LXM);
	
	LXM LXM1(clock, LXM_WE, LXMreset, writeNop_LXM,
			 pcp1_LDX_LXM, opcode_LDX_LXM, readRegB_LDX_LXM, aluResult_e_LXM, readDataB_e_LXM, dmemWE_LDX_LXM, memtoReg_LDX_LXM, pcp1toReg_LDX_LXM, writeReg_LDX_LXM, regWE_LDX_LXM, mdException_e_LXM, 
			 pcp1_LXM_LMW, opcode_LXM_LMW, readRegB_LXM_out, aluResult_LXM_m, readDataB_LXM_m, dmemWE_LXM_m,   memtoReg_LXM_LMW, pcp1toReg_LXM_LMW, writeReg_LXM_LMW, regWE_LXM_LMW, mdException_LXM_out);
	
	memory memory1(clock, dmemWE_LXM_m, aluResult_LXM_m, readDataB_LXM_m, bypass_dmemDatain, writeData_w_d,
				   aluResult_m_LMW, dmemRData_m_LMW, debug_addr, debug_data, debugAddrMasked, debugDataMasked); // dmem debugging outputs connected here!
	
	LMW LMW1(clock, LMW_WE, LMWreset,
			 pcp1_LXM_LMW, opcode_LXM_LMW, aluResult_m_LMW, dmemRData_m_LMW, memtoReg_LXM_LMW, pcp1toReg_LXM_LMW, writeReg_LXM_LMW, regWE_LXM_LMW, 
			 pcp1_LMW_w,   opcode_LMW_out, aluResult_LMW_w, dmemRData_LMW_w, memtoReg_LMW_w,   pcp1toReg_LMW_w,   writeReg_LMW_d, regWE_LMW_d);
	
	writeback  writeback1(pcp1_LMW_w, aluResult_LMW_w, dmemRData_LMW_w, memtoReg_LMW_w, pcp1toReg_LMW_w, writeData_w_d);
	
	// Bypass logic
	wire [1:0] bypass_aluinA, bypass_aluinB;
	wire bypass_dmemDatain;
	
	bypass bypass1(readRegA_LDX_out, readRegB_LDX_LXM, readRegB_LXM_out, writeReg_LXM_LMW, writeReg_LMW_d,
						bypass_aluinA, bypass_aluinB, bypass_dmemDatain);
	
	// Stall logic (lw stall, jal stall, and multdiv + bex stall): prevent new instruction from going into the decode stage
	wire stall_jal, stall_jr, stall_lw, stall_custj1, dInstBeqBneBlt, xInstMD_dInstBEX;
	stall stall1(opcode_d_LDX, opcode_LDX_LXM, aluop_LDX_e, writeReg_LDX_LXM, readRegA_d_LDX, readRegB_d_LDX, writeReg_LXM_LMW, regWE_LMW_d, stall_jal, stall_jr, stall_lw, stall_custj1, dInstBeqBneBlt, xInstMD_dInstBEX);
	
endmodule


module fetch(clock, pcWE, pcReset, branchPC, takeBranch, jumpPC, jumpCtrl, pcp1, inst, fetchInstPC);
	input         clock;
	input 		  pcWE;       
	input 		  pcReset;	  // resets the pc register
	
	input  [31:0] branchPC;   // execute ->
	input 		  takeBranch; // execute ->
	input  [31:0] jumpPC;	  // decode -> 
	input         jumpCtrl;   // decode ->
	
	output [31:0] pcp1; // -> LFD
	output [31:0] inst; // -> LFD
	
	wire [31:0] currentPC; // Output of the PC register to imem 
	wire [31:0] nextPC;    // Input to the PC register
	
	output [31:0] fetchInstPC; // -> debug
	assign  fetchInstPC = currentPC;
	
	// 32-bit PC register
	regnb #(32) regnb_pc(.clock(clock), 
							   .writeEnable(pcWE), 
							   .reset(pcReset), 
							   .writeIn(nextPC), 
							   .readOut(currentPC)
							   );
	
	// Starts at 12'b000000000000 after a pc register reset
	imem myimem(.address 	(currentPC[11:0]),
					.clken		(1'b1),
					.clock		(~clock),
					.q 			(inst));
		
	// Calculate the next PC: PC=PC+1
	wire [31:0] sum;
	wire cout;
	csa32b csa32b_pcp1(1'b0, currentPC, 32'b00000000000000000000000000000001, sum, cout);
	
	assign pcp1 = sum; 
	
	// select between pcp1, branchPC, and jumpPC
	trinb #(32) trinb_pcp1(       sum, nextPC, ~takeBranch & ~jumpCtrl);
	trinb #(32) trinb_branch(branchPC, nextPC,  takeBranch);
	trinb #(32) trinb_jump(    jumpPC, nextPC,  jumpCtrl);
	
endmodule


// (L)atch (F)etch (D)ecode
module LFD(clock, WE, LFDreset, writeNop, pcp1in,  instin,
							                     pcp1out, instout);

	input         clock, WE, LFDreset;
	input			  writeNop;
	input  [31:0] pcp1in;  // fetch -> 
	input  [31:0] instin;  // fetch -> 

	output [31:0] pcp1out; // -> LDX
	output [31:0] instout; // -> decode
	
	wire [63:0] allIn;
	assign allIn =  {pcp1in,  instin};
	
	wire [63:0] regnbWriteIn;
	trinb #(64) trinb_normal(allIn, regnbWriteIn, ~writeNop);
	trinb #(64) trinb_nop(64'b0, regnbWriteIn,  writeNop);
	
	regnb #(64) regnb1(.clock(clock), 
							 .writeEnable(WE), 
							 .reset(LFDreset), 
							 .writeIn(regnbWriteIn), 
							 .readOut({pcp1out, instout}));
	
endmodule


module decode(clock, regfileReset, inst, pcp1, regWEin, writeRegin, writeDatain, ps2_out,
				  opcode, readRegA, readRegB, readDataA, readDataB, immedsx, 
				  alusrc, aluopctrl, shamt, beq, bne, blt, dmemWE, memtoReg, pcp1toReg, writeRegout, regWEout, 
				  jumpPC, jumpCtrl, statusRegRdata, setxInst, setxData, multInst, divInst,
				  r1, r2, r3, r4, r9, r10, r11, r12, r31);
				  
	input  clock, regfileReset;
	
	input  [31:0] inst; 	  	  // LFD ->
	input  [31:0] pcp1;       // LFD ->
	input         regWEin; 	  // LMW ->
	input   [4:0] writeRegin; // LMW ->
	input  [31:0] writeDatain;// writeback ->
	input  [31:0] statusRegRdata;  // statusReg ->
	input   [7:0] ps2_out;	  // ps2 module ->
	
	// _ means that the signal goes through a mux so that a 0 value can be set on the output in case of flush (take_branch)or stall (lw or jal)
	output  [4:0] opcode;		// -> LDX
	output  [4:0] readRegA,  readRegB;				// -> LDX
	output [31:0] readDataA, readDataB, immedsx; // -> LDX
	output        alusrc;  		// -> LDX
	output  [4:0] aluopctrl;	// -> LDX
	output  [4:0] shamt;			// -> LDX
	output        beq,bne,blt;	// -> LDX
	output        dmemWE;		// -> LDX
	output 		  memtoReg; 	// -> LDX
	output        pcp1toReg;   // -> LDX
	output  [4:0] writeRegout; // -> LDX
	output 		  regWEout;		// -> LDX
	output        multInst, divInst; // -> LDX
	output [31:0] jumpPC;      // -> fetch
	output        jumpCtrl;    // -> fetch
	output        setxInst; // -> statusReg
	output [31:0] setxData; // -> statusReg
	
	// for debugging only
	wire [31:0] r5, r6, r7, r8, r0;
	output [31:0] r1, r2, r3, r4, r9, r10, r11, r12, r31;
	
	// wires going into the tri-state buffer 	
	wire [31:0] readDataA, readDataB; 
	wire        alusrc;  
	wire  [4:0] aluopctrl;	
	wire        beq,bne,blt;		
	wire        dmemWE;		
	wire 		   memtoReg; 
	wire        pcp1toReg;  
	wire  [4:0] writeRegout;
	wire 		   regWEout;	
	wire [31:0] jumpPC;    
	wire        jumpCtrl;  
	wire 			setxInst;
	wire [31:0] setxData;
	wire 			multInst, divInst;
	
	// Instruction breakdown
	wire  [4:0] opcode;
	wire  [4:0] rd, rs, rt;
	wire  [4:0] shamt, aluop;
	wire [16:0] immed;
	wire [26:0] target;
	
	assign opcode = inst[31:27];
	assign     rd = inst[26:22];
	assign     rs = inst[21:17];
	assign     rt = inst[16:12];
	assign  shamt = inst[11:7];
	assign  aluop = inst[6:2];
	assign  immed = inst[16:0];
	assign target = inst[26:0];
	
	// multInst and divInst
	assign multInst = (~opcode[4] & ~opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]) & (~aluop[4] & ~aluop[3] &  aluop[2] &  aluop[1] & ~aluop[0]);// 00000 (00110)
	assign divInst  = (~opcode[4] & ~opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]) & (~aluop[4] & ~aluop[3] &  aluop[2] &  aluop[1] &  aluop[0]);// 00000 (00111)
	
	// setx:
	assign setxInst = ( opcode[4] & ~opcode[3] &  opcode[2] & ~opcode[1] &  opcode[0]); // 10101(setx)
	assign setxData = {5'b00000, target};
	
	// bex: seems to be absolute jump instead of relative jump (jump instead of branch)
	wire bexInst = ( opcode[4] & ~opcode[3] &  opcode[2] &  opcode[1] & ~opcode[0]); // 10110(bex)
	wire statusNotZero = |statusRegRdata;
	
	// Generate jumpPC and jumpCtrl (j, jal, and jr)
	wire jCtrl, jrCtrl;
	
	assign jCtrl  = (~opcode[4] & ~opcode[3] & ~opcode[2] & ~opcode[1] &  opcode[0]) |
						 (~opcode[4] & ~opcode[3] & ~opcode[2] &  opcode[1] &  opcode[0]) |
						 (bexInst & statusNotZero); // 00001(j), 00011(jal), 10110(bex)
	assign jrCtrl = (~opcode[4] & ~opcode[3] &  opcode[2] & ~opcode[1] & ~opcode[0]); // 00100(jr)
	assign jumpCtrl = jCtrl | jrCtrl;
	
	trinb #(32) trinb_j({pcp1[31:27], target}, jumpPC,  jCtrl); // j or jal or bex
	trinb #(32) trinb_jr(           readDataA, jumpPC, jrCtrl); // jr
	
	// Generate immedsx
	wire [14:0] sign;
	wire [31:0] immedsx;
	assign sign = {immed[16], immed[16], immed[16], immed[16], immed[16], immed[16], immed[16], immed[16], 
						immed[16], immed[16], immed[16], immed[16], immed[16], immed[16], immed[16]};
	assign immedsx = {sign, immed};
	
	// Generate alusrc: 1-immediate, 0-not immediate
	assign alusrc = (~opcode[4] & ~opcode[3] &  opcode[2] & ~opcode[1] &  opcode[0]) |	
						 (~opcode[4] & ~opcode[3] &  opcode[2] &  opcode[1] &  opcode[0]) |	
						 (~opcode[4] &  opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]); // 00101(addi), 00111(sw), 01000(lw)
	
	// Generate aluopctrl
	wire Rtype =    (~opcode[4] & ~opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]); // 00000(R)
	wire Itypeadd = (~opcode[4] & ~opcode[3] &  opcode[2] & ~opcode[1] &  opcode[0]) |
						 (~opcode[4] & ~opcode[3] &  opcode[2] &  opcode[1] &  opcode[0]) |
						 (~opcode[4] &  opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]); // 00101(addi), 00111(sw), 01000(lw)
	wire Itypesub = ( opcode[4] & ~opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]) |
						 (~opcode[4] & ~opcode[3] & ~opcode[2] &  opcode[1] & ~opcode[0]) |
						 (~opcode[4] & ~opcode[3] &  opcode[2] &  opcode[1] & ~opcode[0]); // 10000(beq), 00010(bne), 00110(blt)
	
	trinb #(5) trinb_Rtype(      aluop, aluopctrl, Rtype);
	trinb #(5) trinb_Itypeadd(5'b00000, aluopctrl, Itypeadd);
	trinb #(5) trinb_Itypesub(5'b00001, aluopctrl, Itypesub);
	
	// Generate branch control
	assign beq = ( opcode[4] & ~opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]); // 10000(beq)
	assign bne = (~opcode[4] & ~opcode[3] & ~opcode[2] &  opcode[1] & ~opcode[0]); // 00010(bne)
	assign blt = (~opcode[4] & ~opcode[3] &  opcode[2] &  opcode[1] & ~opcode[0]); // 00110(blt)

	// Generate dmem write enable 
	assign dmemWE = (~opcode[4] & ~opcode[3] &  opcode[2] &  opcode[1] &  opcode[0]); // 00111(sw)
	
	// Generate memtoReg
	assign memtoReg = (~opcode[4] &  opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]); // 01000(lw)
	
	// Generate pcp1toReg
	assign pcp1toReg = (~opcode[4] & ~opcode[3] & ~opcode[2] &  opcode[1] &  opcode[0]); // 00011(jal)
	
	// writeRegout control: $rd or $r0 (not really writing to $r0)
	wire   rdWselect, r31Wselect;
	assign rdWselect = (~opcode[4] & ~opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]) |
							 (~opcode[4] & ~opcode[3] &  opcode[2] & ~opcode[1] &  opcode[0]) |
							 (~opcode[4] &  opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]); // 00000(R), 00101(addi), 01000(lw)
	assign r31Wselect =(~opcode[4] & ~opcode[3] & ~opcode[2] &  opcode[1] &  opcode[0]); // 00011(jal)
	
	trinb #(5) trinb_write_r0( 5'b00000, writeRegout, ~rdWselect & ~r31Wselect);
	trinb #(5) trinb_write_rd(       rd, writeRegout,  rdWselect);
	trinb #(5) trinb_write_r31(5'b11111, writeRegout, r31Wselect);
	
	// Generate register write enable
	assign regWEout = (~opcode[4] & ~opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]) |
							(~opcode[4] & ~opcode[3] &  opcode[2] & ~opcode[1] &  opcode[0]) |
							(~opcode[4] &  opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]) |
							(~opcode[4] & ~opcode[3] & ~opcode[2] &  opcode[1] &  opcode[0]); // 00000(R), 00101(addi), 01000(lw), 00011(jal)
	
	// readRegA control: select between $rs and $rd (read from $r0 if the instruction doesn't actually need to read)
	wire [4:0] readRegA;
	wire rdReadAEnable, rsReadAEnable;
	
	assign rdReadAEnable = ( opcode[4] & ~opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]) |
								  (~opcode[4] & ~opcode[3] & ~opcode[2] &  opcode[1] & ~opcode[0]) |
								  (~opcode[4] & ~opcode[3] &  opcode[2] & ~opcode[1] & ~opcode[0]) |
								  (~opcode[4] & ~opcode[3] &  opcode[2] &  opcode[1] & ~opcode[0]); // 10000(beq), 00010(bne), 00100(jr), 00110(blt)
	
	assign rsReadAEnable = (~opcode[4] & ~opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]) |
								  (~opcode[4] & ~opcode[3] &  opcode[2] & ~opcode[1] &  opcode[0]) |
								  (~opcode[4] & ~opcode[3] &  opcode[2] &  opcode[1] &  opcode[0]) |
								  (~opcode[4] &  opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]); // 00000(R), 00101(addi), 00111(sw), 01000(lw)
	
	trinb #(5) trinb_readA_r0(5'b00000, readRegA, ~rdReadAEnable & ~rsReadAEnable);
	trinb #(5) trinb_readA_rd(      rd, readRegA,  rdReadAEnable);
	trinb #(5) trinb_readA_rs(      rs, readRegA,  rsReadAEnable);
	
	// readRegB control: select between $rs, $rt and $rd (read from $r0 if the instruction doesn't actually need to read)
	wire [4:0] readRegB;
	wire rsReadBEnable, rtReadBEnable, rdReadBEnable;
	
	assign rsReadBEnable = ( opcode[4] & ~opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]) |
								  (~opcode[4] & ~opcode[3] & ~opcode[2] &  opcode[1] & ~opcode[0]) |
								  (~opcode[4] & ~opcode[3] &  opcode[2] &  opcode[1] & ~opcode[0]); // 10000(beq), 00010(bne), 00110(blt)
	assign rtReadBEnable = (~opcode[4] & ~opcode[3] & ~opcode[2] & ~opcode[1] & ~opcode[0]); // 00000(R)
	assign rdReadBEnable = (~opcode[4] & ~opcode[3] &  opcode[2] &  opcode[1] &  opcode[0]); // 00111(sw)
	
	trinb #(5) trinb_readB_r0(5'b00000, readRegB, ~rsReadBEnable & ~rtReadBEnable & ~rdReadBEnable);
	trinb #(5) trinb_readB_rs(      rs, readRegB,  rsReadBEnable);
	trinb #(5) trinb_readB_rt(      rt, readRegB,  rtReadBEnable);
	trinb #(5) trinb_readB_rd(      rd, readRegB,  rdReadBEnable);
	
	// Our custj1 instruction 
	wire custj1;
	assign custj1 = ( opcode[4] & ~opcode[3] &  opcode[2] &  opcode[1] &  opcode[0]); // 10111(custj1)
	
	wire [31:0] writeData;
	wire [31:0] writeReg;
	wire 			regWE;
	assign regWE = regWEin | custj1;
	
	trinb #(32) trinb_WB_data(     writeDatain, writeData,  regWEin); // instruction in writeback needs to write to regfile (high priority)
	trinb #(32) trinb_KB_data({24'b0, ps2_out}, writeData, ~regWEin & custj1); // instruction in decode is custj1 (low priority)
	
	trinb #(32) trinb_WB_reg(       writeRegin, writeReg,  regWEin); // instruction in writeback needs to write to regfile (high priority)
	trinb #(32) trinb_KB_reg({27'b0, 5'b11101}, writeReg, ~regWEin & custj1); // instruction in decode is custj1 (low priority)

	// regfile: inverted clock signal 
	regfile regfile1(~clock, regWE, regfileReset, 
	                 writeReg,  readRegA,  readRegB, 
			           writeData, readDataA, readDataB,
						  r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r31);
	
endmodule


// (L)atch (D)ecode E(x)ecute
module LDX(clock, WE, LDXreset, writeNop, pcp1in,  opcodein,  readRegAin,  readRegBin,  readDataAin,  readDataBin,  immedsxin,  alusrcin,  aluopin,  shamtin,  beqin, bnein,  bltin,  dmemWEin,  memtoRegin,  pcp1toRegin,  writeRegin,  regWEin,  multInstin,  divInstin,
										            pcp1out, opcodeout, readRegAout, readRegBout, readDataAout, readDataBout, immedsxout, alusrcout, aluopout, shamtout, beqout, bneout, bltout, dmemWEout, memtoRegout, pcp1toRegout, writeRegout, regWEout, multInstout, divInstout);

	input         clock, WE, LDXreset;
	input 		  writeNop;
	
	input  [31:0] pcp1in;		// LFD ->
	input   [4:0] opcodein;    // LFD ->
	input   [4:0] readRegAin, readRegBin; // decode ->
	input  [31:0] readDataAin,  readDataBin, immedsxin; // decode ->
	input         alusrcin;    // decode ->
	input   [4:0] aluopin;     // decode ->
	input   [4:0] shamtin;     // decode ->
	input			  beqin;			// decode ->
	input         bnein;	      // decode ->
	input         bltin;	      // decode ->
	input         dmemWEin;		// decode ->
	input 		  memtoRegin;	// decode ->
	input         pcp1toRegin; // decode ->
	input   [4:0] writeRegin;	// decode ->
	input 		  regWEin;		// decode ->
	input 		  multInstin, divInstin; // decode ->
	
	output [31:0] pcp1out;		// -> LXM
	output  [4:0] opcodeout;   // -> LXM (also stall)
	output  [4:0] readRegAout, readRegBout; // ->bypass
	output [31:0] readDataAout, readDataBout, immedsxout; // -> execute
	output        alusrcout;   // -> execute
	output  [4:0] aluopout;    // -> execute
	output  [4:0] shamtout;    // -> execute
	output		  beqout;		// -> execute
	output        bneout;	   // -> execute
	output        bltout;	   // -> execute
	output        dmemWEout;	// -> LXM
	output 		  memtoRegout;	// -> LXM
	output        pcp1toRegout;// -> LXM
	output  [4:0] writeRegout; // -> LXM
	output 		  regWEout;		// -> LXM
	output 		  multInstout, divInstout; // -> execute
	
	wire [167:0] allIn;
	assign allIn =  {pcp1in,  opcodein,  readRegAin,  readRegBin,  readDataAin,  readDataBin,  immedsxin,  alusrcin,  aluopin,  shamtin,  beqin,  bnein,  bltin,  dmemWEin,  memtoRegin,  pcp1toRegin,  writeRegin,  regWEin,  multInstin,  divInstin};
	
	wire [167:0] regnbWriteIn;
	trinb #(168) trinb_normal(allIn, regnbWriteIn, ~writeNop);
	trinb #(168) trinb_nop(168'b0, regnbWriteIn,  writeNop);
	
	regnb #(168) regnb1(.clock(clock), 
							  .writeEnable(WE), 
							  .reset(LDXreset), 
							  .writeIn(regnbWriteIn), 
							  .readOut({pcp1out, opcodeout, readRegAout, readRegBout, readDataAout, readDataBout, immedsxout, alusrcout, aluopout, shamtout, beqout, bneout, bltout, dmemWEout, memtoRegout, pcp1toRegout, writeRegout, regWEout, multInstout, divInstout}));
	
endmodule


module execute(clock, pcp1, readDataA, readDataB, immedsx, alusrc, aluop, shamt, beq, bne, blt, bypass_aluinA, bypass_aluinB, aluResult_LXM_m, writeData_w_d, multInst, divInst,
					ALUinA, ALUinB, aluResult, readDataBout, branchPC, takeBranch, mdInputRDY, mdException);
	input   	     clock;
	
	input  [31:0] pcp1;   // LDX ->
	input  [31:0] readDataA, readDataB, immedsx; // LDX ->
	input         alusrc; // LDX ->
	input   [4:0] aluop;  // LDX ->
	input   [4:0] shamt;  // LDX ->
	input			  beq;	 // LDX ->
	input         bne;	 // LDX ->
	input         blt;	 // LDX ->
	input   [1:0] bypass_aluinA, bypass_aluinB; // bypass ->
	input  [31:0] aluResult_LXM_m; // LXM ->
	input  [31:0] writeData_w_d; // writeback ->
	input 		  multInst, divInst; // LDX ->
	
	output [31:0] ALUinA, ALUinB; // -> debug
	output [31:0] aluResult; 	 // -> LXM
	output [31:0] readDataBout; // -> LXM
	output [31:0] branchPC;		 // -> fetch
	output        takeBranch;   // -> fetch
	output        mdInputRDY;   // -> PC, LFD LDX (WE)
	output        mdException;  // -> LXM
	
	// pass readDataB to memory stage as dmem_writeData (changed from readDataB to ALUinBbypass; otherwire wx bypass won't help sw)
	assign readDataBout = ALUinBbypass;
	
	// Bypass Muxes
	wire [31:0] ALUinA;
	wire ALUinA_MXbypass, ALUinA_WXbypass, ALUinA_NObypass;
	
	assign ALUinA_MXbypass = bypass_aluinA[0];
	assign ALUinA_WXbypass = ~ bypass_aluinA[0] & bypass_aluinA[1];
	assign ALUinA_NObypass = ~ bypass_aluinA[0] & ~ bypass_aluinA[1];
	
	trinb #(32) trinb_ALUinA_MXbypass(aluResult_LXM_m, ALUinA, ALUinA_MXbypass);
	trinb #(32) trinb_ALUinA_WXbypass(writeData_w_d,   ALUinA, ALUinA_WXbypass);
	trinb #(32) trinb_ALUinA_NObypass(readDataA,       ALUinA, ALUinA_NObypass);
	
	wire [31:0] ALUinBbypass;
	wire ALUinB_MXbypass, ALUinB_WXbypass, ALUinB_NObypass;
	
	assign ALUinB_MXbypass = bypass_aluinB[0];
	assign ALUinB_WXbypass = ~ bypass_aluinB[0] & bypass_aluinB[1];
	assign ALUinB_NObypass = ~ bypass_aluinB[0] & ~ bypass_aluinB[1];
	
	trinb #(32) trinb_ALUinB_MXbypass(aluResult_LXM_m, ALUinBbypass, ALUinB_MXbypass);
	trinb #(32) trinb_ALUinB_WXbypass(writeData_w_d,   ALUinBbypass, ALUinB_WXbypass);
	trinb #(32) trinb_ALUinB_NObypass(readDataB,       ALUinBbypass, ALUinB_NObypass);
		
	// ALU
	wire [31:0] aluBasicResult;
	wire isNotEqual, isLessThan;	// required by bne, blt
	
	wire [31:0] ALUinB;
	trinb #(32) trinb_readDataB(ALUinBbypass, ALUinB, ~alusrc);
	trinb #(32) trinb_immedsx(       immedsx, ALUinB,  alusrc);
	
	alu alu1(.data_operandA(ALUinA), .data_operandB(ALUinB), .ctrl_ALUopcode(aluop), .ctrl_shiftamt(shamt), 
				.data_result(aluBasicResult), .isNotEqual(isNotEqual), .isLessThan(isLessThan));
	
			
	// Branch: bne blt
	wire cout;
	assign takeBranch = (beq & ~isNotEqual) | (bne & isNotEqual) | (blt & isLessThan); // invert isNotEqual to get isEqual
	csa32b csa32b1(1'b0, pcp1, immedsx[31:0], branchPC, cout); // branchPC = pcp1 + N

	
	// MultDiv: stall until mdInputRDY is high again
	wire [31:0] mdResult;
	wire mdException;
	wire mdInputRDY;		
	wire mdResultRDY;
	
	multdiv multdiv1(.data_operandA(ALUinA), .data_operandB(ALUinB), .ctrl_MULT(multInst), .ctrl_DIV(divInst), 
						  .clock(~clock), .data_result(mdResult), .data_exception(mdException), .data_inputRDY(mdInputRDY), .data_resultRDY(mdResultRDY));
	
	// Mux the output of the ALU and MultDiv
	trinb #(32) trinb_alu(aluBasicResult, aluResult, ~multInst & ~divInst);
	trinb #(32) trinb_multdiv(  mdResult, aluResult,  multInst | divInst);
	
endmodule


// (L)atch E(x)ecute (M)emory
module LXM(clock, WE, LXMreset, writeNop, pcp1in,  opcodein,  readRegBin,  aluResultin,  readDataBin,  dmemWEin,  memtoRegin,  pcp1toRegin,  writeRegin,  regWEin,  mdExceptionin,
														pcp1out, opcodeout, readRegBout, aluResultout, readDataBout, dmemWEout, memtoRegout, pcp1toRegout, writeRegout, regWEout, mdExceptionout);
							 
	input         clock, WE, LXMreset;
	input			  writeNop;
	input  [31:0] pcp1in; 		// LDX ->
	input   [4:0] opcodein;    // LDX ->
	input   [4:0] readRegBin;  // LDX ->
	input  [31:0] aluResultin,  readDataBin; // execute ->
	input         dmemWEin;		// LDX ->
	input 		  memtoRegin;	// LDX ->
	input 		  pcp1toRegin; // LDX ->
	input   [4:0] writeRegin;	// LDX ->
	input 		  regWEin;		// LDX ->
	input         mdExceptionin; // execute ->
	
	output [31:0] pcp1out;		// -> LMW
	output  [4:0] opcodeout;   // -> LMW
	output  [4:0] readRegBout;  // LDX ->
	output [31:0] aluResultout, readDataBout; // -> memory
	output        dmemWEout;	// -> memory
	output 		  memtoRegout;	// -> LMW
	output	     pcp1toRegout;// -> LMW
	output  [4:0] writeRegout;	// -> LMW
	output 		  regWEout;		// -> LMW
	output        mdExceptionout; // -> statusReg

	wire [115:0] allIn;
	assign allIn = {pcp1in,  opcodein,  readRegBin,  aluResultin,  readDataBin,  dmemWEin,  memtoRegin,  pcp1toRegin,  writeRegin,  regWEin,  mdExceptionin};
	
	wire [115:0] regnbWriteIn;
	trinb #(116) trinb_normal(allIn, regnbWriteIn, ~writeNop);
	trinb #(116) trinb_nop(116'b0, regnbWriteIn,  writeNop);
	
	regnb #(116) regnb1(.clock(clock), 
							 .writeEnable(WE), 
							 .reset(LXMreset), 
							 .writeIn(regnbWriteIn), 
							 .readOut({pcp1out, opcodeout, readRegBout, aluResultout, readDataBout, dmemWEout, memtoRegout, pcp1toRegout, writeRegout, regWEout, mdExceptionout}));
							 
endmodule


module memory(clock, dmemWE, aluResult, dmemWDatain, bypass_dmemDatain, writeData_w_d,
				  aluResultOut, dmemRData, debugAddr, debugData, debugAddrMasked, debugDataMasked);
				  
	input clock;
	
	input         dmemWE; // LXM ->
	input  [31:0] aluResult, dmemWDatain; // LXM ->
	input         bypass_dmemDatain; // bypass ->
	input  [31:0] writeData_w_d; // writeback ->

	output [31:0] aluResultOut, dmemRData; // -> LMW
	output [11:0] debugAddr;   // -> debug
	output [31:0] debugData;   // -> debug
	output [11:0] debugAddrMasked;   // -> debug
	output [31:0] debugDataMasked;   // -> debug
	
	assign aluResultOut = aluResult;
	
	
	// WMbypass
	wire [31:0] dmemWData;
	
	trinb #(32) trinb_dmemDatain_WMbypass(writeData_w_d, dmemWData,  bypass_dmemDatain);
	trinb #(32) trinb_dmemDatain_NObypass(dmemWDatain,   dmemWData, ~bypass_dmemDatain);
	
	
	dmem mydmem(.address(aluResult[11:0]),
					.clock(~clock),
					.data	(dmemWData),
					.wren	(dmemWE),
					.q		(dmemRData));
	
	assign debugAddr = aluResult[11:0];
	assign debugData = dmemWData;
	
	// Using the dmemWE signal to mask the debugAddr and debugData output
	trinb #(12) trinb_nowriteAddr(12'b000000000000, debugAddrMasked, ~dmemWE);
	trinb #(12) trinb_writeAddr(   aluResult[11:0], debugAddrMasked,  dmemWE);
	
	trinb #(32) trinb_nowriteData(32'b00000000000000000000000000000000, debugDataMasked, ~dmemWE);
	trinb #(32) trinb_writeData(                             dmemWData, debugDataMasked,  dmemWE);
	
endmodule


// (L)atch (M)emory (W)riteback
module LMW(clock, WE, LMWreset, pcp1in,  opcodein,  aluResultin,  dmemRDatain,  memtoRegin,  pcp1toRegin,  writeRegin,  regWEin, 
										  pcp1out, opcodeout, aluResultout, dmemRDataout, memtoRegout, pcp1toRegout, writeRegout, regWEout);
							 
	input         clock, WE, LMWreset;
	
	input  [31:0] pcp1in; 	  // LXM ->
	input   [4:0] opcodein;   // LXM ->
	input  [31:0] aluResultin, dmemRDatain; // memory ->
	input         memtoRegin; // LXM ->
	input 		  pcp1toRegin;// LXM ->
	input   [4:0] writeRegin; // LXM ->
	input 		  regWEin;    // LXM ->
	
	output [31:0] pcp1out;     // -> writeback
	output  [4:0] opcodeout;   // -> out
	output [31:0] aluResultout, dmemRDataout; // -> writeback
	output 		  memtoRegout; // -> writeback
	output 		  pcp1toRegout; // ->writeback
	output  [4:0] writeRegout; // -> decode
	output 		  regWEout;    // -> decode
	
	
	regnb #(109) regnb1(.clock(clock), 
							 .writeEnable(WE), 
							 .reset(LMWreset), 
							 .writeIn({pcp1in,  opcodein,  aluResultin,  dmemRDatain,  memtoRegin,  pcp1toRegin,  writeRegin,  regWEin}), 
							 .readOut({pcp1out, opcodeout, aluResultout, dmemRDataout, memtoRegout, pcp1toRegout, writeRegout, regWEout})
							 );

endmodule


module writeback(pcp1in, aluResult, dmemRData, memtoReg, pcp1toReg, writeData);

	input  [31:0] pcp1in; // LMW ->
	input  [31:0] aluResult, dmemRData; // LMW ->
	input         memtoReg, pcp1toReg; // LMW ->
	
	output [31:0] writeData; // -> decode
	
	trinb #(32) trinb_alutoReg( aluResult, writeData, ~memtoReg & ~pcp1toReg);
	trinb #(32) trinb_memtoReg( dmemRData, writeData,  memtoReg);
	trinb #(32) trinb_pcp1toReg(   pcp1in, writeData,  pcp1toReg);
	
endmodule


module statusReg(clock, statusRegReset, setxInst, setxData, mdException, statusRegRdata);
	input         clock;
	input         statusRegReset;
	input         setxInst; // decode ->
	input  [31:0] setxData; // decode ->
	input         mdException; // LXM ->
	output [31:0] statusRegRdata;
	
	wire [31:0] statusRegWdata;
	trinb #(32) trinb_setxInst(setxData, statusRegWdata,  setxInst);
	trinb #(32) trinb_mdException(32'b00000000000000000000000000000001, statusRegWdata,  mdException);
	
	regnb #(32) regnb1(.clock(~clock), .writeEnable(setxInst|mdException), .reset(statusRegReset), .writeIn(statusRegWdata), .readOut(statusRegRdata));

endmodule


module stall(opcode_d_LDX, opcode_LDX_out, aluop_LDX_out, writeReg_LDX_LXM, readRegA_d_LDX, readRegB_d_LDX, writeReg_LXM_LMW, regWE_LMW_d, 
				 stall_jal, stall_jr, stall_lw, stall_custj1, dInstBeqBneBlt, xInstMD_dInstBEX);
	input [4:0] opcode_d_LDX, opcode_LDX_out, aluop_LDX_out, writeReg_LDX_LXM, readRegA_d_LDX, readRegB_d_LDX, writeReg_LXM_LMW;
	input regWE_LMW_d;
	
	output stall_jal, stall_jr, stall_lw, stall_custj1, dInstBeqBneBlt, xInstMD_dInstBEX;	

	// lw
	wire   xInstLW;
	assign xInstLW = (~opcode_LDX_out[4] &  opcode_LDX_out[3] & ~opcode_LDX_out[2] & ~opcode_LDX_out[1] & ~opcode_LDX_out[0]); //01000(lw)
	
	wire   dRSAisxRD;
	assign dRSAisxRD = ~ ( (readRegA_d_LDX[4] ^ writeReg_LDX_LXM[4]) | 
								  (readRegA_d_LDX[3] ^ writeReg_LDX_LXM[3]) | 
								  (readRegA_d_LDX[2] ^ writeReg_LDX_LXM[2]) | 
								  (readRegA_d_LDX[1] ^ writeReg_LDX_LXM[1]) | 
								  (readRegA_d_LDX[0] ^ writeReg_LDX_LXM[0]) );
	
	wire   dRSBisxRD;
	assign dRSBisxRD = ~ ( (readRegB_d_LDX[4] ^ writeReg_LDX_LXM[4]) | 
								  (readRegB_d_LDX[3] ^ writeReg_LDX_LXM[3]) | 
								  (readRegB_d_LDX[2] ^ writeReg_LDX_LXM[2]) | 
								  (readRegB_d_LDX[1] ^ writeReg_LDX_LXM[1]) | 
								  (readRegB_d_LDX[0] ^ writeReg_LDX_LXM[0]) );

	wire   dInstNotStore;
	assign dInstNotStore = ~ (~opcode_d_LDX[4] & ~opcode_d_LDX[3] &  opcode_d_LDX[2] &  opcode_d_LDX[1] &  opcode_d_LDX[0]); //00111(sw)
	
	assign stall_lw = xInstLW & ( dRSAisxRD | ( dRSBisxRD & dInstNotStore ) );
	
	// jal
	wire   xInstJAL;
	assign xInstJAL = (~opcode_LDX_out[4] & ~opcode_LDX_out[3] & ~opcode_LDX_out[2] &  opcode_LDX_out[1] &  opcode_LDX_out[0]); //00011(jal)
	
	assign stall_jal = xInstJAL;
	
	// jr: jr in decode stage while the insts in execute or memory stage has r31 as RD (writing to RD at writeback)
	wire dInstJR;
	assign dInstJR = (~opcode_d_LDX[4] & ~opcode_d_LDX[3] &  opcode_d_LDX[2] & ~opcode_d_LDX[1] & ~opcode_d_LDX[0]); //00100(jr)
	
	wire xRDisR31, mRDisR31, xRDormRDisR31;
	assign xRDisR31 = writeReg_LDX_LXM[4] & writeReg_LDX_LXM[3] & writeReg_LDX_LXM[2] & writeReg_LDX_LXM[1] & writeReg_LDX_LXM[0]; // 31 = 5'b11111
	assign mRDisR31 = writeReg_LXM_LMW[4] & writeReg_LXM_LMW[3] & writeReg_LXM_LMW[2] & writeReg_LXM_LMW[1] & writeReg_LXM_LMW[0]; // 31 = 5'b11111
	assign xRDormRDisR31 = xRDisR31 | mRDisR31;
	
	assign stall_jr = dInstJR & xRDormRDisR31;
	
	// beq bne blt
	assign dInstBeqBneBlt = ( opcode_d_LDX[4] & ~opcode_d_LDX[3] & ~opcode_d_LDX[2] & ~opcode_d_LDX[1] & ~opcode_d_LDX[0]) |
									(~opcode_d_LDX[4] & ~opcode_d_LDX[3] & ~opcode_d_LDX[2] &  opcode_d_LDX[1] & ~opcode_d_LDX[0]) |
								   (~opcode_d_LDX[4] & ~opcode_d_LDX[3] &  opcode_d_LDX[2] &  opcode_d_LDX[1] & ~opcode_d_LDX[0]); // 10000(beq), 00010(bne), 00110(blt)
	
	// multdiv
	wire xInstMD, dInstBEX;
	wire xInstMD_dInstBEX;
	assign xInstMD  = (~opcode_LDX_out[4] & ~opcode_LDX_out[3] & ~opcode_LDX_out[2] & ~opcode_LDX_out[1] & ~opcode_LDX_out[0]) & 
						   (~aluop_LDX_out[4] & ~aluop_LDX_out[3] &  aluop_LDX_out[2] &  aluop_LDX_out[1]); //00000(00110/00111)(mult/div)
	assign dInstBEX = ( opcode_d_LDX[4] & ~opcode_d_LDX[3] &  opcode_d_LDX[2] &  opcode_d_LDX[1] & ~opcode_d_LDX[0]); //10110(bex)
	
	assign xInstMD_dInstBEX = xInstMD & dInstBEX;
	
	// custj1
	wire dInstCUSTJ1;
	assign dInstCUSTJ1 = ( opcode_d_LDX[4] & ~opcode_d_LDX[3] &  opcode_d_LDX[2] &  opcode_d_LDX[1] &  opcode_d_LDX[0]); //10111(custj1)
	
	assign stall_custj1 = dInstCUSTJ1 & regWE_LMW_d;
	
endmodule


module bypass(readRegA_LDX_out, readRegB_LDX_out, readRegB_LXM_out, writeReg_LXM_LMW, writeReg_LMW_d, 
				  bypass_aluinA, bypass_aluinB, bypass_dmemDatain);
				  
	input  [4:0] readRegA_LDX_out, readRegB_LDX_out, readRegB_LXM_out, writeReg_LXM_LMW, writeReg_LMW_d;
	
	output [1:0] bypass_aluinA, bypass_aluinB;
	output bypass_dmemDatain;
	
	// readReg and WriteReg both default to 0 when not present/needed; make sure they aren't 0 when bypassing
	wire readRegA_LDX_out_NOT_ZERO, readRegB_LDX_out_NOT_ZERO, readRegB_LXM_out_NOT_ZERO;
	assign readRegA_LDX_out_NOT_ZERO = |readRegA_LDX_out;
	assign readRegB_LDX_out_NOT_ZERO = |readRegB_LDX_out;
	assign readRegB_LXM_out_NOT_ZERO = |readRegB_LXM_out;
	
	// MX
	assign bypass_aluinA[0] = ~ ( (readRegA_LDX_out[4] ^ writeReg_LXM_LMW[4]) | 
											(readRegA_LDX_out[3] ^ writeReg_LXM_LMW[3]) | 
											(readRegA_LDX_out[2] ^ writeReg_LXM_LMW[2]) | 
											(readRegA_LDX_out[1] ^ writeReg_LXM_LMW[1]) | 
											(readRegA_LDX_out[0] ^ writeReg_LXM_LMW[0]) ) & readRegA_LDX_out_NOT_ZERO;
	
	assign bypass_aluinB[0] = ~ ( (readRegB_LDX_out[4] ^ writeReg_LXM_LMW[4]) | 
											(readRegB_LDX_out[3] ^ writeReg_LXM_LMW[3]) | 
											(readRegB_LDX_out[2] ^ writeReg_LXM_LMW[2]) | 
											(readRegB_LDX_out[1] ^ writeReg_LXM_LMW[1]) | 
											(readRegB_LDX_out[0] ^ writeReg_LXM_LMW[0]) ) & readRegB_LDX_out_NOT_ZERO;
	
	// WX
	assign bypass_aluinB[1] = ~ ( (readRegB_LDX_out[4] ^ writeReg_LMW_d[4]) | 
											(readRegB_LDX_out[3] ^ writeReg_LMW_d[3]) | 
											(readRegB_LDX_out[2] ^ writeReg_LMW_d[2]) | 
											(readRegB_LDX_out[1] ^ writeReg_LMW_d[1]) | 
											(readRegB_LDX_out[0] ^ writeReg_LMW_d[0]) )   & readRegB_LDX_out_NOT_ZERO;
	
	assign bypass_aluinA[1] = ~ ( (readRegA_LDX_out[4] ^ writeReg_LMW_d[4]) | 
											(readRegA_LDX_out[3] ^ writeReg_LMW_d[3]) | 
											(readRegA_LDX_out[2] ^ writeReg_LMW_d[2]) | 
											(readRegA_LDX_out[1] ^ writeReg_LMW_d[1]) | 
											(readRegA_LDX_out[0] ^ writeReg_LMW_d[0]) )   & readRegA_LDX_out_NOT_ZERO;
						
	// WM														
	assign bypass_dmemDatain = ~ ( (readRegB_LXM_out[4] ^ writeReg_LMW_d[4]) | 
											 (readRegB_LXM_out[3] ^ writeReg_LMW_d[3]) | 
											 (readRegB_LXM_out[2] ^ writeReg_LMW_d[2]) | 
											 (readRegB_LXM_out[1] ^ writeReg_LMW_d[1]) | 
											 (readRegB_LXM_out[0] ^ writeReg_LMW_d[0]) )  & readRegB_LXM_out_NOT_ZERO;
	
endmodule


module regfile(clock, ctrl_writeEnable, ctrl_reset, ctrl_writeReg, ctrl_readRegA, ctrl_readRegB, data_writeReg, data_readRegA, data_readRegB,
					r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r31);
	input         clock, ctrl_writeEnable, ctrl_reset;
	input   [4:0] ctrl_writeReg, ctrl_readRegA, ctrl_readRegB;
	input  [31:0] data_writeReg;
	output [31:0] data_readRegA, data_readRegB;
	
	// for debugging
	output [31:0] r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r31;
	
	// Circuitry connecting ctrl_writeEnable, ctrl_writeReg to the register file
	wire [31:0] decoded_writeReg;
	wire [31:0] reg32b_writeEnable;
	
	dec5to32 dec_writeReg(ctrl_writeReg, decoded_writeReg);
	
	genvar n;
	generate
		for (n=0;n<32;n=n+1) begin: loop_and
				and a_and(reg32b_writeEnable[n], decoded_writeReg[n], ctrl_writeEnable);
		end
	endgenerate
	
	// Generate 32 x (32bit registers and two 32bit tri-state buffers)
	wire [31:0] readBus[0:31];
	wire [31:0] triA_enable;
	wire [31:0] triB_enable;
	
	// debugging
	assign r0  = readBus[0];
	assign r1  = readBus[1];
	assign r2  = readBus[2];
	assign r3  = readBus[3];
	assign r4  = readBus[4];
	assign r5  = readBus[5];
	assign r6  = readBus[6];
	assign r7  = readBus[7];
	assign r8  = readBus[8];
	assign r9  = readBus[9];
	assign r10 = readBus[10];
	assign r11 = readBus[11];
	assign r12 = readBus[12];
	assign r31 = readBus[31];
	
	
	// Modified $r0 to always store 0 (always reset, input always connected to zero)
	regnb #(32) a_reg(clock, reg32b_writeEnable[0], 1'b1, 32'b0, readBus[0]);
	trinb #(32) trinb_readRegA(readBus[0], data_readRegA, triA_enable[0]);
	trinb #(32) trinb_readRegB(readBus[0], data_readRegB, triB_enable[0]);		
	
	generate
		for (n=1;n<32;n=n+1) begin: reg32bs
			regnb #(32) a_reg(clock, reg32b_writeEnable[n], ctrl_reset, data_writeReg, readBus[n]);
			trinb #(32) trinb_readRegA(readBus[n], data_readRegA, triA_enable[n]);
			trinb #(32) trinb_readRegB(readBus[n], data_readRegB, triB_enable[n]);
		end
	endgenerate
		
	// Generate two 5-to-32 decoders that controls the tri-state buffers
	dec5to32 dec_readRegA(ctrl_readRegA, triA_enable);
	dec5to32 dec_readRegB(ctrl_readRegB, triB_enable);
	
endmodule

module dec5to32(in, out);
	input [4:0] in;
	output [31:0] out;
	wire [3:0] en;
	
	dec2to4 dec2to4_0(in[4:3], en[3:0]);
	dec3to8 dec3to8_3(in[2:0], out[31:24], en[3]);
	dec3to8 dec3to8_2(in[2:0], out[23:16], en[2]);
	dec3to8 dec3to8_1(in[2:0], out[15:8], en[1]);
	dec3to8 dec3to8_0(in[2:0], out[7:0], en[0]);
endmodule

module dec3to8(in, out, en);
	input en;
	input [2:0] in;
	output [7:0] out;
	
	assign out[7] = in[2] & in[1] & in[0] & en;
	assign out[6] = in[2] & in[1] &~in[0] & en;
	assign out[5] = in[2] &~in[1] & in[0] & en;
	assign out[4] = in[2] &~in[1] &~in[0] & en;
	assign out[3] =~in[2] & in[1] & in[0] & en;
	assign out[2] =~in[2] & in[1] &~in[0] & en;
	assign out[1] =~in[2] &~in[1] & in[0] & en;
	assign out[0] =~in[2] &~in[1] &~in[0] & en;
endmodule

module dec2to4(in, out);
	input [1:0] in;
	output [3:0] out;
	
	assign out[3] = in[1] & in[0];
	assign out[2] = in[1] &~in[0];
	assign out[1] =~in[1] & in[0];
	assign out[0] =~in[1] &~in[0];
endmodule


/*	Use Modified Booth's algorithm (4-bit + 1 helper bit) for multiplication
	Multiplication result available in four clock cycles
	Use the most simple algorithm for division
	Division result available in 16 clock cycles
	
	For multiplication, assume both data_operandA and data_operandB are 32-bit signed integers (-2,147,483,649 ~ 2,147,483,648)
	Overflow occurs when the higher 32b and the MSB of the lower 32b are all 1s or all 0s
	For division, assume both the dividend and the divisor are 32b values

	Begin operation when ctrl_MULT or ctrl_DIV is asserted; remain idle otherwise
	Assert data_resultRDY when operation is complete; assert data_inputRDY when new operation can begin
	Assert data_exception when divide by zero or overflow 
*/

module multdiv(data_operandA, data_operandB, ctrl_MULT, ctrl_DIV, clock, data_result, data_exception, data_inputRDY, data_resultRDY); 
	input [31:0] data_operandA, data_operandB;
	input ctrl_MULT, ctrl_DIV, clock;
	output [31:0] data_result;
	output data_exception, data_inputRDY, data_resultRDY;
	
	// Multiplier modules and wiring
	wire [39:0] addsub_inA, addsub_inB, addsub_out;
	wire [31:0] data_operandA_reg;	// multiplicand_reg -> premult
	wire [4:0] boothcode; // booth_recode -> premult
	wire addsubCtrl;	// booth_recode -> addsub
	wire recodeCtrl;	// FSM -> booth_recode
	wire addsubinACtrl; // FSM -> addsub
	wire mult_enable;	// FSM -> booth_recode and product_reg
	wire overflow;		// product_reg -> data_exception
	wire disp_overflow;	// FSM -> data_exception
	wire multiplicand_reg_enable; //FSM -> multiplicand_reg
	wire multiplicand_mux_ctrl;	  //FSM -> multiplicand_reg
	
	wire [31:0] mult_result; // product_reg -> data_result
	wire mult_inputRDY, mult_resultRDY; 
	
	booth_recode recode1(recodeCtrl, mult_enable, clock, data_operandB, boothcode, addsubCtrl);
	
	premult premult1(boothcode, data_operandA_reg, addsub_inB);
	
	addsub_s addsub1(addsubinACtrl, addsub_inA, addsub_inB, addsubCtrl, addsub_out);
	
	multiplicand_reg multiplicand_reg1(multiplicand_reg_enable, clock, multiplicand_mux_ctrl, data_operandA, data_operandA_reg);
	
	product_reg product_reg1(mult_enable, clock, addsub_out, addsub_inA, mult_result, overflow);
	
	multFSM multFSM1(ctrl_MULT, clock, mult_enable, recodeCtrl, addsubinACtrl, mult_inputRDY, mult_resultRDY, disp_overflow, multiplicand_reg_enable, multiplicand_mux_ctrl);
	
	// Divider modules and wiring
	wire [31:0] divisor_regout;	// divisor_reg -> remainder_reg
	wire quotient_sign, remainder_sign;	// sign_reg -> quotient_reg & remainder_reg
	wire newqbit;			// remainder_reg -> quotient_reg
	wire divisor_is_zero;	// dividebyzero ->FSM
	wire shift0, shift8, shift16, shift24; //remainder_reg -> FSM
	wire remainder_reg_ctrl;// FSM -> remainder_reg
	wire quotient_reg_ctrl;	// FSM -> quotient_reg
	wire div_enable;		   // FSM -> remainder_reg, quotient_reg
	wire divisor_reg_enable;// FSM -> divisor_reg
	wire sign_reg_enable;   // FSM -> sign_reg
	wire disp_dividebyzero; // FSM -> data_exception
	
	wire [31:0] quotient, remainder;
	wire div_inputRDY, div_resultRDY;
	
	dividebyzero dividebyzero1(data_operandB, divisor_is_zero);
	
	divisor_reg divisor_reg1(divisor_reg_enable, clock, data_operandB, divisor_regout);
	
	remainder_reg remainder_reg1(div_enable, clock, remainder_reg_ctrl, data_operandA, divisor_regout, remainder_sign, remainder, newqbit, shift0, shift8, shift16, shift24);
	
	quotient_reg quotient_reg1(div_enable, clock, quotient_reg_ctrl, newqbit, quotient_sign, quotient);
	
	sign_reg sign_reg1(sign_reg_enable, clock, data_operandA, data_operandB, quotient_sign, remainder_sign);
	
	divFSM divFSM1(ctrl_DIV, clock, divisor_is_zero, remainder_reg_ctrl, quotient_reg_ctrl, div_enable, divisor_reg_enable, sign_reg_enable, disp_dividebyzero, div_inputRDY, div_resultRDY, shift0, shift8, shift16, shift24);
	
	// Output 
	trinb #(32)	tri_mult(mult_result, data_result, mult_resultRDY);
	trinb #(32)	tri_div(quotient, data_result, div_resultRDY);

	assign data_inputRDY =  mult_inputRDY  & div_inputRDY;
	assign data_resultRDY = (mult_resultRDY & ~overflow) | div_resultRDY;
	assign data_exception = (overflow & disp_overflow) | (disp_dividebyzero);
	
endmodule 


// Multiplier Modules

module multFSM(ctrl_MULT, clk, reg_enable, recodeCtrl, addsubinACtrl, data_inputRDY, data_resultRDY, disp_overflow, multiplicand_reg_enable, multiplicand_mux_ctrl);
	input ctrl_MULT, clk;	
	output reg_enable, recodeCtrl, addsubinACtrl, data_inputRDY, data_resultRDY, disp_overflow, multiplicand_reg_enable, multiplicand_mux_ctrl;
	wire [3:0] curState, nextState;
	
	regnb #(4) reg_state(clk, 1'b1, 1'b0, nextState, curState);
	
	assign nextState[3] = ~curState[3] & curState[2] & curState[1] & curState[0];
	assign nextState[2] = (~curState[3] & ~curState[2] & curState[1] & curState[0]) | (~curState[3] & curState[2] & ~curState[1]) | (~curState[3] & curState[2] & ~curState[0]);
	assign nextState[1] = (~curState[3] & ~curState[1] & curState[0]) |  (~curState[3] & curState[1] & ~curState[0]);
	assign nextState[0] = (~curState[3] & curState[1] & ~curState[0]) | (~curState[3] & curState[2] & ~curState[0]) | (~curState[2] & ~curState[1] & ~curState[0] & ctrl_MULT);
	
	assign reg_enable =    ~ (~curState[2] & ~curState[1] & ~curState[0] & ~ctrl_MULT);
	
	assign recodeCtrl =    ~ (~curState[2] & ~curState[1] & ~curState[0]);
	assign addsubinACtrl = ~ (~curState[2] & ~curState[1] & ~curState[0]);
	
	assign data_inputRDY =                ~curState[2] & ~curState[1] & ~curState[0];
	assign data_resultRDY = curState[3] & ~curState[2] & ~curState[1] & ~curState[0];
	assign disp_overflow =  curState[3] & ~curState[2] & ~curState[1] & ~curState[0];
	
	assign multiplicand_reg_enable =      ~curState[2] & ~curState[1] & ~curState[0];
	assign multiplicand_mux_ctrl = 		  ~curState[2] & ~curState[1] & ~curState[0];
	
endmodule


module multiplicand_reg(enable, clk, mux_ctrl, in, out);
	input enable, clk, mux_ctrl;
	input [31:0] in;
	output [31:0] out;
	
	wire [31:0] reg_out;
	
	regnb #(32) reg_1(clk, enable, 1'b0, in, reg_out);

	trinb #(32)	tri_0(     in, out,  mux_ctrl);
	trinb #(32)	tri_1(reg_out, out, ~mux_ctrl);

endmodule


// The overflow signal is generated by looking at the upper 32b of the 64b result
// if the upper 32 bits aren't all 0s or all 1s, then there is an overflow
module product_reg(enable, clk, in, toaddsub, result, overflow);
	input enable, clk;
	input [39:0] in;
	output [39:0] toaddsub;	// back to inA of the addsub module
	output [31:0] result;	// multiplication result; only valid after eight clock cycles
	output overflow;
	
	wire [27:0] feedback;	// 28b feedback
	wire [3:0] last4bits;	// 4b garbage
	
	regnb #(72) reg_1(clk, enable, 1'b0, {in[39],in[39],in[39],in[39], in, feedback}, {toaddsub, feedback, last4bits});
	
	assign result = {feedback, last4bits};
	assign overflow = (~&{toaddsub[31:0], feedback[27]}) & (|{toaddsub[31:0], feedback[27]});
	
endmodule


// convert operand B to 5-bit booth code before each rising edge of the clock
// using a 2-1 mux(tri32) and a 33-bit DFF register
module booth_recode(c, enable, clk, in, out, addsubCtrl);
	input c;   // 1-bit control to select either the original value of operand B(c=0), or the shifted version of B(c==1)
	input enable, clk; // clock input to the 33-bit register
	input [31:0] in;  // operand B
	output [4:0] out; // 5-bit control going directly into the premult module
	output addsubCtrl;
	
	supply0 zero;
	supply0 [3:0] zero4;
	
	wire [32:0] mux_out;
	wire [32:0] reg_out;
	
 	trinb #(33)	tri_0({in, zero}, mux_out, ~c);
	trinb #(33)	tri_1({zero4, reg_out[32:4]}, mux_out, c);
	
	regnb #(33) reg_1(clk, enable, 1'b0, mux_out, reg_out);
	
	assign out = mux_out[4:0];
	assign addsubCtrl = mux_out[4];
	
endmodule


// 40b wide addsub for use in the multiplier
// _s stands for simple; it doesn't have the lessthan and equalto signals compared to the module used in the ALU
module addsub_s(c, inA, inB, addsub, out);
	input c; // 1-bit control to select either 0 as inA(c=0), or the output of the product_reg(c==1)
	input [39:0] inA,inB;
	input addsub; //0-add, 1-sub
	output [39:0] out;
	
	wire [39:0] mux_out;
	supply0 [39:0] zero40;
	
	wire cout;
	wire [39:0] inBn, inBorBn;
	assign inBn = ~ inB;
	
	trinb #(40) tri_0(zero40, mux_out, ~c);
	trinb #(40) tri_1(inA, mux_out, c);
	
	trinb #(40)	triadd( inB, inBorBn, ~addsub);
	trinb #(40)	trisub(inBn, inBorBn, addsub);
	
	csa40b a_csa40b(addsub, mux_out, inBorBn, out, cout);

endmodule


module premult(c, A, out);
	input [4:0] c;	// the five control bits
	input [31:0] A;	// operand A
	output [39:0] out;  // 40b output of multiples of A (only uses a max of 35 bits (8A))

	supply0 [39:0] A0;	// has value 0
	wire [39:0] A1,A2,A3,A4,A5,A6,A7,A8;	//integer multiples of A1
	assign A1 = {A[31], A[31], A[31], A[31], A[31], A[31], A[31], A[31], A};	// expand 32b to 40b by adding 8b signed prefix
	
	sllnb_40b_ae  #(1)  sllA2(A1, A2);
	sllnb_40b_ae  #(1)  sllA4(A2, A4);
	sllnb_40b_ae  #(1)  sllA8(A4, A8);
	
	add_premult addA3(A2, A1, A3);
	add_premult addA5(A4, A1, A5);
	add_premult addA6(A4, A2, A6);
	sub_premult subA7(A8, A1, A7);
	
	wire OE0,OE1,OE2,OE3,OE4,OE5,OE6,OE7,OE8;
	
	assign OE0 = (~c[4] & ~c[3] & ~c[2] & ~c[1] & ~c[0]) | ( c[4] &  c[3] &  c[2] &  c[1] &  c[0]);	
	assign OE1 = (~c[4] & ~c[3] & ~c[2] & ~c[1] &  c[0]) | (~c[4] & ~c[3] & ~c[2] &  c[1] & ~c[0]) | ( c[4] &  c[3] &  c[2] & ~c[1] &  c[0]) | ( c[4] &  c[3] &  c[2] &  c[1] & ~c[0]);
	assign OE2 = (~c[4] & ~c[3] & ~c[2] &  c[1] &  c[0]) | (~c[4] & ~c[3] &  c[2] & ~c[1] & ~c[0]) | ( c[4] &  c[3] & ~c[2] &  c[1] &  c[0]) | ( c[4] &  c[3] &  c[2] & ~c[1] & ~c[0]);
	assign OE3 = (~c[4] & ~c[3] &  c[2] & ~c[1] &  c[0]) | (~c[4] & ~c[3] &  c[2] &  c[1] & ~c[0]) | ( c[4] &  c[3] & ~c[2] & ~c[1] &  c[0]) | ( c[4] &  c[3] & ~c[2] &  c[1] & ~c[0]);
	assign OE4 = (~c[4] & ~c[3] &  c[2] &  c[1] &  c[0]) | (~c[4] &  c[3] & ~c[2] & ~c[1] & ~c[0]) | ( c[4] & ~c[3] &  c[2] &  c[1] &  c[0]) | ( c[4] &  c[3] & ~c[2] & ~c[1] & ~c[0]);
	assign OE5 = (~c[4] &  c[3] & ~c[2] & ~c[1] &  c[0]) | (~c[4] &  c[3] & ~c[2] &  c[1] & ~c[0]) | ( c[4] & ~c[3] &  c[2] & ~c[1] &  c[0]) | ( c[4] & ~c[3] &  c[2] &  c[1] & ~c[0]);
	assign OE6 = (~c[4] &  c[3] & ~c[2] &  c[1] &  c[0]) | (~c[4] &  c[3] &  c[2] & ~c[1] & ~c[0]) | ( c[4] & ~c[3] & ~c[2] &  c[1] &  c[0]) | ( c[4] & ~c[3] &  c[2] & ~c[1] & ~c[0]);
	assign OE7 = (~c[4] &  c[3] &  c[2] & ~c[1] &  c[0]) | (~c[4] &  c[3] &  c[2] &  c[1] & ~c[0]) | ( c[4] & ~c[3] & ~c[2] & ~c[1] &  c[0]) | ( c[4] & ~c[3] & ~c[2] &  c[1] & ~c[0]);
	assign OE8 = (~c[4] &  c[3] &  c[2] &  c[1] &  c[0]) | ( c[4] & ~c[3] & ~c[2] & ~c[1] & ~c[0]);

	trinb #(40)	tri_0(A0, out, OE0);
	trinb #(40)	tri_1(A1, out, OE1);
	trinb #(40)	tri_2(A2, out, OE2);
	trinb #(40)	tri_3(A3, out, OE3);
	trinb #(40)	tri_4(A4, out, OE4);
	trinb #(40)	tri_5(A5, out, OE5);
	trinb #(40)	tri_6(A6, out, OE6);
	trinb #(40)	tri_7(A7, out, OE7);
	trinb #(40)	tri_8(A8, out, OE8);
	
endmodule


module add_premult(inA, inB, out);
	input [39:0] inA, inB;
	output [39:0] out;
	
	supply0 zero;
	wire cout;
	
	csa40b a_csa40b(zero, inA, inB, out, cout);
	
endmodule


module sub_premult(inA, inB, out);
	input [39:0] inA, inB;
	output [39:0] out;
	
	supply1 one;
	wire cout;
	wire [39:0] inBn;
	assign inBn = ~inB;
	
	csa40b a_csa40b(one, inA, inBn, out, cout);
	
endmodule


// Carry Select Adder (40-bit) consisting of 1 x ks8b and 4 x ks8bmux
module csa40b(cin, inA, inB, sum, cout);
	input cin;
	input [39:0] inA, inB;
	output [39:0] sum;
	output cout;
	
	wire cin2, cin3, cin4, cin5;
	
	ks8b    ks8b1(cin,    inA[7:0],   inB[7:0],   sum[7:0], cin2);
	ks8bMux ks8b2(cin2,  inA[15:8],  inB[15:8],  sum[15:8], cin3);
	ks8bMux ks8b3(cin3, inA[23:16], inB[23:16], sum[23:16], cin4);
	ks8bMux ks8b4(cin4, inA[31:24], inB[31:24], sum[31:24], cin5);
	ks8bMux ks8b5(cin5, inA[39:32], inB[39:32], sum[39:32], cout);
	
endmodule


// 40b bus width sll for use in premult
// ae stands for always enabled, meaning that it always pruduces a shifted output
module sllnb_40b_ae(in, out);
	parameter b = 1;
	input [39:0] in;
	output [39:0] out;
	
	supply0 gnd;
		
	genvar n;
	generate
		for (n=0;n<b;n=n+1) begin: loop_sll_1
			assign out[n]=gnd;
		end
	endgenerate
	
	generate
		for (n=b;n<40;n=n+1) begin: loop_sll_2
			assign out[n] = in[n-b];
		end
	endgenerate
	
endmodule


// Divider Modules

module divFSM(ctrl_DIV, clk, divisor_is_zero, remainder_reg_ctrl, quotient_reg_ctrl, div_enable, divisor_reg_enable, sign_reg_enable, disp_dividebyzero, div_inputRDY, div_resultRDY, shift0, shift8, shift16, shift24);
	input ctrl_DIV, clk, divisor_is_zero, shift0, shift8, shift16, shift24;
	output remainder_reg_ctrl, quotient_reg_ctrl, div_enable, divisor_reg_enable, sign_reg_enable, disp_dividebyzero, div_inputRDY, div_resultRDY;
	wire [32:0] cs, ns; // current state; next state
	
	regnb #(33) reg_state(clk, 1'b1, 1'b0, ns, cs);
	
	// States
	assign ns[0] = (ctrl_DIV & ~divisor_is_zero & shift0) & ( (~|cs) | cs[31] | cs[32]);
	
	/*genvar n;
	generate
		for (n=1;n<32;n=n+1) begin: loop1
			assign ns[n]=cs[n-1];
		end
	endgenerate
	*/
	
	genvar n;
	generate
		for (n=1;n<8;n=n+1) begin: loop1
			assign ns[n]=cs[n-1];
		end
	endgenerate
	
	assign ns[8] = cs[7] | ( (ctrl_DIV & ~divisor_is_zero & shift8) & ( (~|cs) | cs[31] | cs[32]) );
	
	generate
		for (n=9;n<16;n=n+1) begin: loop2
			assign ns[n]=cs[n-1];
		end
	endgenerate
	
	assign ns[16] = cs[15] | ( (ctrl_DIV & ~divisor_is_zero & shift16) & ( (~|cs) | cs[31] | cs[32]) );
	
	generate
		for (n=17;n<24;n=n+1) begin: loop3
			assign ns[n]=cs[n-1];
		end
	endgenerate
	
	assign ns[24] = cs[23] | ( (ctrl_DIV & ~divisor_is_zero & shift24) & ( (~|cs) | cs[31] | cs[32]) );
	
	generate
		for (n=25;n<32;n=n+1) begin: loop4
			assign ns[n]=cs[n-1];
		end
	endgenerate
	
	assign ns[32] = (ctrl_DIV & divisor_is_zero) & ( (~|cs) | cs[31] | cs[32]);
	
	// Output
	assign remainder_reg_ctrl = (~|cs) | cs[31] | cs[32];
	assign quotient_reg_ctrl =  (~|cs) | cs[31] | cs[32];
	assign divisor_reg_enable = (~|cs) | cs[31] | cs[32];
	assign sign_reg_enable = 	 (~|cs) | cs[31] | cs[32];
	assign div_enable = ~( ( ~ctrl_DIV | (ctrl_DIV & divisor_is_zero) ) & ( (~|cs) | cs[31] | cs[32]) );
	assign disp_dividebyzero = cs[32];
	assign div_inputRDY = (~|cs) | cs[31] | cs[32];
	assign div_resultRDY = cs[31];
	
endmodule


module remainder_reg(enable, clk, muxctrl, dividend, divisor_reg, remainder_sign, remainder, newqbit, shift0, shift8, shift16, shift24);
	input enable, clk, muxctrl, remainder_sign;
	input [31:0] dividend, divisor_reg;
	output [31:0] remainder;
	output newqbit;
	output shift0, shift8, shift16, shift24;
	
	wire [31:0] mux32in0, mux32in1, mux32out;
	wire [63:0] mux64in0, mux64in1, mux64out;
	wire [63:0] regout;
	wire islessthan;
	
	supply0 [30:0] zero31;
	supply0 zero;
	
	sub_div sub_div1(regout[62:31], divisor_reg, mux32in0, islessthan);
	
	assign mux32in1 = regout[62:31];
	trinb #(32)	tri32_0(mux32in0, mux32out, ~islessthan);
	trinb #(32)	tri32_1(mux32in1, mux32out, islessthan);
	
	wire [31:0] dividend_sign_corrected;
	correct_sign correct_sign1(dividend, dividend_sign_corrected);
	
	wire [31:0] shifted_dividend_sign_corrected;
	shift_dividend shift_dividend1(dividend_sign_corrected, shifted_dividend_sign_corrected, shift0, shift8, shift16, shift24);
	
	assign mux64in0 = {mux32out, regout[30:0], zero};
	assign mux64in1 = {zero31, shifted_dividend_sign_corrected, zero};
	trinb #(64)	tri64_0(mux64in0, mux64out, ~muxctrl);
	trinb #(64)	tri64_1(mux64in1, mux64out, muxctrl);
	
	regnb #(64) reg_1(clk, enable, 1'b0, mux64out, regout);
	
	result_correct_sign result_correct_sign1(remainder_sign, regout[63:32], remainder);

	assign newqbit = ~ islessthan;
	
endmodule


module divisor_reg(enable, clk, divisorin, divisorout);
	input enable, clk;
	input [31:0] divisorin;
	output [31:0] divisorout;
	
	wire [31:0] divisor_sign_corrected;
	correct_sign correct_sign1(divisorin, divisor_sign_corrected);
	
	regnb #(32) reg_1(clk, enable, 1'b0, divisor_sign_corrected, divisorout);

endmodule


module quotient_reg(enable, clk, muxctrl, newqbit, quotient_sign, quotient);
	input enable, clk, muxctrl, newqbit, quotient_sign;
	output [31:0] quotient;
	
	wire [31:0] mux32in0, mux32in1, mux32out;
	wire [31:0] regout;
	
	supply0 zero;
	supply0 [31:0] zero32;
	
	assign mux32in0 = {regout[30:0], newqbit};
	assign mux32in1 = zero32; //{regout[30:0], zero};
	trinb #(32)	tri_0(mux32in0, mux32out, ~muxctrl);
	trinb #(32)	tri_1(mux32in1, mux32out, muxctrl);
	
	regnb #(32) reg_1(clk, enable, 1'b0, mux32out, regout);

	result_correct_sign result_correct_sign1(quotient_sign, regout, quotient);

endmodule


module sign_reg(sign_reg_enable, clk, dividend, divisor, quotient_sign, remainder_sign);
	input sign_reg_enable, clk;
	input [31:0] dividend, divisor;
	output quotient_sign, remainder_sign;
	
	wire dividend_sign, divisor_sign;
	assign dividend_sign = dividend[31];
	assign divisor_sign = divisor[31];
	
	wire regin1;
	assign regin1 = dividend_sign ^ divisor_sign;
	
	regnb #(2) reg_1(clk, sign_reg_enable, 1'b0, {regin1, dividend_sign}, {quotient_sign, remainder_sign});

endmodule


module twoscomplement(in, out);
	input [31:0] in;
	output [31:0] out;
	
	supply0 [31:0] zero32;
	supply1 one;
	
	wire cout;
	wire [31:0] in_not;
	assign in_not = ~in;
	
	csa32b a_csa32b(one, in_not, zero32, out, cout);

endmodule


// used when loading the divisor into divisor_reg and dividend into the remainder reg
module correct_sign(in, out);
	input [31:0] in;
	output [31:0] out;
	
	wire [31:0] tri1_in;
	twoscomplement twoscomplement1(in, tri1_in);
	
	trinb #(32)	tri_0(     in, out, ~in[31]);
	trinb #(32)	tri_1(tri1_in, out, in[31]);

endmodule


module shift_dividend(dividend, shifted_dividend, shift0, shift8, shift16, shift24);
	input [31:0] dividend;
	output [31:0] shifted_dividend;
	output shift0, shift8, shift16, shift24;
	
	assign shift24 =  ~|dividend[31:8];
	assign shift16 = (~|dividend[31:16]) & |dividend[15:8];
	assign shift8  = (~|dividend[31:24]) & |dividend[23:16];
	assign shift0  =                       |dividend[31:24];
	
	wire [31:0] dividendsll8, dividendsll16, dividendsll24;
	
	supply0  [7:0]  zero8;
	supply0 [15:0] zero16;
	supply0 [23:0] zero24;
	
	assign  dividendsll8 = {dividend[23:0],  zero8};
	assign dividendsll16 = {dividend[15:0], zero16};
	assign dividendsll24 = { dividend[7:0], zero24};
	
	trinb #(32)  tri_0(     dividend, shifted_dividend,  shift0);
	trinb #(32)	 tri_8( dividendsll8, shifted_dividend,  shift8);
	trinb #(32)	tri_16(dividendsll16, shifted_dividend, shift16);
	trinb #(32)	tri_24(dividendsll24, shifted_dividend, shift24);

endmodule


// used in the remainder_reg and quotient_reg modules for correcting the signs of the remainder and quotient
module result_correct_sign(sign, in, out);
	input sign;
	input [31:0] in;
	output [31:0] out;
	
	wire [31:0] tri1_in;
	twoscomplement twoscomplement1(in, tri1_in);
	
	trinb #(32)	tri_0(     in, out, ~sign);
	trinb #(32)	tri_1(tri1_in, out, sign);

endmodule


module sub_div(inA, inB, out, isLessThan);
	input [31:0] inA,inB;
	output [31:0] out;
	output isLessThan;
	
	supply1 one;
	wire cout;
	wire [31:0] inBn;
	assign inBn = ~inB;
	
	csa32b a_csa32b(one, inA, inBn, out, cout);
	
	assign isLessThan = out[31]; // isLessThan == MSB of out is 1
	
endmodule


module dividebyzero(divisor, divisor_is_zero);
	input [31:0] divisor;
	output divisor_is_zero;
	assign divisor_is_zero = ~|divisor;
endmodule


module alu(data_operandA, data_operandB, ctrl_ALUopcode, ctrl_shiftamt, data_result, isNotEqual, isLessThan);
   input [31:0] data_operandA, data_operandB;
   input [4:0] ctrl_ALUopcode, ctrl_shiftamt;
   output [31:0] data_result;
   output isNotEqual, isLessThan;
	
	wire [31:0] addsubOut, andOut, orOut, sllOut, sraOut;
	
	addsub a_addsub(data_operandA, data_operandB, ctrl_ALUopcode[0], addsubOut, isNotEqual, isLessThan);
	and32b a_and32b(data_operandA, data_operandB, andOut);
	or32b a_or32b(data_operandA, data_operandB, orOut);
	sll a_sll(data_operandA, ctrl_shiftamt, sllOut);
	sra a_sra(data_operandA, ctrl_shiftamt, sraOut);
	
	wire addsubOE, and32bOE, or32bOE, sllOE, sraOE;
	
	assign addsubOE = ~ctrl_ALUopcode[4] & ~ctrl_ALUopcode[3] & ~ctrl_ALUopcode[2] & ~ctrl_ALUopcode[1];
	assign and32bOE = ~ctrl_ALUopcode[4] & ~ctrl_ALUopcode[3] & ~ctrl_ALUopcode[2] &  ctrl_ALUopcode[1] & ~ctrl_ALUopcode[0];
	assign  or32bOE = ~ctrl_ALUopcode[4] & ~ctrl_ALUopcode[3] & ~ctrl_ALUopcode[2] &  ctrl_ALUopcode[1] &  ctrl_ALUopcode[0];
	assign    sllOE = ~ctrl_ALUopcode[4] & ~ctrl_ALUopcode[3] &  ctrl_ALUopcode[2] & ~ctrl_ALUopcode[1] & ~ctrl_ALUopcode[0];
	assign    sraOE = ~ctrl_ALUopcode[4] & ~ctrl_ALUopcode[3] &  ctrl_ALUopcode[2] & ~ctrl_ALUopcode[1] &  ctrl_ALUopcode[0];
	
	trinb #(32) triaddsub(addsubOut, data_result, addsubOE);
	trinb #(32) triand32b(	 andOut, data_result, and32bOE);
	trinb #(32)  trior32b(    orOut, data_result,  or32bOE);
	trinb #(32) 	trisll(   sllOut, data_result,    sllOE);
	trinb #(32) 	trisra(   sraOut, data_result,    sraOE);
	
endmodule


module addsub(inA, inB, addsub, out, isNotEqual, isLessThan);
	input [31:0] inA,inB;
	input addsub; //0-add, 1-sub
	output [31:0] out;
	output isNotEqual, isLessThan;
	
	wire cout;
	wire [31:0] inBn, inBorBn;
	assign inBn = ~ inB;

	trinb #(32)	triadd( inB, inBorBn, ~addsub);
	trinb #(32)	trisub(inBn, inBorBn, addsub);
	
	csa32b a_csa32b(addsub, inA, inBorBn, out, cout);
	
	assign isNotEqual = |out;	  // isNotEqual == (out!=0)
	assign isLessThan = out[31]; // isLessThan == MSB of out is 1
	
endmodule


// Carry Select Adder (32-bit) consisting of 1 x ks8b and 3 x ks8bmux
module csa32b(cin, inA, inB, sum, cout);
	input cin;
	input [31:0] inA, inB;
	output [31:0] sum;
	output cout;
	
	wire cin2, cin3, cin4;
	
	ks8b    ks8b1(cin,    inA[7:0],   inB[7:0],   sum[7:0], cin2);
	ks8bMux ks8b2(cin2,  inA[15:8],  inB[15:8],  sum[15:8], cin3);
	ks8bMux ks8b3(cin3, inA[23:16], inB[23:16], sum[23:16], cin4);
	ks8bMux ks8b4(cin4, inA[31:24], inB[31:24], sum[31:24], cout);
	
endmodule


module ks8bMux(cin, inA, inB, sum, cout);
	input cin;
	input [7:0] inA, inB;
	output [7:0] sum;
	output cout;
	
	wire [7:0] cin0sum, cin1sum;
	wire cin0cout, cin1cout;
	
	ks8b kscin0(1'b0, inA, inB, cin0sum, cin0cout);
	ks8b kscin1(1'b1, inA, inB, cin1sum, cin1cout);

	trinb #(8) tri0sum(cin0sum, sum, ~cin);
	trinb #(8) tri1sum(cin1sum, sum, cin);
	trinb #(1) tri0cout(cin0cout, cout, ~cin);
	trinb #(1) tri1cout(cin1cout, cout, cin);
	
endmodule


//Kogge Stone Adder (8-bit)
//Reference schematic: http://venividiwiki.ee.virginia.edu/mediawiki/index.php/File:8-bit_KSA.jpg
module ks8b(cin, x, y, sum, cout);
	input cin; 
	input [7:0] x, y;
	output [7:0] sum;
	output cout; 
	wire [7:0]  GZ, PZ, GA, PA, GB, PB, GC, PC;
 
	Gcomb A0(cin, PZ[0], GZ[0], GA[0]);
	GPcomb A1(GZ[0], PZ[1], GZ[1], PZ[0], GA[1], PA[1]);
	GPcomb A2(GZ[1], PZ[2], GZ[2], PZ[1], GA[2], PA[2]);
	GPcomb A3(GZ[2], PZ[3], GZ[3], PZ[2], GA[3], PA[3]);
	GPcomb A4(GZ[3], PZ[4], GZ[4], PZ[3], GA[4], PA[4]);
	GPcomb A5(GZ[4], PZ[5], GZ[5], PZ[4], GA[5], PA[5]);
	GPcomb A6(GZ[5], PZ[6], GZ[6], PZ[5], GA[6], PA[6]);
	GPcomb A7(GZ[6], PZ[7], GZ[7], PZ[6], GA[7], PA[7]);
 
	Gcomb B1(cin, PA[1], GA[1], GB[1]);
	Gcomb B2(GA[0], PA[2], GA[2], GB[2]);
	GPcomb B3(GA[1], PA[3], GA[3], PA[1], GB[3], PB[3]);
	GPcomb B4(GA[2], PA[4], GA[4], PA[2], GB[4], PB[4]);
	GPcomb B5(GA[3], PA[5], GA[5], PA[3], GB[5], PB[5]);
	GPcomb B6(GA[4], PA[6], GA[6], PA[4], GB[6], PB[6]);
	GPcomb B7(GA[5], PA[7], GA[7], PA[5], GB[7], PB[7]);
	
	Gcomb C3(cin, PB[3], GB[3], GC[3]);
	Gcomb C4(GA[0], PB[4], GB[4], GC[4]);
	Gcomb C5(GB[1], PB[5], GB[5], GC[5]);
	Gcomb C6(GB[2], PB[6], GB[6], GC[6]);
	GPcomb C7(GB[3], PB[7], GB[7], PB[3], GC[7], PC[7]);
 
	Gcomb D7(cin, PC[7], GC[7], cout);
 
	GP Z0(x[0], y[0], PZ[0], GZ[0]);
	GP Z1(x[1], y[1], PZ[1], GZ[1]);
	GP Z2(x[2], y[2], PZ[2], GZ[2]);
	GP Z3(x[3], y[3], PZ[3], GZ[3]);
	GP Z4(x[4], y[4], PZ[4], GZ[4]);
	GP Z5(x[5], y[5], PZ[5], GZ[5]);
	GP Z6(x[6], y[6], PZ[6], GZ[6]);
	GP Z7(x[7], y[7], PZ[7], GZ[7]);
 
	xor(sum[0], cin, PZ[0]);
	xor(sum[1], GA[0], PZ[1]);
	xor(sum[2], GB[1], PZ[2]);
	xor(sum[3], GB[2], PZ[3]);
	xor(sum[4], GC[3], PZ[4]);
	xor(sum[5], GC[4], PZ[5]);
	xor(sum[6], GC[5], PZ[6]);
	xor(sum[7], GC[6], PZ[7]);
endmodule

module GPcomb(Gkj, Pik, Gik, Pkj, G, P);
	input Gkj, Pik, Gik, Pkj;
	output G, P;
	wire Y;
  
	and(Y, Gkj, Pik);
	or(G, Gik, Y);
	and(P, Pkj, Pik); 
endmodule

module Gcomb(Gkj, Pik, Gik, G);
	input Gkj, Pik, Gik;
	output G;
	wire Y;
 
	and(Y, Gkj, Pik);
	or(G, Y, Gik);
endmodule

module GP(a, b, p, g);
	input a, b;
	output p, g;
 
	xor(p, a, b);
	and(g, a, b);
endmodule


module and32b(a, b, out);
	input [31:0] a,b;
	output [31:0] out;
	
	assign out = a & b;
endmodule


module or32b(a, b, out);
	input [31:0] a,b;
	output [31:0] out;
	
	assign out = a | b;
endmodule


module sllnb(in, shift, out);
	parameter b = 1;
	input [31:0] in;
	input shift;
	output [31:0] out;
	
	wire [31:0] bus;	// connecting the output of the sllnb to a tri32b (triShift)
	wire shiftn;
	supply0 gnd;
	
	assign shiftn = ~shift;
	
	genvar n;
	generate
		for (n=0;n<b;n=n+1) begin: loop_sll_1
			assign bus[n]=gnd;
		end
	endgenerate
	
	generate
		for (n=b;n<32;n=n+1) begin: loop_sll_2
			assign bus[n] = in[n-b];
		end
	endgenerate
	
	trinb #(32) triShift(bus, out, shift);
	trinb #(32) triShiftn(in, out, shiftn);
	
endmodule


module sll(in, shamt, out);
	input [31:0] in;
	input [4:0] shamt;
	output [31:0] out;

	wire [31:0] s1bo, s2bo, s4bo, s8bo;

	sllnb  #(1)  sll1b(  in, shamt[0], s1bo);
	sllnb  #(2)  sll2b(s1bo, shamt[1], s2bo);
	sllnb  #(4)  sll4b(s2bo, shamt[2], s4bo);
	sllnb  #(8)  sll8b(s4bo, shamt[3], s8bo);
	sllnb #(16) sll16b(s8bo, shamt[4],  out);
	
endmodule


module sranb(in, shift, out);
	parameter b = 0;
	input [31:0] in;
	input shift;
	output [31:0] out;
	
	wire [31:0] bus;	// connecting the output of the sllnb to a tri32b (triShift)
	wire shiftn;
	supply0 gnd;
	
	assign shiftn = ~shift;
	
	genvar n;
	generate
		for (n=0;n<(32-b);n=n+1) begin: loop_sra_1
			assign bus[n]=in[n+b];
		end
	endgenerate
	
	generate
		for (n=32-b;n<32;n=n+1) begin: loop_sra_2
			assign bus[n] = bus[n-1];
		end
	endgenerate
	
	trinb #(32) triShift(bus, out, shift);
	trinb #(32) triShiftn(in, out, shiftn);

endmodule


module sra(in, shamt, out);
	input [31:0] in;
	input [4:0] shamt;
	output [31:0] out;

	wire [31:0] s1bo, s2bo, s4bo, s8bo;

	sranb  #(1)  sra1b(  in, shamt[0], s1bo);
	sranb  #(2)  sra2b(s1bo, shamt[1], s2bo);
	sranb  #(4)  sra4b(s2bo, shamt[2], s4bo);
	sranb  #(8)  sra8b(s4bo, shamt[3], s8bo);
	sranb #(16) sra16b(s8bo, shamt[4],  out);
endmodule


module myDFF(d, clk, clr, ena, q);
	input d, clk, clr, ena;
	output q;
	
	reg q;
	
	// asynchronous clear/reset
	always @ (posedge clk or posedge clr)
	begin
		if (clr==1'b1) q <= 1'b0;
		else if (ena==1'b1) q <= d;
	end
	
endmodule

module regnb(clock, writeEnable, reset, writeIn, readOut);
	parameter b = 32; 
	input clock, writeEnable, reset;
	input [(b-1):0] writeIn;
	output [(b-1):0] readOut;
	
	genvar n;
	generate
		for (n=0;n<b;n=n+1) begin: myDFFs
			myDFF a_DFF(.d(writeIn[n]), .clk(clock), .clr(reset), .ena(writeEnable), .q(readOut[n]));
		end
	endgenerate
endmodule

module trinb(in, out, OE);
	parameter b = 1; 
	input OE;
	input [(b-1):0] in;
	output [(b-1):0] out;
	
	genvar n;
	generate
		for (n=0;n<b;n=n+1) begin: loop_trinb
			assign out[n] = (OE)? in[n]:1'bz;
		end
	endgenerate
endmodule
