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
	output        mem0_busy,
	
	input  [27:1] mem1_addr,
	output [31:0] mem1_dout,
	input  [31:0] mem1_din,
	input         mem1_rd,
	input   [3:0] mem1_wr,
	input         mem1_16b,
	output        mem1_busy,

	input  [27:1] mem2_addr,
	output [31:0] mem2_dout,
	input  [31:0] mem2_din,
	input         mem2_rd,
	input   [3:0] mem2_wr,
	input         mem2_16b,
//	input   [1:0] mem2_chan,
	output        mem2_busy,

	input  [27:1] mem3_addr,
	output [31:0] mem3_dout,
	input  [31:0] mem3_din,
	input         mem3_rd,
	input   [3:0] mem3_wr,
	input         mem3_16b,
	output        mem3_busy,

	input  [27:1] mem4_addr,
	output [31:0] mem4_dout,
	input  [31:0] mem4_din,
	input         mem4_rd,
	input   [3:0] mem4_wr,
	input         mem4_16b,
	output        mem4_busy,

	input  [27:1] mem5_addr,
	output [31:0] mem5_dout,
	input  [31:0] mem5_din,
	input         mem5_rd,
	input   [3:0] mem5_wr,
	input         mem5_16b,
	output        mem5_busy,

	input  [27:1] mem6_addr,
	output [31:0] mem6_dout,
	input  [31:0] mem6_din,
	input         mem6_rd,
	input   [3:0] mem6_wr,
	input         mem6_16b,
	output        mem6_busy
);

reg  [ 27:  1] ram_address;
reg  [ 63:  0] ram_din;
reg  [  7:  0] ram_ba;
reg  [  7:  0] ram_burst;
reg            ram_read = 0;
reg            ram_write = 0;

reg  [ 27:  1] rcache_addr[7] = '{7{'1}};
reg  [127:  0] rcache_buf[7];
reg            rcache_word[7];
reg  [ 27:  1] wcache_addr[7] = '{7{'1}};
reg  [ 15:  0] wcache_be[7] = '{7{'0}};
reg  [127:  0] wcache_buf[7];
reg  [ 27:  1] save_addr[7];
reg  [127:  0] save_buf[7];
reg  [ 15:  0] save_be[7];

reg            read_busy[7] = '{7{0}};
reg  [  1:  0] write_busy[7] = '{7{'0}};

wire           mem_rd[7] = '{mem0_rd,mem1_rd,mem2_rd,mem3_rd,mem4_rd,mem5_rd,mem6_rd};
wire [  3:  0] mem_wr[7] = '{mem0_wr,mem1_wr,mem2_wr,mem3_wr,mem4_wr,mem5_wr,mem6_wr};
wire [ 27:  1] mem_addr[7] = '{mem0_addr,mem1_addr,mem2_addr,mem3_addr,mem4_addr,mem5_addr,mem6_addr};
wire           mem_16b[7] = '{mem0_16b,mem1_16b,mem2_16b,mem3_16b,mem4_16b,mem5_16b,mem6_16b};
wire [ 31:  0] mem_din[7] = '{mem0_din,mem1_din,mem2_din,mem3_din,mem4_din,mem5_din,mem6_din};
wire [ 31:  0] mem_dout[7];
wire           mem_busy[7];


//reg  [ 27:  1] rcache1_addr = '1;
//reg  [127:  0] rcache1_buf;
//reg            rcache1_word;
//reg  [ 27:  1] wcache1_addr = '1;
//reg  [ 15:  0] wcache1_be = '0;
//reg  [127:  0] wcache1_buf;
//reg  [ 27:  1] save1_addr;
//reg  [127:  0] save1_buf;
//reg  [ 15:  0] save1_be;
//
//reg  [ 27:  1] cache2_addr[4] = '{4{'1}};
//reg  [127:  0] cache2_buf[4];
//reg            cache2_word;
//reg  [  2:  0] cache2_chan;
//reg  [ 27:  1] save2_addr;
//reg  [ 31:  0] save2_din;
//reg  [  3:  0] save2_wr;
//reg            save2_word;
//
//reg            read_busy1 = 0, read_busy2 = 0;
//reg  [  1:  0] write_busy1 = '0;
//reg            write_busy2 = 0;

reg  [  2:  0] state = 0;

always @(posedge clk) begin
	bit old_rd[7], old_we[7];
	bit write,read;
	bit [2:0] chan,ram_chan;
	bit rcache_match;
//	reg old_rd1, old_we1;
//	reg old_rd2, old_we2;

	for (int i=0; i<7; i++) begin
		old_rd[i] <= mem_rd[i];
		old_we[i] <= |mem_wr[i];
		if (mem_rd[i] && !old_rd[i]) begin
			if (rcache_addr[i][27:4] != mem_addr[i][27:4]) begin
				read_busy[i] <= 1;
			end
			rcache_addr[i] <= mem_addr[i];
			rcache_word[i] <= mem_16b[i];
			if (wcache_addr[i][27:4] == mem_addr[i][27:4] && wcache_be[i]) begin
				save_addr[i] <= wcache_addr[i];
				save_buf[i] <= wcache_buf[i];
				save_be[i] <= wcache_be[i];
				wcache_be[i] <= '0;
				write_busy[i] <= {|wcache_be[i][15:8],|wcache_be[i][7:0]};
				read_busy[i] <= 1;
			end
		end
		if (|mem_wr[i] && !old_we[i]) begin
			if (wcache_addr[i][27:4] != mem_addr[i][27:4]) begin
				if (wcache_be[i]) begin
					save_addr[i] <= wcache_addr[i];
					save_buf[i] <= wcache_buf[i];
					save_be[i] <= wcache_be[i];
					write_busy[i] <= {|wcache_be[i][15:8],|wcache_be[i][7:0]};
				end
				wcache_addr[i] <= mem_addr[i];
				wcache_be[i] <= '0;
			end
			
			rcache_match = (rcache_addr[i][27:4] == mem_addr[i][27:4]);
			if (mem_16b[i]) 
				case (mem_addr[i][3:1])
					3'b000: begin
						if (mem_wr[i][1]) begin wcache_buf[i][127:120] <= mem_din[i][15:8]; wcache_be[i][15] <= 1; rcache_buf[i][127:120] <= rcache_match ? mem_din[i][15:8] : rcache_buf[i][127:120]; end
						if (mem_wr[i][0]) begin wcache_buf[i][119:112] <= mem_din[i][ 7:0]; wcache_be[i][14] <= 1; rcache_buf[i][119:112] <= rcache_match ? mem_din[i][ 7:0] : rcache_buf[i][119:112]; end
					end
					3'b001: begin
						if (mem_wr[i][1]) begin wcache_buf[i][111:104] <= mem_din[i][15:8]; wcache_be[i][13] <= 1; rcache_buf[i][111:104] <= rcache_match ? mem_din[i][15:8] : rcache_buf[i][111:104]; end
						if (mem_wr[i][0]) begin wcache_buf[i][103:096] <= mem_din[i][ 7:0]; wcache_be[i][12] <= 1; rcache_buf[i][103:096] <= rcache_match ? mem_din[i][ 7:0] : rcache_buf[i][103:096]; end
					end
					3'b010: begin
						if (mem_wr[i][1]) begin wcache_buf[i][095:088] <= mem_din[i][15:8]; wcache_be[i][11] <= 1; rcache_buf[i][095:088] <= rcache_match ? mem_din[i][15:8] : rcache_buf[i][095:088]; end
						if (mem_wr[i][0]) begin wcache_buf[i][087:080] <= mem_din[i][ 7:0]; wcache_be[i][10] <= 1; rcache_buf[i][087:080] <= rcache_match ? mem_din[i][ 7:0] : rcache_buf[i][087:080]; end
					end
					3'b011: begin
						if (mem_wr[i][1]) begin wcache_buf[i][079:072] <= mem_din[i][15:8]; wcache_be[i][ 9] <= 1; rcache_buf[i][079:072] <= rcache_match ? mem_din[i][15:8] : rcache_buf[i][079:072]; end
						if (mem_wr[i][0]) begin wcache_buf[i][071:064] <= mem_din[i][ 7:0]; wcache_be[i][ 8] <= 1; rcache_buf[i][071:064] <= rcache_match ? mem_din[i][ 7:0] : rcache_buf[i][071:064]; end
					end
					3'b100: begin
						if (mem_wr[i][1]) begin wcache_buf[i][063:056] <= mem_din[i][15:8]; wcache_be[i][ 7] <= 1; rcache_buf[i][063:056] <= rcache_match ? mem_din[i][15:8] : rcache_buf[i][063:056]; end
						if (mem_wr[i][0]) begin wcache_buf[i][055:048] <= mem_din[i][ 7:0]; wcache_be[i][ 6] <= 1; rcache_buf[i][055:048] <= rcache_match ? mem_din[i][ 7:0] : rcache_buf[i][055:048]; end
					end
					3'b101: begin
						if (mem_wr[i][1]) begin wcache_buf[i][047:040] <= mem_din[i][15:8]; wcache_be[i][ 5] <= 1; rcache_buf[i][047:040] <= rcache_match ? mem_din[i][15:8] : rcache_buf[i][047:040]; end
						if (mem_wr[i][0]) begin wcache_buf[i][039:032] <= mem_din[i][ 7:0]; wcache_be[i][ 4] <= 1; rcache_buf[i][039:032] <= rcache_match ? mem_din[i][ 7:0] : rcache_buf[i][039:032]; end
					end
					3'b110: begin
						if (mem_wr[i][1]) begin wcache_buf[i][031:024] <= mem_din[i][15:8]; wcache_be[i][ 3] <= 1; rcache_buf[i][031:024] <= rcache_match ? mem_din[i][15:8] : rcache_buf[i][031:024]; end
						if (mem_wr[i][0]) begin wcache_buf[i][023:016] <= mem_din[i][ 7:0]; wcache_be[i][ 2] <= 1; rcache_buf[i][023:016] <= rcache_match ? mem_din[i][ 7:0] : rcache_buf[i][023:016]; end
					end
					3'b111: begin
						if (mem_wr[i][1]) begin wcache_buf[i][015:008] <= mem_din[i][15:8]; wcache_be[i][ 1] <= 1; rcache_buf[i][015:008] <= rcache_match ? mem_din[i][15:8] : rcache_buf[i][015:008]; end
						if (mem_wr[i][0]) begin wcache_buf[i][007:000] <= mem_din[i][ 7:0]; wcache_be[i][ 0] <= 1; rcache_buf[i][007:000] <= rcache_match ? mem_din[i][ 7:0] : rcache_buf[i][007:000]; end
					end
				endcase
			else
				case (mem_addr[i][3:2])
					2'b00: begin
						if (mem_wr[i][3]) begin wcache_buf[i][127:120] <= mem_din[i][31:24]; wcache_be[i][15] <= 1; rcache_buf[i][127:120] <= rcache_match ? mem_din[i][31:24] : rcache_buf[i][127:120]; end
						if (mem_wr[i][2]) begin wcache_buf[i][119:112] <= mem_din[i][23:16]; wcache_be[i][14] <= 1; rcache_buf[i][119:112] <= rcache_match ? mem_din[i][23:16] : rcache_buf[i][119:112]; end
						if (mem_wr[i][1]) begin wcache_buf[i][111:104] <= mem_din[i][15: 8]; wcache_be[i][13] <= 1; rcache_buf[i][111:104] <= rcache_match ? mem_din[i][15: 8] : rcache_buf[i][111:104]; end
						if (mem_wr[i][0]) begin wcache_buf[i][103:096] <= mem_din[i][ 7: 0]; wcache_be[i][12] <= 1; rcache_buf[i][103:096] <= rcache_match ? mem_din[i][ 7: 0] : rcache_buf[i][103:096]; end
					end
					2'b01: begin
						if (mem_wr[i][3]) begin wcache_buf[i][095:088] <= mem_din[i][31:24]; wcache_be[i][11] <= 1; rcache_buf[i][095:088] <= rcache_match ? mem_din[i][31:24] : rcache_buf[i][095:088]; end
						if (mem_wr[i][2]) begin wcache_buf[i][087:080] <= mem_din[i][23:16]; wcache_be[i][10] <= 1; rcache_buf[i][087:080] <= rcache_match ? mem_din[i][23:16] : rcache_buf[i][087:080]; end
						if (mem_wr[i][1]) begin wcache_buf[i][079:072] <= mem_din[i][15: 8]; wcache_be[i][ 9] <= 1; rcache_buf[i][079:072] <= rcache_match ? mem_din[i][15: 8] : rcache_buf[i][079:072]; end
						if (mem_wr[i][0]) begin wcache_buf[i][071:064] <= mem_din[i][ 7: 0]; wcache_be[i][ 8] <= 1; rcache_buf[i][071:064] <= rcache_match ? mem_din[i][ 7: 0] : rcache_buf[i][071:064]; end
					end
					2'b10: begin
						if (mem_wr[i][3]) begin wcache_buf[i][063:056] <= mem_din[i][31:24]; wcache_be[i][ 7] <= 1; rcache_buf[i][063:056] <= rcache_match ? mem_din[i][31:24] : rcache_buf[i][063:056]; end
						if (mem_wr[i][2]) begin wcache_buf[i][055:048] <= mem_din[i][23:16]; wcache_be[i][ 6] <= 1; rcache_buf[i][055:048] <= rcache_match ? mem_din[i][23:16] : rcache_buf[i][055:048]; end
						if (mem_wr[i][1]) begin wcache_buf[i][047:040] <= mem_din[i][15: 8]; wcache_be[i][ 5] <= 1; rcache_buf[i][047:040] <= rcache_match ? mem_din[i][15: 8] : rcache_buf[i][047:040]; end
						if (mem_wr[i][0]) begin wcache_buf[i][039:032] <= mem_din[i][ 7: 0]; wcache_be[i][ 4] <= 1; rcache_buf[i][039:032] <= rcache_match ? mem_din[i][ 7: 0] : rcache_buf[i][039:032]; end
					end
					2'b11: begin
						if (mem_wr[i][3]) begin wcache_buf[i][031:024] <= mem_din[i][31:24]; wcache_be[i][ 3] <= 1; rcache_buf[i][031:024] <= rcache_match ? mem_din[i][31:24] : rcache_buf[i][031:024]; end
						if (mem_wr[i][2]) begin wcache_buf[i][023:016] <= mem_din[i][23:16]; wcache_be[i][ 2] <= 1; rcache_buf[i][023:016] <= rcache_match ? mem_din[i][23:16] : rcache_buf[i][023:016]; end
						if (mem_wr[i][1]) begin wcache_buf[i][015:008] <= mem_din[i][15: 8]; wcache_be[i][ 1] <= 1; rcache_buf[i][015:008] <= rcache_match ? mem_din[i][15: 8] : rcache_buf[i][015:008]; end
						if (mem_wr[i][0]) begin wcache_buf[i][007:000] <= mem_din[i][ 7: 0]; wcache_be[i][ 0] <= 1; rcache_buf[i][007:000] <= rcache_match ? mem_din[i][ 7: 0] : rcache_buf[i][007:000]; end
					end
				endcase
		end
	end
//	old_rd1 <= mem1_rd;
//	old_we1 <= |mem1_wr;
//	if (mem1_rd && !old_rd1) begin
//		if (rcache1_addr[27:4] != mem1_addr[27:4]) begin
//			read_busy1 <= 1;
//		end
//		rcache1_addr <= mem1_addr;
//		rcache1_word <= mem1_16b;
//		if (wcache1_addr[27:4] == mem1_addr[27:4] && wcache1_be) begin
//			save1_addr <= wcache1_addr;
//			save1_buf <= wcache1_buf;
//			save1_be <= wcache1_be;
//			wcache1_be <= '0;
//			write_busy1 <= {|wcache1_be[15:8],|wcache1_be[7:0]};
//			read_busy1 <= 1;
//		end
//	end
//	if (|mem1_wr && !old_we1) begin
//		if (wcache1_addr[27:4] != mem1_addr[27:4]) begin
//			if (wcache1_be) begin
//				save1_addr <= wcache1_addr;
//				save1_buf <= wcache1_buf;
//				save1_be <= wcache1_be;
//				write_busy1 <= {|wcache1_be[15:8],|wcache1_be[7:0]};
//			end
//			wcache1_addr <= mem1_addr;
//			wcache1_be <= '0;
//		end
//		
//		if (mem1_16b) 
//			case (mem1_addr[3:1])
//				3'b000: begin
//					if (mem1_wr[1]) begin wcache1_buf[127:120] <= mem1_din[15:8]; wcache1_be[15] <= 1; end
//					if (mem1_wr[0]) begin wcache1_buf[119:112] <= mem1_din[ 7:0]; wcache1_be[14] <= 1; end
//				end
//				3'b001: begin
//					if (mem1_wr[1]) begin wcache1_buf[111:104] <= mem1_din[15:8]; wcache1_be[13] <= 1; end
//					if (mem1_wr[0]) begin wcache1_buf[103:096] <= mem1_din[ 7:0]; wcache1_be[12] <= 1; end
//				end
//				3'b010: begin
//					if (mem1_wr[1]) begin wcache1_buf[095:088] <= mem1_din[15:8]; wcache1_be[11] <= 1; end
//					if (mem1_wr[0]) begin wcache1_buf[087:080] <= mem1_din[ 7:0]; wcache1_be[10] <= 1; end
//				end
//				3'b011: begin
//					if (mem1_wr[1]) begin wcache1_buf[079:072] <= mem1_din[15:8]; wcache1_be[ 9] <= 1; end
//					if (mem1_wr[0]) begin wcache1_buf[071:064] <= mem1_din[ 7:0]; wcache1_be[ 8] <= 1; end
//				end
//				3'b100: begin
//					if (mem1_wr[1]) begin wcache1_buf[063:056] <= mem1_din[15:8]; wcache1_be[ 7] <= 1; end
//					if (mem1_wr[0]) begin wcache1_buf[055:048] <= mem1_din[ 7:0]; wcache1_be[ 6] <= 1; end
//				end
//				3'b101: begin
//					if (mem1_wr[1]) begin wcache1_buf[047:040] <= mem1_din[15:8]; wcache1_be[ 5] <= 1; end
//					if (mem1_wr[0]) begin wcache1_buf[039:032] <= mem1_din[ 7:0]; wcache1_be[ 4] <= 1; end
//				end
//				3'b110: begin
//					if (mem1_wr[1]) begin wcache1_buf[031:024] <= mem1_din[15:8]; wcache1_be[ 3] <= 1; end
//					if (mem1_wr[0]) begin wcache1_buf[023:016] <= mem1_din[ 7:0]; wcache1_be[ 2] <= 1; end
//				end
//				3'b111: begin
//					if (mem1_wr[1]) begin wcache1_buf[015:008] <= mem1_din[15:8]; wcache1_be[ 1] <= 1; end
//					if (mem1_wr[0]) begin wcache1_buf[007:000] <= mem1_din[ 7:0]; wcache1_be[ 0] <= 1; end
//				end
//			endcase
//		else
//			case (mem1_addr[3:2])
//				2'b00: begin
//					if (mem1_wr[3]) begin wcache1_buf[127:120] <= mem1_din[31:24]; wcache1_be[15] <= 1; end
//					if (mem1_wr[2]) begin wcache1_buf[119:112] <= mem1_din[23:16]; wcache1_be[14] <= 1; end
//					if (mem1_wr[1]) begin wcache1_buf[111:104] <= mem1_din[15: 8]; wcache1_be[13] <= 1; end
//					if (mem1_wr[0]) begin wcache1_buf[103:096] <= mem1_din[ 7: 0]; wcache1_be[12] <= 1; end
//				end
//				2'b01: begin
//					if (mem1_wr[3]) begin wcache1_buf[095:088] <= mem1_din[31:24]; wcache1_be[11] <= 1; end
//					if (mem1_wr[2]) begin wcache1_buf[087:080] <= mem1_din[23:16]; wcache1_be[10] <= 1; end
//					if (mem1_wr[1]) begin wcache1_buf[079:072] <= mem1_din[15: 8]; wcache1_be[ 9] <= 1; end
//					if (mem1_wr[0]) begin wcache1_buf[071:064] <= mem1_din[ 7: 0]; wcache1_be[ 8] <= 1; end
//				end
//				2'b10: begin
//					if (mem1_wr[3]) begin wcache1_buf[063:056] <= mem1_din[31:24]; wcache1_be[ 7] <= 1; end
//					if (mem1_wr[2]) begin wcache1_buf[055:048] <= mem1_din[23:16]; wcache1_be[ 6] <= 1; end
//					if (mem1_wr[1]) begin wcache1_buf[047:040] <= mem1_din[15: 8]; wcache1_be[ 5] <= 1; end
//					if (mem1_wr[0]) begin wcache1_buf[039:032] <= mem1_din[ 7: 0]; wcache1_be[ 4] <= 1; end
//				end
//				2'b11: begin
//					if (mem1_wr[3]) begin wcache1_buf[031:024] <= mem1_din[31:24]; wcache1_be[ 3] <= 1; end
//					if (mem1_wr[2]) begin wcache1_buf[023:016] <= mem1_din[23:16]; wcache1_be[ 2] <= 1; end
//					if (mem1_wr[1]) begin wcache1_buf[015:008] <= mem1_din[15: 8]; wcache1_be[ 1] <= 1; end
//					if (mem1_wr[0]) begin wcache1_buf[007:000] <= mem1_din[ 7: 0]; wcache1_be[ 0] <= 1; end
//				end
//			endcase
//	end
//
//	old_rd2 <= mem2_rd;
//	old_we2 <= |mem2_wr;
//	if (mem2_rd && !old_rd2) begin
//		cache2_addr[mem2_chan] <= mem2_addr;
//		cache2_chan <= mem2_chan;
//		cache2_word <= mem2_16b;
//		if (cache2_addr[mem2_chan][27:4] == mem2_addr[27:4]) begin
//		end else
//			read_busy2 <= 1;
//	end
//	if (|mem2_wr && !old_we2) begin
//		if (cache2_addr[mem2_chan][27:4] == mem2_addr[27:4]) begin
//			if (mem2_16b) 
//				case (mem2_addr[3:1])
//					3'b000: begin
//						if (mem2_wr[1]) cache2_buf[mem2_chan][127:120] <= mem2_din[15:8];
//						if (mem2_wr[0]) cache2_buf[mem2_chan][119:112] <= mem2_din[7:0];
//					end
//					3'b001: begin
//						if (mem2_wr[1]) cache2_buf[mem2_chan][111:104] <= mem2_din[15:8];
//						if (mem2_wr[0]) cache2_buf[mem2_chan][103:096] <= mem2_din[7:0];
//					end
//					3'b010: begin
//						if (mem2_wr[1]) cache2_buf[mem2_chan][095:088] <= mem2_din[15:8];
//						if (mem2_wr[0]) cache2_buf[mem2_chan][087:080] <= mem2_din[7:0];
//					end
//					3'b011: begin
//						if (mem2_wr[1]) cache2_buf[mem2_chan][079:072] <= mem2_din[15:8];
//						if (mem2_wr[0]) cache2_buf[mem2_chan][071:064] <= mem2_din[7:0];
//					end
//					3'b100: begin
//						if (mem2_wr[1]) cache2_buf[mem2_chan][063:056] <= mem2_din[15:8];
//						if (mem2_wr[0]) cache2_buf[mem2_chan][055:048] <= mem2_din[7:0];
//					end
//					3'b101: begin
//						if (mem2_wr[1]) cache2_buf[mem2_chan][047:040] <= mem2_din[15:8];
//						if (mem2_wr[0]) cache2_buf[mem2_chan][039:032] <= mem2_din[7:0];
//					end
//					3'b110: begin
//						if (mem2_wr[1]) cache2_buf[mem2_chan][031:024] <= mem2_din[15:8];
//						if (mem2_wr[0]) cache2_buf[mem2_chan][023:016] <= mem2_din[7:0];
//					end
//					3'b111: begin
//						if (mem2_wr[1]) cache2_buf[mem2_chan][015:008] <= mem2_din[15:8];
//						if (mem2_wr[0]) cache2_buf[mem2_chan][007:000] <= mem2_din[7:0];
//					end
//				endcase
//			else
//				case (mem2_addr[3:2])
//					2'b00: begin
//						if (mem2_wr[3]) cache2_buf[mem2_chan][127:120] <= mem2_din[31:24];
//						if (mem2_wr[2]) cache2_buf[mem2_chan][119:112] <= mem2_din[23:16];
//						if (mem2_wr[1]) cache2_buf[mem2_chan][111:104] <= mem2_din[15:8];
//						if (mem2_wr[0]) cache2_buf[mem2_chan][103:096] <= mem2_din[7:0];
//					end
//					2'b01: begin
//						if (mem2_wr[3]) cache2_buf[mem2_chan][095:088] <= mem2_din[31:24];
//						if (mem2_wr[2]) cache2_buf[mem2_chan][087:080] <= mem2_din[23:16];
//						if (mem2_wr[1]) cache2_buf[mem2_chan][079:072] <= mem2_din[15:8];
//						if (mem2_wr[0]) cache2_buf[mem2_chan][071:064] <= mem2_din[7:0];
//					end
//					2'b10: begin
//						if (mem2_wr[3]) cache2_buf[mem2_chan][063:056] <= mem2_din[31:24];
//						if (mem2_wr[2]) cache2_buf[mem2_chan][055:048] <= mem2_din[23:16];
//						if (mem2_wr[1]) cache2_buf[mem2_chan][047:040] <= mem2_din[15:8];
//						if (mem2_wr[0]) cache2_buf[mem2_chan][039:032] <= mem2_din[7:0];
//					end
//					2'b11: begin
//						if (mem2_wr[3]) cache2_buf[mem2_chan][031:024] <= mem2_din[31:24];
//						if (mem2_wr[2]) cache2_buf[mem2_chan][023:016] <= mem2_din[23:16];
//						if (mem2_wr[1]) cache2_buf[mem2_chan][015:008] <= mem2_din[15:8];
//						if (mem2_wr[0]) cache2_buf[mem2_chan][007:000] <= mem2_din[7:0];
//					end
//				endcase
//		end
//		save2_addr <= mem2_addr;
//		save2_din <= mem2_din;
//		save2_wr <= mem2_wr;
//		save2_word <= mem2_16b;
//		write_busy2 <= 1;
//	end

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
				
				if (write) begin
					ram_address <= write_busy[chan][1] ? {save_addr[chan][27:4],3'b000} : {save_addr[chan][27:4],3'b100};
					ram_din		<= write_busy[chan][1] ? save_buf[chan][127:64]         : save_buf[chan][63:0];
					ram_ba      <= write_busy[chan][1] ? save_be[chan][15:8]            : save_be[chan][7:0];
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
				for (int i=0; i<7; i++) begin
					if (ram_chan == i) if (write_busy[i][1]) write_busy[i][1] <= 0;
					                   else                  write_busy[i][0] <= 0;
				end
				state <= 0;
			end
		
			3'h2: if (DDRAM_DOUT_READY) begin
				for (int i=0; i<7; i++) begin
					if (ram_chan == i) rcache_buf[i][127:64] <= DDRAM_DOUT;
				end
				state <= 3'h3;
			end

			3'h3: if (DDRAM_DOUT_READY) begin
				for (int i=0; i<7; i++) begin
					if (ram_chan == i) rcache_buf[i][63:0] <= DDRAM_DOUT;
					if (ram_chan == i) read_busy[i] <= 0;
				end
				state <= 0;
			end
				
//			0: if (write_busy1) begin
//					ram_address <= write_busy1[1] ? {save1_addr[27:4],3'b000} : {save1_addr[27:4],3'b100};
//					ram_din		<= write_busy1[1] ? save1_buf[127:64]         : save1_buf[63:0];
//					ram_ba      <= write_busy1[1] ? save1_be[15:8]            : save1_be[7:0];
//					ram_write 	<= 1;
//					ram_burst   <= 1;
//					state       <= 3'h1;
//				end
//				else if (write_busy2) begin
//					ram_din		<= save2_word ? {4{save2_din[15:0]}} : {2{save2_din}};
//					ram_address <= save2_addr;
//					if (save2_word) 
//						case (save2_addr[2:1])
//							2'b00: ram_ba <= {save2_wr[1:0],6'b000000};
//							2'b01: ram_ba <= {2'b00,save2_wr[1:0],4'b0000};
//							2'b10: ram_ba <= {4'b0000,save2_wr[1:0],2'b00};
//							2'b11: ram_ba <= {6'b000000,save2_wr[1:0]};
//						endcase
//					else
//						case (save2_addr[2])
//							1'b0: ram_ba <= {save2_wr,4'b0000};
//							1'b1: ram_ba <= {4'b0000,save2_wr};
//						endcase
//					ram_write 	<= 1;
//					ram_burst   <= 1;
//					state       <= 3'h5;
//				end
//				else if (read_busy1) begin
//					ram_address <= {rcache1_addr[27:4],3'b000};
//					ram_ba      <= 8'hFF;
//					ram_read    <= 1;
//					ram_burst   <= 2;
//					state       <= 3'h2;
//				end
//				else if (read_busy2) begin
//					ram_address <= {cache2_addr[cache2_chan][27:4],3'b000};
//					ram_ba      <= 8'hFF;
//					ram_read    <= 1;
//					ram_burst   <= 2;
//					state       <= 3'h6;
//				end
//
//			3'h1,3'h5: begin
//					if (!state[2]) if (write_busy1[1]) write_busy1[1] <= 0;
//					               else                write_busy1[0] <= 0;
//					else           write_busy2 <= 0;
//					state  <= 0;
//				end
//		
//			3'h2,3'h6: if (DDRAM_DOUT_READY) begin
//					if (!state[2]) rcache1_buf[127:64] <= DDRAM_DOUT;
//					else           cache2_buf[cache2_chan][127:64] <= DDRAM_DOUT;
//					state <= state + 3'h1;
//				end
//
//			3'h3,3'h7: if (DDRAM_DOUT_READY) begin
//					if (!state[2]) rcache1_buf[63:0] <= DDRAM_DOUT;
//					else           cache2_buf[cache2_chan][63:0] <= DDRAM_DOUT;
//					if (!state[2]) read_busy1 <= 0;
//					else           read_busy2 <= 0;
//					state <= 0;
//				end
		endcase
	end
end

always_comb begin
	for (int i=0; i<7; i++) begin
		if (rcache_word[i]) 
			case (rcache_addr[i][3:1])
				3'b000: mem_dout[i] = {16'h0000,rcache_buf[i][127:112]};
				3'b001: mem_dout[i] = {16'h0000,rcache_buf[i][111:096]};
				3'b010: mem_dout[i] = {16'h0000,rcache_buf[i][095:080]};
				3'b011: mem_dout[i] = {16'h0000,rcache_buf[i][079:064]};
				3'b100: mem_dout[i] = {16'h0000,rcache_buf[i][063:048]};
				3'b101: mem_dout[i] = {16'h0000,rcache_buf[i][047:032]};
				3'b110: mem_dout[i] = {16'h0000,rcache_buf[i][031:016]};
				3'b111: mem_dout[i] = {16'h0000,rcache_buf[i][015:000]};
			endcase
		else
			case (rcache_addr[i][3:2])
				2'b00: mem_dout[i] = rcache_buf[i][127:096];
				2'b01: mem_dout[i] = rcache_buf[i][095:064];
				2'b10: mem_dout[i] = rcache_buf[i][063:032];
				2'b11: mem_dout[i] = rcache_buf[i][031:000];
			endcase
		mem_busy[i] = read_busy[i] | |write_busy[i];
	end
end
assign {mem0_dout,mem1_dout,mem2_dout,mem3_dout,mem4_dout,mem5_dout,mem6_dout} = {mem_dout[0],mem_dout[1],mem_dout[2],mem_dout[3],mem_dout[4],mem_dout[5],mem_dout[6]};
assign {mem0_busy,mem1_busy,mem2_busy,mem3_busy,mem4_busy,mem5_busy,mem6_busy} = {mem_busy[0],mem_busy[1],mem_busy[2],mem_busy[3],mem_busy[4],mem_busy[5],mem_busy[6]};

//always_comb begin
//	if (rcache1_word) 
//		case (rcache1_addr[3:1])
//			3'b000: mem1_dout = {16'h0000,rcache1_buf[127:112]};
//			3'b001: mem1_dout = {16'h0000,rcache1_buf[111:096]};
//			3'b010: mem1_dout = {16'h0000,rcache1_buf[095:080]};
//			3'b011: mem1_dout = {16'h0000,rcache1_buf[079:064]};
//			3'b100: mem1_dout = {16'h0000,rcache1_buf[063:048]};
//			3'b101: mem1_dout = {16'h0000,rcache1_buf[047:032]};
//			3'b110: mem1_dout = {16'h0000,rcache1_buf[031:016]};
//			3'b111: mem1_dout = {16'h0000,rcache1_buf[015:000]};
//		endcase
//	else
//		case (rcache1_addr[3:2])
//			2'b00: mem1_dout = rcache1_buf[127:096];
//			2'b01: mem1_dout = rcache1_buf[095:064];
//			2'b10: mem1_dout = rcache1_buf[063:032];
//			2'b11: mem1_dout = rcache1_buf[031:000];
//		endcase
//end
//assign mem1_busy = read_busy1 | |write_busy1;
//
//always_comb begin
//	if (cache2_word) 
//		case (cache2_addr[cache2_chan][3:1])
//			3'b000: mem2_dout = {16'h0000,cache2_buf[cache2_chan][127:112]};
//			3'b001: mem2_dout = {16'h0000,cache2_buf[cache2_chan][111:096]};
//			3'b010: mem2_dout = {16'h0000,cache2_buf[cache2_chan][095:080]};
//			3'b011: mem2_dout = {16'h0000,cache2_buf[cache2_chan][079:064]};
//			3'b100: mem2_dout = {16'h0000,cache2_buf[cache2_chan][063:048]};
//			3'b101: mem2_dout = {16'h0000,cache2_buf[cache2_chan][047:032]};
//			3'b110: mem2_dout = {16'h0000,cache2_buf[cache2_chan][031:016]};
//			3'b111: mem2_dout = {16'h0000,cache2_buf[cache2_chan][015:000]};
//		endcase
//	else
//		case (cache2_addr[cache2_chan][3:2])
//			2'b00: mem2_dout = cache2_buf[cache2_chan][127:096];
//			2'b01: mem2_dout = cache2_buf[cache2_chan][095:064];
//			2'b10: mem2_dout = cache2_buf[cache2_chan][063:032];
//			2'b11: mem2_dout = cache2_buf[cache2_chan][031:000];
//		endcase
//end
//assign mem2_busy = read_busy2 | write_busy2;


assign DDRAM_CLK      = clk;
assign DDRAM_BURSTCNT = ram_burst;
assign DDRAM_BE       = ram_ba;
assign DDRAM_ADDR     = {4'b0011, ram_address[27:3]}; // RAM at 0x30000000
assign DDRAM_RD       = ram_read;
assign DDRAM_DIN      = ram_din;
assign DDRAM_WE       = ram_write;

endmodule
