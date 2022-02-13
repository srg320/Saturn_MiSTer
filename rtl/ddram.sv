//
// ddram.v
// Copyright (c) 2020 Sorgelig
//
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
// ------------------------------------------
//


module ddram
(
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,
	
	input         clk,

	input  [27:1] mem0_addr,
	output [31:0] mem0_dout,
	input  [31:0] mem0_din,
	input         mem0_rd,
	input   [3:0] mem0_wr,
	input         mem0_16b,
	input         mem0_wcen,
	output        mem0_busy,
	
	input  [27:1] mem1_addr,
	output [31:0] mem1_dout,
	input  [31:0] mem1_din,
	input         mem1_rd,
	input   [3:0] mem1_wr,
	input         mem1_16b,
	input         mem1_wcen,
	output        mem1_busy,

	input  [27:1] mem2_addr,
	output [31:0] mem2_dout,
	input  [31:0] mem2_din,
	input         mem2_rd,
	input   [3:0] mem2_wr,
	input         mem2_16b,
	input         mem2_wcen,
	output        mem2_busy,

	input  [27:1] mem3_addr,
	output [31:0] mem3_dout,
	input  [31:0] mem3_din,
	input         mem3_rd,
	input   [3:0] mem3_wr,
	input         mem3_16b,
	input         mem3_wcen,
	output        mem3_busy,

	input  [27:1] mem4_addr,
	output [31:0] mem4_dout,
	input  [31:0] mem4_din,
	input         mem4_rd,
	input   [3:0] mem4_wr,
	input         mem4_16b,
	input         mem4_wcen,
	output        mem4_busy,

	input  [27:1] mem5_addr,
	output [31:0] mem5_dout,
	input  [31:0] mem5_din,
	input         mem5_rd,
	input   [3:0] mem5_wr,
	input         mem5_16b,
	input         mem5_wcen,
	output        mem5_busy,

	input  [27:1] mem6_addr,
	output [31:0] mem6_dout,
	input  [31:0] mem6_din,
	input         mem6_rd,
	input   [3:0] mem6_wr,
	input         mem6_16b,
	input         mem6_wcen,
	output        mem6_busy,

	input  [27:1] mem7_addr,
	output [31:0] mem7_dout,
	input  [31:0] mem7_din,
	input         mem7_rd,
	input   [3:0] mem7_wr,
	input         mem7_16b,
	input         mem7_wcen,
	output        mem7_busy
);

reg  [ 27:  1] ram_address;
reg  [ 63:  0] ram_din;
reg  [  7:  0] ram_ba;
reg  [  7:  0] ram_burst;
reg            ram_read = 0;
reg            ram_write = 0;

reg  [ 27:  1] rcache_addr[8] = '{8{'1}};
reg  [127:  0] rcache_buf[8];
reg            rcache_word[8];
reg  [ 27:  1] wcache_addr[8] = '{8{'1}};
reg  [ 15:  0] wcache_be[8] = '{8{'0}};
reg  [127:  0] wcache_buf[8];
reg  [ 27:  1] write_addr[8];
reg  [127:  0] write_buf[8];
reg  [ 15:  0] write_be[8];

reg            read_busy[8] = '{8{0}};
reg  [  1:  0] write_busy[8] = '{8{'0}};

wire           mem_rd[8] = '{mem0_rd,mem1_rd,mem2_rd,mem3_rd,mem4_rd,mem5_rd,mem6_rd,mem7_rd};
wire [  3:  0] mem_wr[8] = '{mem0_wr,mem1_wr,mem2_wr,mem3_wr,mem4_wr,mem5_wr,mem6_wr,mem7_wr};
wire [ 27:  1] mem_addr[8] = '{mem0_addr,mem1_addr,mem2_addr,mem3_addr,mem4_addr,mem5_addr,mem6_addr,mem7_addr};
wire           mem_16b[8] = '{mem0_16b,mem1_16b,mem2_16b,mem3_16b,mem4_16b,mem5_16b,mem6_16b,mem7_16b};
wire [ 31:  0] mem_din[8] = '{mem0_din,mem1_din,mem2_din,mem3_din,mem4_din,mem5_din,mem6_din,mem7_din};
wire           mem_wcen[8] = '{mem0_wcen,mem1_wcen,mem2_wcen,mem3_wcen,mem4_wcen,mem5_wcen,mem6_wcen,mem7_wcen};
wire [ 31:  0] mem_dout[8];
wire           mem_busy[8];

reg  [  2:  0] state = 0;

always @(posedge clk) begin
	bit old_rd[8], old_we[8];
	bit write,read;
	bit [2:0] chan,ram_chan;

	for (int i=0; i<8; i++) begin
		old_rd[i] <= mem_rd[i];
		old_we[i] <= |mem_wr[i];
		if (mem_rd[i] && !old_rd[i]) begin
			if (rcache_addr[i][27:4] != mem_addr[i][27:4]) begin
				read_busy[i] <= 1;
			end
			rcache_addr[i] <= mem_addr[i];
			rcache_word[i] <= mem_16b[i];
			if (wcache_addr[i][27:4] == mem_addr[i][27:4] && wcache_be[i] && mem_wcen[i]) begin
				write_addr[i] <= wcache_addr[i];
				write_buf[i] <= wcache_buf[i];
				write_be[i] <= wcache_be[i];
				wcache_be[i] <= '0;
				write_busy[i] <= {|wcache_be[i][15:8],|wcache_be[i][7:0]};
				read_busy[i] <= 1;
			end
		end
		if (|mem_wr[i] && !old_we[i]) begin
			if (mem_wcen[i]) begin
				if (wcache_addr[i][27:4] != mem_addr[i][27:4]) begin
					if (wcache_be[i]) begin
						write_addr[i] <= wcache_addr[i];
						write_buf[i] <= wcache_buf[i];
						write_be[i] <= wcache_be[i];
						write_busy[i] <= {|wcache_be[i][15:8],|wcache_be[i][7:0]};
					end
					wcache_addr[i] <= mem_addr[i];
					wcache_be[i] <= '0;
				end 
				
				if (mem_16b[i]) 
					case (mem_addr[i][3:1])
						3'b000: begin
							if (mem_wr[i][1]) begin wcache_buf[i][127:120] <= mem_din[i][15:8]; wcache_be[i][15] <= 1; end
							if (mem_wr[i][0]) begin wcache_buf[i][119:112] <= mem_din[i][ 7:0]; wcache_be[i][14] <= 1; end
						end
						3'b001: begin
							if (mem_wr[i][1]) begin wcache_buf[i][111:104] <= mem_din[i][15:8]; wcache_be[i][13] <= 1; end
							if (mem_wr[i][0]) begin wcache_buf[i][103:096] <= mem_din[i][ 7:0]; wcache_be[i][12] <= 1; end
						end
						3'b010: begin
							if (mem_wr[i][1]) begin wcache_buf[i][095:088] <= mem_din[i][15:8]; wcache_be[i][11] <= 1; end
							if (mem_wr[i][0]) begin wcache_buf[i][087:080] <= mem_din[i][ 7:0]; wcache_be[i][10] <= 1; end
						end
						3'b011: begin
							if (mem_wr[i][1]) begin wcache_buf[i][079:072] <= mem_din[i][15:8]; wcache_be[i][ 9] <= 1; end
							if (mem_wr[i][0]) begin wcache_buf[i][071:064] <= mem_din[i][ 7:0]; wcache_be[i][ 8] <= 1; end
						end
						3'b100: begin
							if (mem_wr[i][1]) begin wcache_buf[i][063:056] <= mem_din[i][15:8]; wcache_be[i][ 7] <= 1; end
							if (mem_wr[i][0]) begin wcache_buf[i][055:048] <= mem_din[i][ 7:0]; wcache_be[i][ 6] <= 1; end
						end
						3'b101: begin
							if (mem_wr[i][1]) begin wcache_buf[i][047:040] <= mem_din[i][15:8]; wcache_be[i][ 5] <= 1; end
							if (mem_wr[i][0]) begin wcache_buf[i][039:032] <= mem_din[i][ 7:0]; wcache_be[i][ 4] <= 1; end
						end
						3'b110: begin
							if (mem_wr[i][1]) begin wcache_buf[i][031:024] <= mem_din[i][15:8]; wcache_be[i][ 3] <= 1; end
							if (mem_wr[i][0]) begin wcache_buf[i][023:016] <= mem_din[i][ 7:0]; wcache_be[i][ 2] <= 1; end
						end
						3'b111: begin
							if (mem_wr[i][1]) begin wcache_buf[i][015:008] <= mem_din[i][15:8]; wcache_be[i][ 1] <= 1; end
							if (mem_wr[i][0]) begin wcache_buf[i][007:000] <= mem_din[i][ 7:0]; wcache_be[i][ 0] <= 1; end
						end
					endcase
				else
					case (mem_addr[i][3:2])
						2'b00: begin
							if (mem_wr[i][3]) begin wcache_buf[i][127:120] <= mem_din[i][31:24]; wcache_be[i][15] <= 1; end
							if (mem_wr[i][2]) begin wcache_buf[i][119:112] <= mem_din[i][23:16]; wcache_be[i][14] <= 1; end
							if (mem_wr[i][1]) begin wcache_buf[i][111:104] <= mem_din[i][15: 8]; wcache_be[i][13] <= 1; end
							if (mem_wr[i][0]) begin wcache_buf[i][103:096] <= mem_din[i][ 7: 0]; wcache_be[i][12] <= 1; end
						end
						2'b01: begin
							if (mem_wr[i][3]) begin wcache_buf[i][095:088] <= mem_din[i][31:24]; wcache_be[i][11] <= 1; end
							if (mem_wr[i][2]) begin wcache_buf[i][087:080] <= mem_din[i][23:16]; wcache_be[i][10] <= 1; end
							if (mem_wr[i][1]) begin wcache_buf[i][079:072] <= mem_din[i][15: 8]; wcache_be[i][ 9] <= 1; end
							if (mem_wr[i][0]) begin wcache_buf[i][071:064] <= mem_din[i][ 7: 0]; wcache_be[i][ 8] <= 1; end
						end
						2'b10: begin
							if (mem_wr[i][3]) begin wcache_buf[i][063:056] <= mem_din[i][31:24]; wcache_be[i][ 7] <= 1; end
							if (mem_wr[i][2]) begin wcache_buf[i][055:048] <= mem_din[i][23:16]; wcache_be[i][ 6] <= 1; end
							if (mem_wr[i][1]) begin wcache_buf[i][047:040] <= mem_din[i][15: 8]; wcache_be[i][ 5] <= 1; end
							if (mem_wr[i][0]) begin wcache_buf[i][039:032] <= mem_din[i][ 7: 0]; wcache_be[i][ 4] <= 1; end
						end
						2'b11: begin
							if (mem_wr[i][3]) begin wcache_buf[i][031:024] <= mem_din[i][31:24]; wcache_be[i][ 3] <= 1; end
							if (mem_wr[i][2]) begin wcache_buf[i][023:016] <= mem_din[i][23:16]; wcache_be[i][ 2] <= 1; end
							if (mem_wr[i][1]) begin wcache_buf[i][015:008] <= mem_din[i][15: 8]; wcache_be[i][ 1] <= 1; end
							if (mem_wr[i][0]) begin wcache_buf[i][007:000] <= mem_din[i][ 7: 0]; wcache_be[i][ 0] <= 1; end
						end
					endcase
			end else begin
				write_addr[i] <= mem_addr[i];
				write_be[i] <= '0;
				write_busy[i] <= '0;
				if (mem_16b[i]) 
					case (mem_addr[i][3:1])
						3'b000: begin
							if (mem_wr[i][1]) begin write_buf[i][127:120] <= mem_din[i][15:8]; write_be[i][15] <= 1; write_busy[i][1] <= 1; end
							if (mem_wr[i][0]) begin write_buf[i][119:112] <= mem_din[i][ 7:0]; write_be[i][14] <= 1; write_busy[i][1] <= 1; end
						end
						3'b001: begin
							if (mem_wr[i][1]) begin write_buf[i][111:104] <= mem_din[i][15:8]; write_be[i][13] <= 1; write_busy[i][1] <= 1; end
							if (mem_wr[i][0]) begin write_buf[i][103:096] <= mem_din[i][ 7:0]; write_be[i][12] <= 1; write_busy[i][1] <= 1; end
						end
						3'b010: begin
							if (mem_wr[i][1]) begin write_buf[i][095:088] <= mem_din[i][15:8]; write_be[i][11] <= 1; write_busy[i][1] <= 1; end
							if (mem_wr[i][0]) begin write_buf[i][087:080] <= mem_din[i][ 7:0]; write_be[i][10] <= 1; write_busy[i][1] <= 1; end
						end
						3'b011: begin
							if (mem_wr[i][1]) begin write_buf[i][079:072] <= mem_din[i][15:8]; write_be[i][ 9] <= 1; write_busy[i][1] <= 1; end
							if (mem_wr[i][0]) begin write_buf[i][071:064] <= mem_din[i][ 7:0]; write_be[i][ 8] <= 1; write_busy[i][1] <= 1; end
						end
						3'b100: begin
							if (mem_wr[i][1]) begin write_buf[i][063:056] <= mem_din[i][15:8]; write_be[i][ 7] <= 1; write_busy[i][0] <= 1; end
							if (mem_wr[i][0]) begin write_buf[i][055:048] <= mem_din[i][ 7:0]; write_be[i][ 6] <= 1; write_busy[i][0] <= 1; end
						end
						3'b101: begin
							if (mem_wr[i][1]) begin write_buf[i][047:040] <= mem_din[i][15:8]; write_be[i][ 5] <= 1; write_busy[i][0] <= 1; end
							if (mem_wr[i][0]) begin write_buf[i][039:032] <= mem_din[i][ 7:0]; write_be[i][ 4] <= 1; write_busy[i][0] <= 1; end
						end
						3'b110: begin
							if (mem_wr[i][1]) begin write_buf[i][031:024] <= mem_din[i][15:8]; write_be[i][ 3] <= 1; write_busy[i][0] <= 1; end
							if (mem_wr[i][0]) begin write_buf[i][023:016] <= mem_din[i][ 7:0]; write_be[i][ 2] <= 1; write_busy[i][0] <= 1; end
						end
						3'b111: begin
							if (mem_wr[i][1]) begin write_buf[i][015:008] <= mem_din[i][15:8]; write_be[i][ 1] <= 1; write_busy[i][0] <= 1; end
							if (mem_wr[i][0]) begin write_buf[i][007:000] <= mem_din[i][ 7:0]; write_be[i][ 0] <= 1; write_busy[i][0] <= 1; end
						end
					endcase
				else
					case (mem_addr[i][3:2])
						2'b00: begin
							if (mem_wr[i][3]) begin write_buf[i][127:120] <= mem_din[i][31:24]; write_be[i][15] <= 1; write_busy[i][1] <= 1; end
							if (mem_wr[i][2]) begin write_buf[i][119:112] <= mem_din[i][23:16]; write_be[i][14] <= 1; write_busy[i][1] <= 1; end
							if (mem_wr[i][1]) begin write_buf[i][111:104] <= mem_din[i][15: 8]; write_be[i][13] <= 1; write_busy[i][1] <= 1; end
							if (mem_wr[i][0]) begin write_buf[i][103:096] <= mem_din[i][ 7: 0]; write_be[i][12] <= 1; write_busy[i][1] <= 1; end
						end
						2'b01: begin
							if (mem_wr[i][3]) begin write_buf[i][095:088] <= mem_din[i][31:24]; write_be[i][11] <= 1; write_busy[i][1] <= 1; end
							if (mem_wr[i][2]) begin write_buf[i][087:080] <= mem_din[i][23:16]; write_be[i][10] <= 1; write_busy[i][1] <= 1; end
							if (mem_wr[i][1]) begin write_buf[i][079:072] <= mem_din[i][15: 8]; write_be[i][ 9] <= 1; write_busy[i][1] <= 1; end
							if (mem_wr[i][0]) begin write_buf[i][071:064] <= mem_din[i][ 7: 0]; write_be[i][ 8] <= 1; write_busy[i][1] <= 1; end
						end
						2'b10: begin
							if (mem_wr[i][3]) begin write_buf[i][063:056] <= mem_din[i][31:24]; write_be[i][ 7] <= 1; write_busy[i][0] <= 1; end
							if (mem_wr[i][2]) begin write_buf[i][055:048] <= mem_din[i][23:16]; write_be[i][ 6] <= 1; write_busy[i][0] <= 1; end
							if (mem_wr[i][1]) begin write_buf[i][047:040] <= mem_din[i][15: 8]; write_be[i][ 5] <= 1; write_busy[i][0] <= 1; end
							if (mem_wr[i][0]) begin write_buf[i][039:032] <= mem_din[i][ 7: 0]; write_be[i][ 4] <= 1; write_busy[i][0] <= 1; end
						end
						2'b11: begin
							if (mem_wr[i][3]) begin write_buf[i][031:024] <= mem_din[i][31:24]; write_be[i][ 3] <= 1; write_busy[i][0] <= 1; end
							if (mem_wr[i][2]) begin write_buf[i][023:016] <= mem_din[i][23:16]; write_be[i][ 2] <= 1; write_busy[i][0] <= 1; end
							if (mem_wr[i][1]) begin write_buf[i][015:008] <= mem_din[i][15: 8]; write_be[i][ 1] <= 1; write_busy[i][0] <= 1; end
							if (mem_wr[i][0]) begin write_buf[i][007:000] <= mem_din[i][ 7: 0]; write_be[i][ 0] <= 1; write_busy[i][0] <= 1; end
						end
					endcase
			end
			
			if (rcache_addr[i][27:4] == mem_addr[i][27:4]) begin
				if (mem_16b[i]) 
					case (mem_addr[i][3:1])
						3'b000: begin
							if (mem_wr[i][1]) begin rcache_buf[i][127:120] <= mem_din[i][15:8]; end
							if (mem_wr[i][0]) begin rcache_buf[i][119:112] <= mem_din[i][ 7:0]; end
						end
						3'b001: begin
							if (mem_wr[i][1]) begin rcache_buf[i][111:104] <= mem_din[i][15:8]; end
							if (mem_wr[i][0]) begin rcache_buf[i][103:096] <= mem_din[i][ 7:0]; end
						end
						3'b010: begin
							if (mem_wr[i][1]) begin rcache_buf[i][095:088] <= mem_din[i][15:8]; end
							if (mem_wr[i][0]) begin rcache_buf[i][087:080] <= mem_din[i][ 7:0]; end
						end
						3'b011: begin
							if (mem_wr[i][1]) begin rcache_buf[i][079:072] <= mem_din[i][15:8]; end
							if (mem_wr[i][0]) begin rcache_buf[i][071:064] <= mem_din[i][ 7:0]; end
						end
						3'b100: begin
							if (mem_wr[i][1]) begin rcache_buf[i][063:056] <= mem_din[i][15:8]; end
							if (mem_wr[i][0]) begin rcache_buf[i][055:048] <= mem_din[i][ 7:0]; end
						end
						3'b101: begin
							if (mem_wr[i][1]) begin rcache_buf[i][047:040] <= mem_din[i][15:8]; end
							if (mem_wr[i][0]) begin rcache_buf[i][039:032] <= mem_din[i][ 7:0]; end
						end
						3'b110: begin
							if (mem_wr[i][1]) begin rcache_buf[i][031:024] <= mem_din[i][15:8]; end
							if (mem_wr[i][0]) begin rcache_buf[i][023:016] <= mem_din[i][ 7:0]; end
						end
						3'b111: begin
							if (mem_wr[i][1]) begin rcache_buf[i][015:008] <= mem_din[i][15:8]; end
							if (mem_wr[i][0]) begin rcache_buf[i][007:000] <= mem_din[i][ 7:0]; end
						end
					endcase
				else
					case (mem_addr[i][3:2])
						2'b00: begin
							if (mem_wr[i][3]) begin rcache_buf[i][127:120] <= mem_din[i][31:24]; end
							if (mem_wr[i][2]) begin rcache_buf[i][119:112] <= mem_din[i][23:16]; end
							if (mem_wr[i][1]) begin rcache_buf[i][111:104] <= mem_din[i][15: 8]; end
							if (mem_wr[i][0]) begin rcache_buf[i][103:096] <= mem_din[i][ 7: 0]; end
						end
						2'b01: begin
							if (mem_wr[i][3]) begin rcache_buf[i][095:088] <= mem_din[i][31:24]; end
							if (mem_wr[i][2]) begin rcache_buf[i][087:080] <= mem_din[i][23:16]; end
							if (mem_wr[i][1]) begin rcache_buf[i][079:072] <= mem_din[i][15: 8]; end
							if (mem_wr[i][0]) begin rcache_buf[i][071:064] <= mem_din[i][ 7: 0]; end
						end
						2'b10: begin
							if (mem_wr[i][3]) begin rcache_buf[i][063:056] <= mem_din[i][31:24]; end
							if (mem_wr[i][2]) begin rcache_buf[i][055:048] <= mem_din[i][23:16]; end
							if (mem_wr[i][1]) begin rcache_buf[i][047:040] <= mem_din[i][15: 8]; end
							if (mem_wr[i][0]) begin rcache_buf[i][039:032] <= mem_din[i][ 7: 0]; end
						end
						2'b11: begin
							if (mem_wr[i][3]) begin rcache_buf[i][031:024] <= mem_din[i][31:24]; end
							if (mem_wr[i][2]) begin rcache_buf[i][023:016] <= mem_din[i][23:16]; end
							if (mem_wr[i][1]) begin rcache_buf[i][015:008] <= mem_din[i][15: 8]; end
							if (mem_wr[i][0]) begin rcache_buf[i][007:000] <= mem_din[i][ 7: 0]; end
						end
					endcase
			end
		end
	end

	if(!DDRAM_BUSY) begin
		ram_write <= 0;
		ram_read  <= 0;

		case (state)
			0: begin
				write = 0;
				read = 0;
				chan = 3'h0;
				if      (write_busy[0]) begin write = 1; chan = 3'h0; end
				else if (read_busy[0])  begin read = 1;  chan = 3'h0; end
				else if (write_busy[1]) begin write = 1; chan = 3'h1; end
				else if (read_busy[1])  begin read = 1;  chan = 3'h1; end
				else if (write_busy[2]) begin write = 1; chan = 3'h2; end
				else if (read_busy[2])  begin read = 1;  chan = 3'h2; end
				else if (write_busy[3]) begin write = 1; chan = 3'h3; end
				else if (read_busy[3])  begin read = 1;  chan = 3'h3; end
				else if (write_busy[4]) begin write = 1; chan = 3'h4; end
				else if (read_busy[4])  begin read = 1;  chan = 3'h4; end
				else if (write_busy[5]) begin write = 1; chan = 3'h5; end
				else if (read_busy[5])  begin read = 1;  chan = 3'h5; end
				else if (write_busy[6]) begin write = 1; chan = 3'h6; end
				else if (read_busy[6])  begin read = 1;  chan = 3'h6; end
				else if (write_busy[7]) begin write = 1; chan = 3'h7; end
				else if (read_busy[7])  begin read = 1;  chan = 3'h7; end
				
				if (write) begin
					ram_address <= write_busy[chan][1] ? {write_addr[chan][27:4],3'b000} : {write_addr[chan][27:4],3'b100};
					ram_din		<= write_busy[chan][1] ? write_buf[chan][127:64]         : write_buf[chan][63:0];
					ram_ba      <= write_busy[chan][1] ? write_be[chan][15:8]            : write_be[chan][7:0];
					ram_write 	<= 1;
					ram_burst   <= 1;
					ram_chan    <= chan;
					state       <= 3'h1;
				end
				if (read) begin
					ram_address <= {rcache_addr[chan][27:4],3'b000};
					ram_ba      <= 8'hFF;
					ram_read    <= 1;
					ram_burst   <= 2;
					ram_chan    <= chan;
					state       <= 3'h2;
				end
			end

			3'h1: begin
				for (int i=0; i<8; i++) begin
					if (ram_chan == i) if (write_busy[i][1]) write_busy[i][1] <= 0;
					                   else                  write_busy[i][0] <= 0;
				end
				state <= 0;
			end
		
			3'h2: if (DDRAM_DOUT_READY) begin
				for (int i=0; i<8; i++) begin
					if (ram_chan == i) rcache_buf[i][127:64] <= DDRAM_DOUT;
				end
				state <= 3'h3;
			end

			3'h3: if (DDRAM_DOUT_READY) begin
				for (int i=0; i<8; i++) begin
					if (ram_chan == i) rcache_buf[i][63:0] <= DDRAM_DOUT;
					if (ram_chan == i) read_busy[i] <= 0;
				end
				state <= 0;
			end
		endcase
	end
end

always_comb begin
	bit [31:0] temp[8];
	
	for (int i=0; i<8; i++) begin
		case (rcache_addr[i][3:2])
			2'b00: temp[i] = rcache_buf[i][127:096];
			2'b01: temp[i] = rcache_buf[i][095:064];
			2'b10: temp[i] = rcache_buf[i][063:032];
			2'b11: temp[i] = rcache_buf[i][031:000];
		endcase
		if (rcache_word[i]) 
			case (rcache_addr[i][1])
				1'b0: mem_dout[i] = {16'h0000,temp[i][31:16]};
				1'b1: mem_dout[i] = {16'h0000,temp[i][15:00]};
			endcase
		else
			mem_dout[i] = temp[i];
			
		mem_busy[i] = read_busy[i] | |write_busy[i];
	end
end
assign {mem0_dout,mem1_dout,mem2_dout,mem3_dout,mem4_dout,mem5_dout,mem6_dout,mem7_dout} = {mem_dout[0],mem_dout[1],mem_dout[2],mem_dout[3],mem_dout[4],mem_dout[5],mem_dout[6],mem_dout[7]};
assign {mem0_busy,mem1_busy,mem2_busy,mem3_busy,mem4_busy,mem5_busy,mem6_busy,mem7_busy} = {mem_busy[0],mem_busy[1],mem_busy[2],mem_busy[3],mem_busy[4],mem_busy[5],mem_busy[6],mem_busy[7]};

assign DDRAM_CLK      = clk;
assign DDRAM_BURSTCNT = ram_burst;
assign DDRAM_BE       = ram_ba;
assign DDRAM_ADDR     = {4'b0011, ram_address[27:3]}; // RAM at 0x30000000
assign DDRAM_RD       = ram_read;
assign DDRAM_DIN      = ram_din;
assign DDRAM_WE       = ram_write;

endmodule
