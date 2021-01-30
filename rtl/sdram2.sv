module sdram2
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
	input             rst,			//

	input      [20:1] addr_a0,
	input      [20:1] addr_a1,
	input      [15:0] din_a,
	input       [1:0] wr_a,
	input             rd_a,
	output     [31:0] dout_a0,
	output     [31:0] dout_a1,
	
	input      [20:1] addr_b0,
	input      [20:1] addr_b1,
	input      [15:0] din_b,
	input       [1:0] wr_b,
	input             rd_b,
	output     [31:0] dout_b0,
	output     [31:0] dout_b1,
	
	output  state_t state0,

	output [1:0] dbg_ctrl_bank,
	output [1:0] dbg_ctrl_cmd,
	output [1:0] dbg_ctrl_we,
	output       dbg_ctrl_rfs,
	
	output       dbg_data0_read,
	output       dbg_out0_read,
	output [1:0] dbg_out0_bank,
	
	output       dbg_data1_read,
	output       dbg_out1_read,
	output [1:0] dbg_out1_bank
);

	localparam RASCAS_DELAY   = 3'd2; // tRCD=20ns -> 2 cycles@85MHz
	localparam BURST_LENGTH   = 3'd1; // 0=1, 1=2, 2=4, 3=8, 7=full page
	localparam ACCESS_TYPE    = 1'd0; // 0=sequential, 1=interleaved
	localparam CAS_LATENCY    = 3'd2; // 2/3 allowed
	localparam OP_MODE        = 2'd0; // only 0 (standard operation) allowed
	localparam NO_WRITE_BURST = 1'd1; // 0=write burst enabled, 1=only single access write

	localparam MODE = {3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 
	
	localparam STATE_IDLE  = 3'd0;             // state to check the requests
	localparam STATE_START = STATE_IDLE+1'd1;  // state in which a new command is started
	localparam STATE_CONT  = STATE_START+RASCAS_DELAY;
	localparam STATE_READY = STATE_CONT+CAS_LATENCY+1'd1;
	localparam STATE_LAST  = STATE_READY;      // last state in cycle
	
	localparam MODE_NORMAL = 2'b00;
	localparam MODE_RESET  = 2'b01;
	localparam MODE_LDM    = 2'b10;
	localparam MODE_PRE    = 2'b11;

	// initialization 
	reg [2:0] init_state = '0;
	reg [1:0] mode;
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
			init_done <= 0;
		end
		else if (init_state == STATE_LAST) begin
			if(reset != 0) begin
				reset <= reset - 5'd1;
				if (reset == 14)    mode <= MODE_PRE;
				else if(reset == 3) mode <= MODE_LDM;
				else                mode <= MODE_RESET;
			end
			else begin
				mode <= MODE_NORMAL;
				init_done <= 1;
			end
		end
	end
	
	localparam CTRL_NOP = 2'd0;
	localparam CTRL_RAS = 2'd1;
	localparam CTRL_CAS = 2'd2;
	
	typedef struct packed
	{
		bit [1:0] CMD;
		bit [1:0] BANK;
		bit [1:0] WR;
		bit       RD;
		bit       RFS;
	} state_t;
	state_t state[6];
	reg [3:0] st_num;
	
	reg        wa[2];
	reg [19:1] addr[4];
	reg [15:0] din[2];
	reg  [1:0] wr[2];
	reg        rd[2];
	
	always_comb begin	
		state[0] = '0;
		if (!init_done) begin
			state[0].CMD = init_state == STATE_START ? CTRL_RAS : init_state == STATE_CONT ? CTRL_CAS : CTRL_NOP;
			state[0].RFS = 1;
		end else begin
			case (st_num[2:0])
				3'b000: begin state[0].CMD =  rd[st_num[3]] ? CTRL_RAS : CTRL_NOP; end
				3'b010: begin state[0].CMD =  rd[st_num[3]] ? CTRL_CAS : CTRL_RAS;
				              state[0].RD  =  rd[st_num[3]];
								  state[0].RFS = ~|wr[st_num[3]] & ~rd[st_num[3]];     end

				3'b011: begin state[0].CMD =  rd[st_num[3]] ? CTRL_RAS : CTRL_NOP; end
				3'b100: begin state[0].CMD =  wr[st_num[3]] ? CTRL_CAS : CTRL_NOP;
								  state[0].WR  =  wr[st_num[3]];                       end
				3'b101: begin state[0].CMD =  rd[st_num[3]] ? CTRL_CAS : CTRL_NOP; 
				              state[0].RD  =  rd[st_num[3]];                       end
								  
				default:begin state[0].CMD =                  CTRL_NOP;            end
			endcase
			if (!rd[st_num[3]])           state[0].BANK = {st_num[3],wa[st_num[3]]};
			else if (st_num[2:0] <= 3'd2) state[0].BANK = {st_num[3],1'b0};
			else                          state[0].BANK = {st_num[3],1'b1};
		end
	end
	
	always @(posedge clk) begin
		reg rst_old;
		
		rst_old <= rst;
		if (!init_done) begin
			st_num <= '0;
		end else if (!rst && rst_old) begin
			st_num <= 4'd4;
		end else begin
			st_num <= st_num + 4'd1;
			state[1] <= state[0];
			state[2] <= state[1];
			state[3] <= state[2];
			state[4] <= state[3];
			state[5] <= state[4];
			if (st_num == 4'd15) begin
				wa <= '{addr_a0[20],addr_b0[20]};
				addr <= '{addr_a0[19:1],addr_a1[19:1],addr_b0[19:1],addr_b1[19:1]};
				din <= '{din_a,din_b};
				wr <= '{wr_a&{~rst,~rst},wr_b&{~rst,~rst}};
				rd <= '{rd_a&~|wr_a&~rst,rd_b&~|wr_b&~rst};
			end
		end
	end
	
	wire [1:0] ctrl_bank  = state[0].BANK;
	wire [1:0] ctrl_cmd   = state[0].CMD;
	wire [1:0] ctrl_we    = state[0].WR;
	wire       ctrl_rfs   = state[0].RFS;
	
	wire       data0_read = state[3].RD;
	wire       out0_read  = state[4].RD;
	wire [1:0] out0_bank  = state[4].BANK;
	
	wire       data1_read = state[4].RD;
	wire       out1_read  = state[5].RD;
	wire [1:0] out1_bank  = state[5].BANK;
	
	reg [31:0] dout[4];
	always @(posedge clk) begin
		reg [15:0] temp;
		
		if (data0_read || data1_read) temp <= SDRAM_DQ;

		if (out0_read) dout[out0_bank][15:0] <= temp;
		if (out1_read) dout[out1_bank][31:16] <= temp;
	end
		
	assign {dout_a0,dout_a1,dout_b0,dout_b1} = {dout[0],dout[1],dout[2],dout[3]};
	

	localparam CMD_NOP             = 3'b111;
	localparam CMD_ACTIVE          = 3'b011;
	localparam CMD_READ            = 3'b101;
	localparam CMD_WRITE           = 3'b100;
	localparam CMD_BURST_TERMINATE = 3'b110;
	localparam CMD_PRECHARGE       = 3'b010;
	localparam CMD_AUTO_REFRESH    = 3'b001;
	localparam CMD_LOAD_MODE       = 3'b000;
	
	// SDRAM state machines
	wire [19:1] a = addr[ctrl_bank];
	wire [15:0] d = din[ctrl_bank[1]];
	wire        we = |ctrl_we;
	wire  [1:0] dqm = ~(ctrl_we | ~{2{we}});
	always @(posedge clk) begin
		if (ctrl_cmd == CTRL_RAS) SDRAM_BA <= (mode == MODE_NORMAL) ? ctrl_bank : 2'b00;

		casex({init_done,ctrl_rfs,we,mode,ctrl_cmd})
			{3'bX0X, MODE_NORMAL, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_ACTIVE;
			{3'bX1X, MODE_NORMAL, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_AUTO_REFRESH;
			{3'b101, MODE_NORMAL, CTRL_CAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_WRITE;
			{3'b100, MODE_NORMAL, CTRL_CAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_READ;

			// init
			{3'bXXX,    MODE_LDM, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_LOAD_MODE;
			{3'bXXX,    MODE_PRE, CTRL_RAS}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_PRECHARGE;

										   default: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_NOP;
		endcase
		
		SDRAM_DQ <= 'Z;
		casex({init_done,ctrl_rfs,we,mode,ctrl_cmd})
			{3'b101, MODE_NORMAL, CTRL_CAS}: SDRAM_DQ <= d;
										   default: ;
		endcase

		if (mode == MODE_NORMAL) begin
			casex (ctrl_cmd)
				CTRL_RAS: SDRAM_A <= {2'b00, a[19:9]};
				CTRL_CAS: SDRAM_A <= {dqm, 3'b100, a[8:2], a[1] & we};
			endcase;
		end
		else if (mode == MODE_LDM && ctrl_cmd == CTRL_RAS) SDRAM_A <= MODE;
		else if (mode == MODE_PRE && ctrl_cmd == CTRL_RAS) SDRAM_A <= 13'b0010000000000;
		else SDRAM_A <= '0;
	end
	
	assign SDRAM_nCS = 0;
	assign SDRAM_CKE = 1;
	assign {SDRAM_DQMH,SDRAM_DQML} = SDRAM_A[12:11];
	
	
	
	assign state0 = state[0];
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
