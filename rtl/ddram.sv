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

	input  [27:2] mem_addr,
	output [31:0] mem_dout,
	input  [31:0] mem_din,
	input         mem_rd,
	input   [3:0] mem_wr,
	output        mem_busy
);


assign mem_dout = raddr[2] ? ram_q[63:32] : ram_q[31:0];

reg [27:2] raddr;
reg  [7:0] ram_burst;
reg [63:0] ram_q, next_q;
reg [63:0] ram_data;
reg [27:2] ram_address, cache_addr;
reg        ram_read = 0;
reg        ram_write = 0;

reg [1:0]  state = 0;
reg        read_busy = 0;
reg        write_busy = 0;

always @(posedge clk) begin
	reg old_rd, old_we;

	old_rd <= mem_rd;
	old_we <= |mem_wr;
	if (~old_rd & mem_rd) read_busy <= 1;
	if (~old_we & |mem_wr) write_busy <= 1;
	raddr <= mem_addr;

	if(!DDRAM_BUSY) begin
		ram_write <= 0;
		ram_read  <= 0;

		case(state)
			0: if (write_busy) begin
					ram_data		<= {2{mem_din}};
					ram_address <= mem_addr;
					ram_write 	<= 1;
					ram_burst   <= 1;
					state       <= 1;
				end
				else if(read_busy) begin
					if (cache_addr[27:3] == raddr[27:3]) read_busy <= 0;
					else if ((cache_addr[27:3]+1'd1) == raddr[27:3]) begin
						read_busy    <= 0;
						ram_q       <= next_q;
						cache_addr  <= {raddr[27:3],1'b0};
						ram_address <= {raddr[27:3]+1'd1,1'b0};
						ram_read    <= 1;
						ram_burst   <= 1;
						state       <= 3;
					end
					else begin
						ram_address <= {raddr[27:3],1'b0};
						cache_addr  <= {raddr[27:3],1'b0};
						ram_read    <= 1;
						ram_burst   <= 2;
						state       <= 2;
					end 
				end

			1: begin
					cache_addr <= '1;
					cache_addr[3:2] <= 0;
					write_busy <= 0;
					state  <= 0;
				end
		
			2: if (DDRAM_DOUT_READY) begin
					ram_q  <= DDRAM_DOUT;
					read_busy <= 0;
					state  <= 3;
				end

			3: if (DDRAM_DOUT_READY) begin
					next_q <= DDRAM_DOUT;
					state  <= 0;
				end
		endcase
	end
end

assign mem_busy = read_busy | write_busy;

assign DDRAM_CLK      = clk;
assign DDRAM_BURSTCNT = ram_burst;
assign DDRAM_BE       = ram_read ? 8'hFF : ram_address[2] ? {mem_wr,4'b0000} : {4'b0000,mem_wr};
assign DDRAM_ADDR     = {4'b0011, ram_address[27:3]}; // RAM at 0x30000000
assign DDRAM_RD       = ram_read;
assign DDRAM_DIN      = ram_data;
assign DDRAM_WE       = ram_write;

endmodule
