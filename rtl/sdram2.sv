//
// sdram.v
//
// sdram controller implementation
// Copyright (c) 2018 Sorgelig
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

module sdram2
(

	// interface to the MT48LC16M16 chip
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

	input             rfs,
	
	input      [24:1] addr0,
	input             rd0,
	input             wrl0,
	input             wrh0,
	input      [15:0] din0,
	output reg [15:0] dout0,
	output            busy0,
	
	input      [24:1] addr1,
	input             rd1,
	input             wrl1,
	input             wrh1,
	input      [15:0] din1,
	output reg [15:0] dout1,
	output            busy1,
	
	input      [24:1] addr2,
	input             rd2,
	input             wrl2,
	input             wrh2,
	input      [15:0] din2,
	output reg [15:0] dout2,
	output            busy2
);

assign SDRAM_nCS = 0;
assign SDRAM_CKE = 1;
assign {SDRAM_DQMH,SDRAM_DQML} = SDRAM_A[12:11];

localparam RASCAS_DELAY   = 3'd2; // tRCD=20ns -> 2 cycles@85MHz
localparam BURST_LENGTH   = 3'd0; // 0=1, 1=2, 2=4, 3=8, 7=full page
localparam ACCESS_TYPE    = 1'd0; // 0=sequential, 1=interleaved
localparam CAS_LATENCY    = 3'd3; // 2/3 allowed
localparam OP_MODE        = 2'd0; // only 0 (standard operation) allowed
localparam NO_WRITE_BURST = 1'd1; // 0=write burst enabled, 1=only single access write

localparam MODE = { 3'b000, NO_WRITE_BURST, OP_MODE, CAS_LATENCY, ACCESS_TYPE, BURST_LENGTH}; 

localparam STATE_IDLE  = 3'd0;             // state to check the requests
localparam STATE_START = STATE_IDLE+1'd1;  // state in which a new command is started
localparam STATE_CONT  = STATE_START+RASCAS_DELAY;
localparam STATE_READY = STATE_CONT+CAS_LATENCY+1'd1;
localparam STATE_LAST  = STATE_READY;      // last state in cycle

reg  [2:0] state;
reg [22:1] a;
reg [15:0] data;
reg        we;
reg  [1:0] ba = '0;
reg  [1:0] dqm;
reg        active = 0;
reg  [2:0] read_exec = '0,write_exec = '0;
reg  [2:0] read_pend = '0,write_pend = '0;
reg        rfs_pend = 0;

wire [2:0] wr = {wrl2|wrh2,wrl1|wrh1,wrl0|wrh0};
wire [2:0] rd = {rd2,rd1,rd0};

localparam [9:0] RFS_CNT = 766;

// access manager
always @(posedge clk) begin
	reg  [9:0] rfs_timer = 0;
	reg  [2:0] old_rd, old_wr;
	reg        old_rfs;
	reg [15:0] dout;
	reg        data_out = 0;

	old_rd <= rd;
	old_wr <= wr;
	old_rfs <= rfs;

	if(rfs_timer) rfs_timer <= rfs_timer - 1'd1;
	
	if (rd[0] && ~old_rd[0]) read_pend[0] <= 1;
	if (rd[1] && ~old_rd[1]) read_pend[1] <= 1;
	if (rd[2] && ~old_rd[2]) read_pend[2] <= 1;
	if (wr[0] && ~old_wr[0]) write_pend[0] <= 1;
	if (wr[1] && ~old_wr[1]) write_pend[1] <= 1;
	if (wr[2] && ~old_wr[2]) write_pend[2] <= 1;
	if (rfs && ~old_rfs) rfs_pend <= 1;
	
	if(state == STATE_IDLE && mode == MODE_NORMAL) begin
		if (/*(~old_rd[0] && rd[0]) ||*/ write_pend[0] || read_pend[0]) begin
			{ba, a} <= addr0;
			data <= din0;
			we <= write_pend[0];
			dqm <= write_pend[0] ? ~{wrh0,wrl0} : 2'b00;
			read_exec[0] <= /*rd[0] |*/ read_pend[0];
			write_exec[0] <= write_pend[0];
			active <= 1;
			read_pend[0] <= 0; 
			write_pend[0] <= 0;
			state <= STATE_START;
		end
		else if (/*(~old_rd[1] && rd[1]) ||*/ write_pend[1] || read_pend[1]) begin
			{ba, a} <= addr1;
			data <= din1;
			we <= write_pend[1];
			dqm <= write_pend[1] ? ~{wrh1,wrl1} : 2'b00;
			read_exec[1] <= /*rd[1] |*/ read_pend[1];
			write_exec[1] <= write_pend[1];
			active <= 1;
			read_pend[1] <= 0; 
			write_pend[1] <= 0;
			state <= STATE_START;
		end
		else if (/*(~old_rd[2] && rd[2]) ||*/ write_pend[2] || read_pend[2]) begin
			{ba, a} <= addr2;
			data <= din2;
			we <= write_pend[2];
			dqm <= write_pend[2] ? ~{wrh2,wrl2} : 2'b00;
			read_exec[2] <= /*rd[2] |*/ read_pend[2];
			write_exec[2] <= write_pend[2];
			active <= 1;
			read_pend[2] <= 0; 
			write_pend[2] <= 0;
			state <= STATE_START;
		end
		else if (!rfs_timer || rfs_pend) begin
			rfs_timer <= RFS_CNT;
			active <= 0;
			we <= 0;
			dqm <= 0;
			rfs_pend <= 0;
			state <= STATE_START;
		end
	end

	data_out <= 0;
	if(state == STATE_READY && active) begin
		dout <= SDRAM_DQ;
		data_out <= ~|write_exec;
		if (write_exec[0]) write_exec[0] <= 0;
		if (write_exec[1]) write_exec[1] <= 0;
		if (write_exec[2]) write_exec[2] <= 0;
		active <= 0;
	end

	if(mode != MODE_NORMAL || state != STATE_IDLE || reset) begin
		state <= state + 1'd1;
		if(state == STATE_LAST) state <= STATE_IDLE;
	end
	
	if (data_out) begin
		if (read_exec[0]) begin dout0 <= dout; read_exec[0] <= 0; end
		if (read_exec[1]) begin dout1 <= dout; read_exec[1] <= 0; end
		if (read_exec[2]) begin dout2 <= dout; read_exec[2] <= 0; end
	end
end

assign busy0 = write_pend[0] | read_pend[0] | read_exec[0] | write_exec[0];
assign busy1 = write_pend[1] | read_pend[1] | read_exec[1] | write_exec[1];
assign busy2 = write_pend[2] | read_pend[2] | read_exec[2] | write_exec[2];


localparam MODE_NORMAL = 2'b00;
localparam MODE_RESET  = 2'b01;
localparam MODE_LDM    = 2'b10;
localparam MODE_PRE    = 2'b11;

// initialization 
reg [1:0] mode;
reg [4:0] reset=5'h1f;
always @(posedge clk) begin
	reg init_old=0;
	init_old <= init;

	if(init_old & ~init) reset <= 5'h1f;
	else if(state == STATE_LAST) begin
		if(reset != 0) begin
			reset <= reset - 5'd1;
			if(reset == 14)     mode <= MODE_PRE;
			else if(reset == 3) mode <= MODE_LDM;
			else                mode <= MODE_RESET;
		end
		else mode <= MODE_NORMAL;
	end
end

localparam CMD_NOP             = 3'b111;
localparam CMD_ACTIVE          = 3'b011;
localparam CMD_READ            = 3'b101;
localparam CMD_WRITE           = 3'b100;
localparam CMD_BURST_TERMINATE = 3'b110;
localparam CMD_PRECHARGE       = 3'b010;
localparam CMD_AUTO_REFRESH    = 3'b001;
localparam CMD_LOAD_MODE       = 3'b000;

// SDRAM state machines
always @(posedge clk) begin
	if(state == STATE_START) SDRAM_BA <= (mode == MODE_NORMAL) ? ba : 2'b00;

	SDRAM_DQ <= 'Z;
	casex({active,we,mode,state})
		{2'bXX, MODE_NORMAL, STATE_START}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= active ? CMD_ACTIVE : CMD_AUTO_REFRESH;
		{2'b11, MODE_NORMAL, STATE_CONT }: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE, SDRAM_DQ} <= {CMD_WRITE, data};
		{2'b10, MODE_NORMAL, STATE_CONT }: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_READ;

		// init
		{2'bXX,    MODE_LDM, STATE_START}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_LOAD_MODE;
		{2'bXX,    MODE_PRE, STATE_START}: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_PRECHARGE;

		                          default: {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_NOP;
	endcase

	if(mode == MODE_NORMAL) begin
		casex(state)
			STATE_START: SDRAM_A <= a[13:1];
			STATE_CONT:  SDRAM_A <= {dqm, 2'b10, a[22:14]};
		endcase;
	end
	else if(mode == MODE_LDM && state == STATE_START) SDRAM_A <= MODE;
	else if(mode == MODE_PRE && state == STATE_START) SDRAM_A <= 13'b0010000000000;
	else SDRAM_A <= 0;
end

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
