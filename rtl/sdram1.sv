module sdram1
(
	inout  reg [15:0] SDRAM_DQ,   // 16 bit bidirectional data bus
	output reg [12:0] SDRAM_A,    // 13 bit multiplexed address bus
	output reg        SDRAM_DQML, // byte mask
	output reg        SDRAM_DQMH, // byte mask
	output reg  [1:0] SDRAM_BA,   // two banks
	output            SDRAM_nCS,  // a single chip select
	output reg        SDRAM_nWE,  // write enable
	output reg        SDRAM_nRAS, // row address select
	output reg        SDRAM_nCAS, // columns address select
	output            SDRAM_CLK,
	output            SDRAM_CKE,

	// cpu/chipset interface
	input             init,			// init signal after FPGA config to initialize RAM
	input             clk,			// sdram is accessed at up to 128MHz
	input             sync,			//

	input      [20:1] addr_a0,
	input      [19:1] addr_a1,
	input      [63:0] din_a,
	input       [7:0] wr_a,
	input             rd_a,
	output     [31:0] dout_a0,
	output     [31:0] dout_a1,
	
	input      [20:1] addr_b0,
	input      [19:1] addr_b1,
	input      [63:0] din_b,
	input       [7:0] wr_b,
	input             rd_b,
	output     [31:0] dout_b0,
	output     [31:0] dout_b1,

	input      [21:1] ch2addr,
	input      [15:0] ch2din,
	input       [1:0] ch2wr,
	input             ch2rd,
	output     [15:0] ch2dout,
	output reg        ch2rdy,

	output [1:0] dbg_ctrl_bank,
	output [1:0] dbg_ctrl_cmd,
	output [3:0] dbg_ctrl_we,
	output       dbg_ctrl_rfs,
	
	output       dbg_data0_read,
	output       dbg_out0_read,
	output [1:0] dbg_out0_bank,
	
	output       dbg_data1_read,
	output       dbg_out1_read,
	output [1:0] dbg_out1_bank,
	
	output reg [15:0] dbg_sdram_d
);

	localparam RASCAS_DELAY   = 3'd2; // tRCD=20ns -> 2 cycles@85MHz
	localparam BURST_1        = 3'd0; // 0=1, 1=2, 2=4, 3=8, 7=full page
	localparam BURST_2        = 3'd1; // 0=1, 1=2, 2=4, 3=8, 7=full page
	localparam ACCESS_TYPE    = 1'd0; // 0=sequential, 1=interleaved
	localparam CAS_LATENCY_1  = 3'd3; // 2/3 allowed
	localparam CAS_LATENCY_2  = 3'd2; // 2/3 allowed
	localparam OP_MODE        = 2'd0; // only 0 (standard operation) allowed
	localparam NO_WRITE_BURST = 1'd1; // 0=write burst enabled, 1=only single access write

	localparam bit [12:0] MODE[2] = '{{3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY_2, ACCESS_TYPE, BURST_2},
	                                  {3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY_1, ACCESS_TYPE, BURST_1}}; 
	
	localparam STATE_IDLE  = 3'd0;             // state to check the requests
	localparam STATE_START = STATE_IDLE+1'd1;  // state in which a new command is started
	localparam STATE_CONT  = STATE_START+RASCAS_DELAY;
	localparam STATE_READY = STATE_CONT+CAS_LATENCY_1+1'd1;
	localparam STATE_LAST  = STATE_READY;      // last state in cycle
	
	localparam MODE_NORMAL = 2'b00;
	localparam MODE_RESET  = 2'b01;
	localparam MODE_LDM    = 2'b10;
	localparam MODE_PRE    = 2'b11;

	// initialization 
	reg [2:0] init_state = '0;
	reg [1:0] mode;
	reg       init_chip = 0;
	reg       init_done = 0;
	always @(posedge clk) begin
		reg [4:0] reset = 5'h1f;
		reg init_old = 0;
		
		if(mode != MODE_NORMAL || init_state != STATE_IDLE || reset) begin
			init_state <= init_state + 1'd1;
			if (init_state == STATE_LAST) init_state <= STATE_IDLE;
		end

		init_old <= init;
		if (init_old & ~init) begin
			reset <= 5'h1f; 
			init_chip <= 0;
			init_done <= 0;
		end
		else if (init_state == STATE_LAST) begin
			if(reset != 0) begin
				reset <= reset - 5'd1;
				if (reset == 15 || reset == 14) begin mode <= MODE_PRE; init_chip <= (reset == 15); end
				else if(reset == 4 || reset == 3) begin mode <= MODE_LDM; init_chip <= (reset == 4); end
				else                mode <= MODE_RESET;
			end
			else begin
				mode <= MODE_NORMAL;
				init_chip <= 0;
				init_done <= 1;
			end
		end
	end
	
	localparam CTRL_IDLE = 2'd0;
	localparam CTRL_RAS = 2'd1;
	localparam CTRL_CAS = 2'd2;
	
	typedef struct packed
	{
		bit [ 1:0] CMD;	//command
		bit        CHIP;	//chip n
		bit [ 1:0] BANK;	//bank
		bit [19:1] ADDR;	//read/write address
		bit [15:0] DATA;	//write data
		bit        RD;		//read	
		bit        WE;		//write enable
		bit [ 1:0] BE;		//write byte enable
		bit        RFS;	//refresh	
	} state_t;
	state_t state[6];
	reg [ 3: 0] st_num;
	
	reg [19: 1] raddr0[2];
	reg [19: 1] raddr1[2];
	reg [20: 1] waddr[2];
	reg [63: 0] din[2];
	reg [ 7: 0] wr[2];
	reg         rd[2];
	reg [21: 1] addr2,addr2_pipe;
	reg [15: 0] din2;
	reg         wr2;
	reg         rd2,rd2_pipe;
	reg [ 1: 0] be2;
	reg         wr2_pend;
	reg         rd2_pend;
	
	always @(posedge clk) begin
		reg sync_old;
		reg old_rd2, old_wr2;
		reg st_num3_latch,st_num3_latch_pipe;
		reg ch2_lock;
		
		sync_old <= sync;
		if (!init_done) begin
			st_num <= 4'd0;
			wr2 <= '0;
			rd2 <= 0;
			rd2_pend <= 0;
			wr2_pend <= 0;
			ch2_lock <= 0;
			rd2_pipe <= 0;
		end else begin
			st_num <= st_num + 4'd1;
			if (!sync && sync_old) 
				st_num <= 4'd8;
			
			//chip 1
			if (st_num == 4'd15) begin
				raddr0 <= '{addr_a0[19:1],addr_b0[19:1]};
				raddr1 <= '{addr_a1[19:1],addr_b1[19:1]};
				waddr <= '{addr_a0,addr_b0};
				din <= '{din_a,din_b};
				wr <= '{wr_a,wr_b};
				rd <= '{rd_a & ~|wr_a,rd_b & ~|wr_b};
			end
			
			//chip 2
			old_rd2 <= ch2rd;
			old_wr2 <= |ch2wr;
			if (ch2wr && !old_wr2) wr2_pend <= 1;
			if (ch2rd && !old_rd2) rd2_pend <= 1;
			
			if (st_num[2:0] == 3'd7 && !rd2 && !wr2 && (rd2_pend || wr2_pend) && !ch2_lock) begin
				addr2 <= ch2addr;
				din2 <= ch2din;
				rd2 <= ch2rd & ~|ch2wr;
				wr2 <= |ch2wr;
				be2 <= ch2wr;
				st_num3_latch <= st_num[3];
				ch2_lock <= 1;
			end else if (st_num[3] == ~st_num3_latch && st_num[2:0] == 3'd4 && (wr2 || rd2)) begin
				wr2 <= 0;
				rd2 <= 0;
				be2 <= 2'b11;
				wr2_pend <= 0;
				rd2_pend <= 0;
				if (wr2) ch2_lock <= 0;
				
				addr2_pipe <= addr2;
				rd2_pipe <= rd2;
				st_num3_latch_pipe <= st_num3_latch;
			end
			if (st_num[3] == st_num3_latch_pipe && st_num[2:0] == 3'd4 && rd2_pipe) begin
				rd2_pipe <= 0;
				ch2_lock <= 0;
			end
		end
		
	end
	assign ch2rdy = ~(rd2_pend | wr2_pend);
	
	always @(posedge clk) begin
		state[0] <= '0;
		if (!init_done) begin
			state[0].CMD <= init_state == STATE_START ? CTRL_RAS : 
			                init_state == STATE_CONT  ? CTRL_CAS : 
								                             CTRL_IDLE;
			state[0].RFS <= 1;
		end else begin
			case (st_num[2:0])
				3'b000: begin state[0].CMD  <= wr2                             ? CTRL_RAS          : 
				                               rd2_pipe                        ? CTRL_CAS          : CTRL_IDLE;
								  state[0].ADDR <= wr2                             ? addr2[19:1]       : 
				                                                                 addr2_pipe[19:1];
				              state[0].RD   <= rd2_pipe;
				              state[0].BANK <= wr2                             ? addr2[21:20]      : 
				                                                                 addr2_pipe[21:20];
				              state[0].CHIP <= 1; end
								  
				3'b001: begin state[0].CMD  <=                                   CTRL_RAS;
								  state[0].ADDR <= rd[st_num[3]]                   ? raddr0[st_num[3]] : waddr[st_num[3]][19:1];
								  state[0].BANK <= rd[st_num[3]]                   ? {st_num[3],1'b0}  : {st_num[3],waddr[st_num[3]][20]};
								  state[0].RFS  <= ~|wr[st_num[3]] & ~rd[st_num[3]];
				              state[0].CHIP <= 0; end

				3'b010: begin state[0].CMD  <= rd[st_num[3]]                   ? CTRL_RAS          : CTRL_IDLE;
								  state[0].ADDR <= rd[st_num[3]]                   ? raddr1[st_num[3]] : '0;
								  state[0].BANK <= rd[st_num[3]]                   ? {st_num[3],1'b1}  : {st_num[3],1'b1};
				              state[0].CHIP <= 0; end
								  
				3'b011: begin state[0].CMD  <= wr2                             ? CTRL_CAS          : 
				                               rd2                             ? CTRL_RAS          : 
				                               !rd2_pipe                       ? CTRL_RAS          : CTRL_IDLE;
								  state[0].ADDR <=                                   addr2[19:1];
								  state[0].DATA <= din2;
								  state[0].WE   <= wr2;
								  state[0].BE   <= be2;
				              state[0].BANK <= addr2[21:20];
								  state[0].RFS  <= ~wr2 & ~rd2 & ~rd2_pipe;
				              state[0].CHIP <= 1; end

				3'b100: begin state[0].CMD  <= rd[st_num[3]]                   ? CTRL_CAS          : 
				                               wr[st_num[3]]                                       ? CTRL_CAS                        : CTRL_IDLE;
								  state[0].ADDR <= rd[st_num[3]]                   ? raddr0[st_num[3]] : {waddr[st_num[3]][19:3],2'b00};
				              state[0].RD   <= rd[st_num[3]];
								  state[0].DATA <= din[st_num[3]][63:48];
								  state[0].WE   <= |wr[st_num[3]];
								  state[0].BE   <= wr[st_num[3]][7:6];
								  state[0].BANK <= rd[st_num[3]]                   ? {st_num[3],1'b0}  : {st_num[3],waddr[st_num[3]][20]};
				              state[0].CHIP <= 0; end

				3'b101: begin state[0].CMD  <= wr[st_num[3]]                                       ? CTRL_CAS                        : CTRL_IDLE;
								  state[0].ADDR <=                                                       {waddr[st_num[3]][19:3],2'b01};
				              state[0].RD   <= 0;
								  state[0].DATA <= din[st_num[3]][47:32];
								  state[0].WE   <= |wr[st_num[3]];
								  state[0].BE   <= wr[st_num[3]][5:4];
								  state[0].BANK <=                                                       {st_num[3],waddr[st_num[3]][20]};
				              state[0].CHIP <= 0; end

				3'b110: begin state[0].CMD  <= rd[st_num[3]]                   ? CTRL_CAS          : 
				                               wr[st_num[3]]                                       ? CTRL_CAS                        : CTRL_IDLE;
								  state[0].ADDR <= rd[st_num[3]]                   ? raddr1[st_num[3]] : {waddr[st_num[3]][19:3],2'b10};
				              state[0].RD   <= rd[st_num[3]];
								  state[0].DATA <= din[st_num[3]][31:16];
								  state[0].WE   <= |wr[st_num[3]];
								  state[0].BE   <= wr[st_num[3]][3:2];
								  state[0].BANK <= rd[st_num[3]]                   ? {st_num[3],1'b1}  : {st_num[3],waddr[st_num[3]][20]};
				              state[0].CHIP <= 0; end

				3'b111: begin state[0].CMD  <= wr[st_num[3]]                                       ? CTRL_CAS                        : CTRL_IDLE;
								  state[0].ADDR <=                                                       {waddr[st_num[3]][19:3],2'b11};
				              state[0].RD   <= 0;
								  state[0].DATA <= din[st_num[3]][15:0];
								  state[0].WE   <= |wr[st_num[3]];
								  state[0].BE   <= wr[st_num[3]][1:0];
								  state[0].BANK <=                                                       {st_num[3],waddr[st_num[3]][20]};
				              state[0].CHIP <= 0; end
				default:;
			endcase
		end
		state[1] <= state[0];
		state[2] <= state[1];
		state[3] <= state[2];
		state[4] <= state[3];
		state[5] <= state[4];
	end
	
	wire [ 1:0] ctrl_cmd   = state[0].CMD;
	wire [19:1] ctrl_addr  = state[0].ADDR;
	wire [15:0] ctrl_data  = state[0].DATA;
//	wire        ctrl_rd    = state[0].RD;
	wire        ctrl_we    = state[0].WE;
	wire [ 1:0] ctrl_be    = state[0].BE;
	wire [ 1:0] ctrl_bank  = state[0].BANK;
	wire        ctrl_rfs   = state[0].RFS;
	wire        ctrl_chip  = state[0].CHIP;
	
	wire       data0_read = state[3].RD;
	wire       out0_read  = state[4].RD;
	wire [1:0] out0_bank  = state[4].BANK;
	wire       out0_chip  = state[4].CHIP;
	
	wire       data1_read = state[4].RD;
	wire       out1_read  = state[5].RD;
	wire [1:0] out1_bank  = state[5].BANK;
	wire       out1_chip  = state[5].CHIP;
	
	reg [15:0] rbuf;
	reg [31:0] dout[4] = '{4{'1}};
	reg [15:0] dout2 = '1;
	always @(posedge clk) begin
		if (data0_read || data1_read) rbuf <= SDRAM_DQ;

		if (out0_read && !out0_chip) dout[out0_bank][31:16] <= rbuf;
		if (out1_read && !out1_chip) dout[out1_bank][15: 0] <= rbuf;
		if (out1_read && out1_chip) dout2 <= rbuf;
	end
		
	assign {dout_a0,dout_a1,dout_b0,dout_b1} = {dout[0],dout[1],dout[2],dout[3]};
	assign ch2dout = dout2;
	

	localparam CMD_NOP             = 3'b111;
	localparam CMD_ACTIVE          = 3'b011;
	localparam CMD_READ            = 3'b101;
	localparam CMD_WRITE           = 3'b100;
	localparam CMD_BURST_TERMINATE = 3'b110;
	localparam CMD_PRECHARGE       = 3'b010;
	localparam CMD_AUTO_REFRESH    = 3'b001;
	localparam CMD_LOAD_MODE       = 3'b000;
	
	// SDRAM state machines
	wire [19:1] a = ctrl_addr;
	wire [15:0] d = ctrl_data;
	wire        we = ctrl_we;
	wire  [1:0] dqm = ~ctrl_be;
	wire        ra10 = 1;
	wire        wa10 = &ctrl_addr[2:1] | ctrl_chip;
	always @(posedge clk) begin
		if (ctrl_cmd == CTRL_RAS || ctrl_cmd == CTRL_CAS) SDRAM_BA <= (mode == MODE_NORMAL) ? ctrl_bank : 2'b00;

		casex({init_done,ctrl_rfs,we,mode,ctrl_cmd})
			{3'bX0X, MODE_NORMAL, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_ACTIVE,ctrl_chip};
			{3'bX1X, MODE_NORMAL, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_AUTO_REFRESH,ctrl_chip};
			{3'b101, MODE_NORMAL, CTRL_CAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_WRITE,ctrl_chip};
			{3'b100, MODE_NORMAL, CTRL_CAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_READ,ctrl_chip};

			// init
			{3'bXXX,    MODE_LDM, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_LOAD_MODE, init_chip};
			{3'bXXX,    MODE_PRE, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_PRECHARGE, init_chip};

										   default: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_nCS} <= {CMD_NOP,1'b1};
		endcase
		
		SDRAM_DQ <= 'Z;
		casex({init_done,ctrl_rfs,we,mode,ctrl_cmd})
			{3'b101, MODE_NORMAL, CTRL_CAS}: begin SDRAM_DQ <= d; dbg_sdram_d <= d; end
										   default: ;
		endcase

		if (mode == MODE_NORMAL) begin
			casex ({we,ctrl_cmd})
				{1'bX,CTRL_RAS}: SDRAM_A <= {2'b00,a[19:9]};
				{1'b0,CTRL_CAS}: SDRAM_A <= {2'b00,ra10,2'b00,a[8:1]};
				{1'b1,CTRL_CAS}: SDRAM_A <= {dqm  ,wa10 ,2'b00,a[8:1]};
			endcase;
		end
		else if (mode == MODE_LDM && ctrl_cmd == CTRL_RAS) SDRAM_A <= MODE[init_chip];
		else if (mode == MODE_PRE && ctrl_cmd == CTRL_RAS) SDRAM_A <= 13'b0010000000000;
		else SDRAM_A <= '0;
	end
	
	assign SDRAM_CKE = 1;
	assign {SDRAM_DQMH,SDRAM_DQML} = SDRAM_A[12:11];
	
	
	
	assign dbg_ctrl_bank = ctrl_bank;
	assign dbg_ctrl_cmd = ctrl_cmd;
	assign dbg_ctrl_we = ctrl_we;
	assign dbg_ctrl_rfs = ctrl_rfs;
	assign dbg_data0_read = data0_read;
	assign dbg_out0_read = out0_read;
	assign dbg_out0_bank = out0_bank;
	assign dbg_data1_read = data1_read;
	assign dbg_out1_read = out1_read;
	assign dbg_out1_bank = out1_bank;

	altddio_out
	#(
		.extend_oe_disable("OFF"),
		.intended_device_family("Cyclone V"),
		.invert_output("OFF"),
		.lpm_hint("UNUSED"),
		.lpm_type("altddio_out"),
		.oe_reg("UNREGISTERED"),
		.power_up_high("OFF"),
		.width(1)
	)
	sdramclk_ddr
	(
		.datain_h(1'b0),
		.datain_l(1'b1),
		.outclock(clk),
		.dataout(SDRAM_CLK),
		.aclr(1'b0),
		.aset(1'b0),
		.oe(1'b1),
		.outclocken(1'b1),
		.sclr(1'b0),
		.sset(1'b0)
	);

endmodule
