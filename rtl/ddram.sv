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
	input         rst,

	input  [24:1] mem0_addr,
	output [31:0] mem0_dout,
	input  [31:0] mem0_din,
	input         mem0_rd,
	input   [3:0] mem0_wr,
	input         mem0_16b,
	output        mem0_busy,
	
	input  [24:1] mem1_addr,
	output [31:0] mem1_dout,
	input  [31:0] mem1_din,
	input         mem1_rd,
	input   [3:0] mem1_wr,
	input         mem1_16b,
	output        mem1_busy,

	input  [24:1] mem2_addr,
	output [31:0] mem2_dout,
	input  [31:0] mem2_din,
	input         mem2_rd,
	input   [3:0] mem2_wr,
	input         mem2_16b,
	output        mem2_busy,

	input  [24:1] mem3_addr,
	output [31:0] mem3_dout,
	input  [31:0] mem3_din,
	input         mem3_rd,
	input   [3:0] mem3_wr,
	input         mem3_16b,
	output        mem3_busy,

	input  [24:1] mem4_addr,
	output [31:0] mem4_dout,
	input  [31:0] mem4_din,
	input         mem4_rd,
	input   [3:0] mem4_wr,
	input         mem4_16b,
	output        mem4_busy,

	input  [24:1] mem5_addr,
	output [31:0] mem5_dout,
	input  [31:0] mem5_din,
	input         mem5_rd,
	input   [3:0] mem5_wr,
	input         mem5_16b,
	output        mem5_busy,

	input  [24:1] mem6_addr,
	output [31:0] mem6_dout,
	input  [31:0] mem6_din,
	input         mem6_rd,
	input   [3:0] mem6_wr,
	input         mem6_16b,
	output        mem6_busy,

	input  [24:1] mem7_addr,
	output [31:0] mem7_dout,
	input  [31:0] mem7_din,
	input         mem7_rd,
	input   [3:0] mem7_wr,
	input         mem7_16b,
	output        mem7_busy,

	input  [24:1] mem8_addr,
	output [31:0] mem8_dout,
	input  [31:0] mem8_din,
	input         mem8_rd,
	input   [3:0] mem8_wr,
	input         mem8_16b,
	output        mem8_busy,

	input  [24:1] mem9_addr,
	output [31:0] mem9_dout,
	input  [31:0] mem9_din,
	input         mem9_rd,
	input   [3:0] mem9_wr,
	input         mem9_16b,
	output        mem9_busy
);

reg  [ 24:  1] ram_address;
reg  [ 63:  0] ram_din;
reg  [  7:  0] ram_ba;
reg  [  7:  0] ram_burst;
reg            ram_read = 0;
reg            ram_write = 0;
reg  [  3:  0] ram_chan;

reg  [ 24:  1] rcache_addr[10] = '{10{'1}};
reg  [127:  0] rcache_buf[10];
reg            rcache_word[10];
reg            rcache_update[10];
reg  [ 24:  1] write_addr[10];
reg  [ 63:  0] write_buf[10];
reg  [  7:  0] write_be[10];

reg            read_busy[10] = '{10{0}};
reg            write_busy[10] = '{10{0}};

wire           mem_rd[10] = '{mem0_rd,mem1_rd,mem2_rd,mem3_rd,mem4_rd,mem5_rd,mem6_rd,mem7_rd,mem8_rd,mem9_rd};
wire [  3:  0] mem_wr[10] = '{mem0_wr,mem1_wr,mem2_wr,mem3_wr,mem4_wr,mem5_wr,mem6_wr,mem7_wr,mem8_wr,mem9_wr};
wire [ 24:  1] mem_addr[10] = '{mem0_addr,mem1_addr,mem2_addr,mem3_addr,mem4_addr,mem5_addr,mem6_addr,mem7_addr,mem8_addr,mem9_addr};
wire           mem_16b[10] = '{mem0_16b,mem1_16b,mem2_16b,mem3_16b,mem4_16b,mem5_16b,mem6_16b,mem7_16b,mem8_16b,mem9_16b};
wire [ 31:  0] mem_din[10] = '{mem0_din,mem1_din,mem2_din,mem3_din,mem4_din,mem5_din,mem6_din,mem7_din,mem8_din,mem9_din};
wire [ 31:  0] mem_dout[10];
wire           mem_busy[10];

reg  [  2:  0] state = 0;

reg  [  1:  0] cache_wraddr;
reg            cache_update;

always @(posedge clk) begin
	bit old_rd[10], old_we[10], old_rst;
	bit write,read;
	bit [3:0] chan;

	old_rst <= rst;
	for (int i=0; i<10; i++) begin
		old_rd[i] <= mem_rd[i];
		old_we[i] <= |mem_wr[i];
		if (rst && !old_rst) begin
			rcache_addr[i] <= '1;
			read_busy[i] <= 0;
		end
		else if (mem_rd[i] && !old_rd[i]) begin
			if (rcache_addr[i][24:5] != mem_addr[i][24:5]) begin
				read_busy[i] <= 1;
			end
			rcache_addr[i] <= mem_addr[i];
			rcache_word[i] <= mem_16b[i];
		end
		
		if (rst && !old_rst) begin
			write_busy[i] <= 0;
			rcache_update[i] <= 0;
		end
		else if (|mem_wr[i] && !old_we[i]) begin
			write_addr[i] <= mem_addr[i];
			write_busy[i] <= 1;
			if (mem_16b[i]) begin
				write_buf[i] <= {4{mem_din[i][15:0]}};
				case (mem_addr[i][2:1])
					2'b00: write_be[i] <= {mem_wr[i][1:0],6'b000000};
					2'b01: write_be[i] <= {2'b00,mem_wr[i][1:0],4'b0000};
					2'b10: write_be[i] <= {4'b0000,mem_wr[i][1:0],2'b00};
					2'b11: write_be[i] <= {6'b000000,mem_wr[i][1:0]};
				endcase
			end else begin
				write_buf[i] <= {2{mem_din[i]}};
				case (mem_addr[i][2])
					1'b0: write_be[i] <= {mem_wr[i][3:0],4'b0000};
					1'b1: write_be[i] <= {4'b0000,mem_wr[i][3:0]};
				endcase
			end
			
			rcache_update[i] <= (rcache_addr[i][24:5] == mem_addr[i][24:5]);
		end
	end
	
	if (rst && !old_rst) begin
		state <= '0;
		ram_write <= 0;
		ram_read  <= 0;
	end
	else if(!DDRAM_BUSY) begin
		ram_write <= 0;
		ram_read  <= 0;

		case (state)
			0: begin
				write = 0;
				read = 0;
				chan = 4'h0;
				if      (write_busy[0]) begin write = 1; chan = 4'h0; end
				else if (read_busy[0])  begin read = 1;  chan = 4'h0; end
				else if (write_busy[1]) begin write = 1; chan = 4'h1; end
				else if (read_busy[1])  begin read = 1;  chan = 4'h1; end
				else if (write_busy[2]) begin write = 1; chan = 4'h2; end
				else if (read_busy[2])  begin read = 1;  chan = 4'h2; end
				else if (write_busy[3]) begin write = 1; chan = 4'h3; end
				else if (read_busy[3])  begin read = 1;  chan = 4'h3; end
				else if (write_busy[4]) begin write = 1; chan = 4'h4; end
				else if (read_busy[4])  begin read = 1;  chan = 4'h4; end
				else if (write_busy[5]) begin write = 1; chan = 4'h5; end
				else if (read_busy[5])  begin read = 1;  chan = 4'h5; end
				else if (write_busy[6]) begin write = 1; chan = 4'h6; end
				else if (read_busy[6])  begin read = 1;  chan = 4'h6; end
				else if (write_busy[7]) begin write = 1; chan = 4'h7; end
				else if (read_busy[7])  begin read = 1;  chan = 4'h7; end
				else if (write_busy[8]) begin write = 1; chan = 4'h8; end
				else if (read_busy[8])  begin read = 1;  chan = 4'h8; end
				else if (write_busy[9]) begin write = 1; chan = 4'h9; end
				else if (read_busy[9])  begin read = 1;  chan = 4'h9; end
				
				if (write) begin
					ram_address <= {write_addr[chan][24:3],2'b00};
					ram_din		<= write_buf[chan];
					ram_ba      <= write_be[chan];
					ram_write 	<= 1;
					ram_burst   <= 1;
					ram_chan    <= chan;
					cache_wraddr<= write_addr[chan][4:3];
					cache_update<= rcache_update[chan];
					write_busy[chan] <= 0;
					state       <= 3'h1;
				end
				if (read) begin
					ram_address <= {rcache_addr[chan][24:5],4'b0000};
					ram_ba      <= 8'hFF;
					ram_read    <= 1;
					ram_burst   <= 4;
					ram_chan    <= chan;
					cache_wraddr <= '0;
					state       <= 3'h2;
				end
			end

			3'h1: begin
				cache_update <= 0;
				state <= 0;
			end
		
			3'h2: if (DDRAM_DOUT_READY) begin
				for (int i=0; i<10; i++) begin
					cache_wraddr <= cache_wraddr + 2'd1;
					if (cache_wraddr == 2'd3) begin
						read_busy[ram_chan] <= 0;
						state <= 0;
					end
				end
			end
		endcase
	end
end


wire [ 63:  0] cache_data = state == 3'h1 ? write_buf[ram_chan] : DDRAM_DOUT; 
wire [  7:  0] cache_be = state == 3'h1 ? write_be[ram_chan] : 8'hFF; 
wire           cache_wren = (state == 3'h1 ? cache_update : state == 3'h2 ? DDRAM_DOUT_READY : 1'b0) && !DDRAM_BUSY;
wire [ 63:  0] cache_q[10];

ddr_cache_ram cache0 (clk, cache_wraddr, cache_data, cache_be, cache_wren & ram_chan == 0, rcache_addr[0][4:3], cache_q[0]);
ddr_cache_ram cache1 (clk, cache_wraddr, cache_data, cache_be, cache_wren & ram_chan == 1, rcache_addr[1][4:3], cache_q[1]);
ddr_cache_ram cache2 (clk, cache_wraddr, cache_data, cache_be, cache_wren & ram_chan == 2, rcache_addr[2][4:3], cache_q[2]);
ddr_cache_ram cache3 (clk, cache_wraddr, cache_data, cache_be, cache_wren & ram_chan == 3, rcache_addr[3][4:3], cache_q[3]);
ddr_cache_ram cache4 (clk, cache_wraddr, cache_data, cache_be, cache_wren & ram_chan == 4, rcache_addr[4][4:3], cache_q[4]);
ddr_cache_ram cache5 (clk, cache_wraddr, cache_data, cache_be, cache_wren & ram_chan == 5, rcache_addr[5][4:3], cache_q[5]);
ddr_cache_ram cache6 (clk, cache_wraddr, cache_data, cache_be, cache_wren & ram_chan == 6, rcache_addr[6][4:3], cache_q[6]);
ddr_cache_ram cache7 (clk, cache_wraddr, cache_data, cache_be, cache_wren & ram_chan == 7, rcache_addr[7][4:3], cache_q[7]);
ddr_cache_ram cache8 (clk, cache_wraddr, cache_data, cache_be, cache_wren & ram_chan == 8, rcache_addr[8][4:3], cache_q[8]);
ddr_cache_ram cache9 (clk, cache_wraddr, cache_data, cache_be, cache_wren & ram_chan == 9, rcache_addr[9][4:3], cache_q[9]);

always_comb begin
	for (int i=0; i<10; i++) begin
		if (rcache_word[i]) 
			case (rcache_addr[i][2:1])
				2'b00: mem_dout[i] = {16'h0000,cache_q[i][63:48]};
				2'b01: mem_dout[i] = {16'h0000,cache_q[i][47:32]};
				2'b10: mem_dout[i] = {16'h0000,cache_q[i][31:16]};
				2'b11: mem_dout[i] = {16'h0000,cache_q[i][15:00]};
			endcase
		else
			case (rcache_addr[i][2])
				1'b0: mem_dout[i] = cache_q[i][63:32];
				1'b1: mem_dout[i] = cache_q[i][31:00];
			endcase
			
		mem_busy[i] = read_busy[i] | |write_busy[i];
	end
end
assign {mem0_dout,mem1_dout,mem2_dout,mem3_dout,mem4_dout,mem5_dout,mem6_dout,mem7_dout,mem8_dout,mem9_dout} = {mem_dout[0],mem_dout[1],mem_dout[2],mem_dout[3],mem_dout[4],mem_dout[5],mem_dout[6],mem_dout[7],mem_dout[8],mem_dout[9]};
assign {mem0_busy,mem1_busy,mem2_busy,mem3_busy,mem4_busy,mem5_busy,mem6_busy,mem7_busy,mem8_busy,mem9_busy} = {mem_busy[0],mem_busy[1],mem_busy[2],mem_busy[3],mem_busy[4],mem_busy[5],mem_busy[6],mem_busy[7],mem_busy[8],mem_busy[9]};

assign DDRAM_CLK      = clk;
assign DDRAM_BURSTCNT = ram_burst;
assign DDRAM_BE       = ram_ba;
assign DDRAM_ADDR     = {7'b0011000, ram_address[24:3]}; // RAM at 0x30000000
assign DDRAM_RD       = ram_read;
assign DDRAM_DIN      = ram_din;
assign DDRAM_WE       = ram_write;

endmodule


module ddr_cache_ram (
	clock,
	wraddress,
	data,
	byteena,
	wren,
	rdaddress,
	q);

	input	  clock;
	input	[1:0]  wraddress;
	input	[63:0] data;
	input	 [7:0] byteena;
	input	       wren;
	input	[1:0]  rdaddress;
	output	[63:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0	  wren;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire [63:0] sub_wire0;
	wire [63:0] q = sub_wire0;

	altdpram	altdpram_component (
				.data (data),
				.inclock (clock),
				.rdaddress (rdaddress),
				.wraddress (wraddress),
				.wren (wren),
				.q (sub_wire0),
				.aclr (1'b0),
				.byteena (byteena),
				.inclocken (1'b1),
				.rdaddressstall (1'b0),
				.rden (1'b1),
				//.sclr (1'b0),
				.wraddressstall (1'b0));
	defparam
		altdpram_component.indata_aclr = "OFF",
		altdpram_component.indata_reg = "INCLOCK",
		altdpram_component.intended_device_family = "Cyclone V",
		altdpram_component.lpm_type = "altdpram",
		altdpram_component.outdata_aclr = "OFF",
		altdpram_component.outdata_reg = "UNREGISTERED",
		altdpram_component.power_up_uninitialized = "TRUE",
		altdpram_component.ram_block_type = "MLAB",
		altdpram_component.rdaddress_aclr = "OFF",
		altdpram_component.rdaddress_reg = "UNREGISTERED",
		altdpram_component.rdcontrol_aclr = "OFF",
		altdpram_component.rdcontrol_reg = "UNREGISTERED",
		altdpram_component.read_during_write_mode_mixed_ports = "CONSTRAINED_DONT_CARE",
		altdpram_component.width = 64,
		altdpram_component.widthad = 2,
		altdpram_component.byte_size = 8,
		altdpram_component.width_byteena = 8,
		altdpram_component.wraddress_aclr = "OFF",
		altdpram_component.wraddress_reg = "INCLOCK",
		altdpram_component.wrcontrol_aclr = "OFF",
		altdpram_component.wrcontrol_reg = "INCLOCK";

endmodule
