//============================================================================
//  FPGAGen port to MiSTer
//  Copyright (c) 2017-2019 Sorgelig
//
//  YM2612 implementation by Jose Tejada Gomez. Twitter: @topapate
//  Original Genesis code: Copyright (c) 2010-2013 Gregory Estrade (greg@torlus.com) 
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
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

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef DUAL_SDRAM
	//Secondary SDRAM
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign ADC_BUS  = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign BUTTONS   = osd_btn;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign USER_OUT = '0;

//assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;
//assign {SDRAM_CLK, SDRAM_A, SDRAM_BA} = '0;
//assign SDRAM_DQ = 'Z;
//assign {SDRAM_DQML, SDRAM_DQMH, SDRAM_nCS, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nWE, SDRAM_CKE} = '1;

always_comb begin
	if (status[10]) begin
		VIDEO_ARX = 8'd16;
		VIDEO_ARY = 8'd9;
	end else begin
		case(res) // {V30, H40}
			2'b00: begin // 256 x 224
				VIDEO_ARX = 8'd64;
				VIDEO_ARY = 8'd49;
			end

			2'b01: begin // 320 x 224
				VIDEO_ARX = status[30] ? 8'd10: 8'd64;
				VIDEO_ARY = status[30] ? 8'd7 : 8'd49;
			end

			2'b10: begin // 256 x 240
				VIDEO_ARX = 8'd128;
				VIDEO_ARY = 8'd105;
			end

			2'b11: begin // 320 x 240
				VIDEO_ARX = status[30] ? 8'd4 : 8'd128;
				VIDEO_ARY = status[30] ? 8'd3 : 8'd105;
			end
		endcase
	end
end

//assign VIDEO_ARX = status[10] ? 8'd16 : ((status[30] && wide_ar) ? 8'd10 : 8'd64);
//assign VIDEO_ARY = status[10] ? 8'd9  : ((status[30] && wide_ar) ? 8'd7  : 8'd49);

assign AUDIO_S = 1;
assign AUDIO_MIX = 0;

assign LED_DISK  = 0;
assign LED_POWER = 0;
assign LED_USER  = cart_download;


///////////////////////////////////////////////////

// Status Bit Map:
//             Upper                             Lower              
// 0         1         2         3          4         5         6   
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXXX XXXXXXXXXXXXXXXXXXX XX XXXXXXXXXXXXXx              

`include "build_id.v"
localparam CONF_STR = {
	"Saturn;;",
	"FS,BIN;",
	"-;",
	"oG,Time set,No,Yes;",
	"-;",
	"P1,Audio & Video;",
	"P1-;",
	"P1OA,Aspect Ratio,4:3,16:9;",
	"P1OU,320x224 Aspect,Original,Corrected;",
	"P1O13,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1-;",
	"P1OT,Border,No,Yes;",
	"P1oEF,Composite Blend,Off,On,Adaptive;",
	"P1-;",
	"P1OEF,Audio Filter,Model 1,Model 2,Minimal,No Filter;",
	"P1OB,FM Chip,YM2612,YM3438;",
	"P1ON,HiFi PCM,No,Yes;",

	"P2,Input;",
	"P2-;",
	"P2O4,Swap Joysticks,No,Yes;",
	"P2O5,6 Buttons Mode,No,Yes;",
	"P2o57,Multitap,Disabled,4-Way,TeamPlayer: Port1,TeamPlayer: Port2,J-Cart;",
	"P2-;",
	"P2OIJ,Mouse,None,Port1,Port2;",
	"P2OK,Mouse Flip Y,No,Yes;",
	"P2-;",
	"P2oD,Serial,OFF,SNAC;",
	"P2-;",
	"P2o89,Gun Control,Disabled,Joy1,Joy2,Mouse;",
	"D4P2oA,Gun Fire,Joy,Mouse;",
	"D4P2oBC,Cross,Small,Medium,Big,None;",

	"-;",
	"R0,Reset;",
	"J1,A,B,C,Start,Mode,X,Y,Z;",
	"jn,A,B,R,Start,Select,X,Y,L;", 
	"jp,Y,B,A,Start,Select,L,X,R;",
	"V,v",`BUILD_DATE
};

wire [63:0] status;
wire  [1:0] buttons;
wire [12:0] joystick_0,joystick_1,joystick_2,joystick_3,joystick_4;
wire  [7:0] joy0_x,joy0_y,joy1_x,joy1_y;
wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_data;
wire  [7:0] ioctl_index;
reg         ioctl_wait = 0;

reg  [31:0] sd_lba;
reg         sd_rd = 0;
reg         sd_wr = 0;
wire        sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire        img_readonly;
wire [63:0] img_size;

wire        forced_scandoubler;
wire [10:0] ps2_key;
wire [24:0] ps2_mouse;

wire [21:0] gamma_bus;
wire [15:0] sdram_sz;

hps_io #(.STRLEN($size(CONF_STR)>>3), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.joystick_2(joystick_2),
	.joystick_3(joystick_3),
	.joystick_4(joystick_4),
	.joystick_analog_0({joy0_y, joy0_x}),
	.joystick_analog_1({joy1_y, joy1_x}),

	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.new_vmode(new_vmode),

	.status(status),
	.status_in({status[63:8],region_req,status[5:0]}),
	.status_set(region_set),
	.status_menumask({1'b1,1'b1,~status[8],1'b1,1'b1}),

	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	.ioctl_wait(ioctl_wait),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

	.gamma_bus(gamma_bus),
	.sdram_sz(sdram_sz),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse)
);

wire code_index = &ioctl_index;
wire cart_download = ioctl_download & ~code_index;

reg osd_btn = 0;
//always @(posedge clk_sys) begin
//	integer timeout = 0;
//	reg     has_bootrom = 0;
//	reg     last_rst = 0;
//
//	if (RESET) last_rst = 0;
//	if (status[0]) last_rst = 1;
//
//	if (cart_download & ioctl_wr & status[0]) has_bootrom <= 1;
//
//	if(last_rst & ~status[0]) begin
//		osd_btn <= 0;
//		if(timeout < 24000000) begin
//			timeout <= timeout + 1;
//			osd_btn <= ~has_bootrom;
//		end
//	end
//end
///////////////////////////////////////////////////
wire clk_sys, clk_ram, locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys),
	.outclk_1(clk_ram),
	.locked(locked)
);


wire reset = RESET | status[0] | buttons[1];

wire [15:0] joy1 = {~joystick_0[0],~joystick_0[1],~joystick_0[2],~joystick_0[3],~joystick_0[7],~joystick_0[4],~joystick_0[6],~joystick_0[5],
                    ~joystick_0[8],~joystick_0[9],~joystick_0[10],~joystick_0[11],~joystick_0[12],3'b111};

//Genesis
wire [24:0] MEM_A;
wire [31:0] MEM_DI;
wire [31:0] MEM_DO;
wire        ROM_CS_N;
wire        RAML_CS_N;
wire        RAMH_CS_N;
wire  [3:0] MEM_DQM_N;
wire        MEM_RD_N;
wire        MEM_WAIT_N;

wire [18:1] VDP1_VRAM_A;
wire [15:0] VDP1_VRAM_D;
wire [31:0] VDP1_VRAM_Q;
wire  [1:0] VDP1_VRAM_WE;
wire        VDP1_VRAM_RD;
wire        VDP1_VRAM_ARDY;
wire        VDP1_VRAM_DRDY;
wire [17:1] VDP1_FB0_A;
wire [15:0] VDP1_FB0_D;
wire [15:0] VDP1_FB0_Q;
wire        VDP1_FB0_WE;
wire        VDP1_FB0_RD;
wire [17:1] VDP1_FB1_A;
wire [15:0] VDP1_FB1_D;
wire [15:0] VDP1_FB1_Q;
wire        VDP1_FB1_WE;
wire        VDP1_FB1_RD;

wire [16:1] VDP2_RA0_A;
wire [15:0] VDP2_RA0_D;
wire  [1:0] VDP2_RA0_WE;
wire        VDP2_RA0_RD;
wire [31:0] VDP2_RA0_Q;
wire [16:1] VDP2_RA1_A;
wire [15:0] VDP2_RA1_D;
wire  [1:0] VDP2_RA1_WE;
wire        VDP2_RA1_RD;
wire [31:0] VDP2_RA1_Q;
wire [16:1] VDP2_RB0_A;
wire [15:0] VDP2_RB0_D;
wire  [1:0] VDP2_RB0_WE;
wire        VDP2_RB0_RD;
wire [31:0] VDP2_RB0_Q;
wire [16:1] VDP2_RB1_A;
wire [15:0] VDP2_RB1_D;
wire  [1:0] VDP2_RB1_WE;
wire        VDP2_RB1_RD;
wire [31:0] VDP2_RB1_Q;

wire [18:1] SCSP_RAM_A;
wire [15:0] SCSP_RAM_D;
wire  [1:0] SCSP_RAM_WE;
wire        SCSP_RAM_RD;
wire [15:0] SCSP_RAM_Q;
wire        SCSP_RAM_RDY;

wire [7:0] r, g, b;
wire vs,hs;
wire ce_pix;
wire hblank, vblank;

Saturn saturn
(
	.RST_N(~(reset|cart_download)),
	.CLK(clk_sys),
	.CE(1),
	
	.SRES_N(~status[0]),
	
	.TIME_SET(~status[48]),
	
	.MEM_A(MEM_A),
	.MEM_DI(MEM_DI),
	.MEM_DO(MEM_DO),
	.MEM_DQM_N(MEM_DQM_N),
	.ROM_CS_N(ROM_CS_N),
	.RAML_CS_N(RAML_CS_N),
	.RAMH_CS_N(RAMH_CS_N),
	.MEM_RD_N(MEM_RD_N),
	.MEM_WAIT_N(MEM_WAIT_N),
	
	.VDP1_VRAM_A(VDP1_VRAM_A),
	.VDP1_VRAM_D(VDP1_VRAM_D),
	.VDP1_VRAM_WE(VDP1_VRAM_WE),
	.VDP1_VRAM_RD(VDP1_VRAM_RD),
	.VDP1_VRAM_Q(VDP1_VRAM_Q),
	.VDP1_VRAM_ARDY(VDP1_VRAM_ARDY),
	.VDP1_VRAM_DRDY(VDP1_VRAM_DRDY),
	.VDP1_FB0_A(VDP1_FB0_A),
	.VDP1_FB0_D(VDP1_FB0_D),
	.VDP1_FB0_WE(VDP1_FB0_WE),
	.VDP1_FB0_RD(VDP1_FB0_RD),
	.VDP1_FB0_Q(VDP1_FB0_Q),
	.VDP1_FB1_A(VDP1_FB1_A),
	.VDP1_FB1_D(VDP1_FB1_D),
	.VDP1_FB1_WE(VDP1_FB1_WE),
	.VDP1_FB1_RD(VDP1_FB1_RD),
	.VDP1_FB1_Q(VDP1_FB1_Q),
		
	.VDP2_RA0_A(VDP2_RA0_A),
	.VDP2_RA0_D(VDP2_RA0_D),
	.VDP2_RA0_WE(VDP2_RA0_WE),
	.VDP2_RA0_RD(VDP2_RA0_RD),
	.VDP2_RA0_Q(VDP2_RA0_Q),
	.VDP2_RA1_A(VDP2_RA1_A),
	.VDP2_RA1_D(VDP2_RA1_D),
	.VDP2_RA1_WE(VDP2_RA1_WE),
	.VDP2_RA1_RD(VDP2_RA1_RD),
	.VDP2_RA1_Q(VDP2_RA1_Q),
	.VDP2_RB0_A(VDP2_RB0_A),
	.VDP2_RB0_D(VDP2_RB0_D),
	.VDP2_RB0_WE(VDP2_RB0_WE),
	.VDP2_RB0_RD(VDP2_RB0_RD),
	.VDP2_RB0_Q(VDP2_RB0_Q),
	.VDP2_RB1_A(VDP2_RB1_A),
	.VDP2_RB1_D(VDP2_RB1_D),
	.VDP2_RB1_WE(VDP2_RB1_WE),
	.VDP2_RB1_RD(VDP2_RB1_RD),
	.VDP2_RB1_Q(VDP2_RB1_Q),
	
	.SCSP_RAM_A(SCSP_RAM_A),
	.SCSP_RAM_D(SCSP_RAM_D),
	.SCSP_RAM_WE(SCSP_RAM_WE),
	.SCSP_RAM_RD(SCSP_RAM_RD),
	.SCSP_RAM_Q(SCSP_RAM_Q),
	.SCSP_RAM_RDY(SCSP_RAM_RDY),
	
	.R(r),
	.G(g),
	.B(b),
	.DCLK(ce_pix),
	.VS_N(vs),
	.HS_N(hs),
	.HBL_N(hblank),
	.VBL_N(vblank),
	
	.JOY1(joy1),
	
	.SCRN_EN(SCRN_EN),
	.PAUSE_EN(DBG_PAUSE_EN)
);


//always @(posedge clk_sys) begin
//	reg old_busy;
//	
//	old_busy <= sdr_busy2;
//	if(cart_download & ioctl_wr) ioctl_wait <= 1;
//	if(old_busy & ~sdr_busy2) ioctl_wait <= 0;
//end


wire sdr_busy, sdr_busy1, sdr_busy2;
wire [15:0] sdr_do;
sdram sdram
(
	.*,
	.init(~locked),
	.clk(clk_ram),

	.addr0({6'b000000,SCSP_RAM_A[18:1]}), // 0000000-007FFFF
	.din0(SCSP_RAM_D),
	.dout0(SCSP_RAM_Q),
	.rd0(SCSP_RAM_RD),
	.wrl0(SCSP_RAM_WE[0]),
	.wrh0(SCSP_RAM_WE[1]),
	.busy0(sdr_busy),

	.addr1('0),
	.din1('0),
	.dout1(),
	.rd1(0),
	.wrl1(0),
	.wrh1(0),
	.busy1(sdr_busy1),

	.addr2('0),
	.din2('0),
	.dout2(),
	.rd2(0),
	.wrl2(0),
	.wrh2(0),
	.busy2(sdr_busy2)
);
assign SCSP_RAM_RDY = ~sdr_busy;

always @(posedge clk_sys) begin
	reg old_busy;
	
	old_busy <= ddr_busy;
	if(cart_download & ioctl_wr) ioctl_wait <= 1;
	if(old_busy & ~ddr_busy) ioctl_wait <= 0;
end

wire [27:1] ddr_addr = !ROM_CS_N  ? {9'b000000000,MEM_A[18:1]} :
                       !RAML_CS_N ? {8'b00000001, MEM_A[19:1]} :
							               {8'b00000010, MEM_A[19:2],1'b0};
wire [31:0] ddr_do;
wire        ddr_busy;
ddram ddram
(
	.*,
	.clk(clk_ram),

	.mem_addr(cart_download ? {3'b000,ioctl_addr[24:1]} : ddr_addr),
	.mem_dout(ddr_do),
	.mem_din(cart_download ? {ioctl_data[7:0],ioctl_data[15:8]} : MEM_DO),
	.mem_rd(cart_download ? 1'b0 : (~RAMH_CS_N | ~RAML_CS_N | ~ROM_CS_N) & ~MEM_RD_N),
	.mem_wr(cart_download ? {2'b00,{2{ioctl_wait}}} : {4{~RAMH_CS_N | ~RAML_CS_N | ~ROM_CS_N}} & ~MEM_DQM_N),
	.mem_16b(cart_download | ~RAML_CS_N | ~ROM_CS_N),
	.mem_busy(ddr_busy)
);
assign MEM_DI     = ddr_do;
assign MEM_WAIT_N = ~ddr_busy;

vdp1_fb vdp1_fb0
(
	.clock(clk_sys),
	.address({VDP1_FB0_A[9:1],VDP1_FB0_A[17:10]}),
	.data(VDP1_FB0_D),
	.wren(VDP1_FB0_WE),
	.q(VDP1_FB0_Q)
);

vdp1_fb vdp1_fb1
(
	.clock(clk_sys),
	.address({VDP1_FB1_A[9:1],VDP1_FB1_A[17:10]}),
	.data(VDP1_FB1_D),
	.wren(VDP1_FB1_WE),
	.q(VDP1_FB1_Q)
);

`ifdef DUAL_SDRAM
wire [31:0] sdr2ch2_do;
wire sdr2ch2_ardy,sdr2ch2_drdy;
sdram2 sdram2
(
	.SDRAM_CLK(SDRAM2_CLK),
	.SDRAM_A(SDRAM2_A),
	.SDRAM_BA(SDRAM2_BA),
	.SDRAM_DQ(SDRAM2_DQ),
	.SDRAM_nCS(SDRAM2_nCS),
	.SDRAM_nWE(SDRAM2_nWE),
	.SDRAM_nRAS(SDRAM2_nRAS),
	.SDRAM_nCAS(SDRAM2_nCAS),
	
	.init(~locked),
	.clk(clk_ram),
	.sync(ce_pix),

	.addr_a0({|VDP2_RA1_WE,3'b0000,VDP2_RA0_A}), // 0000000-001FFFF
	.addr_a1({|VDP2_RA1_WE,3'b0000,VDP2_RA1_A}),
	.din_a(VDP2_RA0_D),
	.wr_a(VDP2_RA0_WE|VDP2_RA1_WE),
	.rd_a(VDP2_RA0_RD|VDP2_RA1_RD),
	.dout_a0(VDP2_RA0_Q),
	.dout_a1(VDP2_RA1_Q),

	.addr_b0({|VDP2_RB1_WE,3'b0000,VDP2_RB0_A}),
	.addr_b1({|VDP2_RB1_WE,3'b0000,VDP2_RB1_A}),
	.din_b(VDP2_RB0_D),
	.wr_b(VDP2_RB0_WE|VDP2_RB1_WE),
	.rd_b(VDP2_RB0_RD|VDP2_RB1_RD),
	.dout_b0(VDP2_RB0_Q),
	.dout_b1(VDP2_RB1_Q),
	
	.ch2addr({3'b000,VDP1_VRAM_A[18:1]}),
	.ch2din(VDP1_VRAM_D),
	.ch2wr(VDP1_VRAM_WE),
	.ch2rd(VDP1_VRAM_RD),
	.ch2dout(sdr2ch2_do),
	.ch2ardy(sdr2ch2_ardy),
	.ch2drdy(sdr2ch2_drdy)
);
assign VDP1_VRAM_Q = sdr2ch2_do;
assign VDP1_VRAM_ARDY = sdr2ch2_ardy;
assign VDP1_VRAM_DRDY = sdr2ch2_drdy;
`else

`endif

//spram #(17,8)	sndram_l
//(
//	.clock(clk_sys),
//	.address(SCSP_RAM_A[17:1]),
//	.data(SCSP_RAM_D[7:0]),
//	.wren(SCSP_RAM_WE[0]),
//	.q(SCSP_RAM_Q[7:0])
//);
//
//spram #(17,8)	sndram_u
//(
//	.clock(clk_sys),
//	.address(SCSP_RAM_A[17:1]),
//	.data(SCSP_RAM_D[15:8]),
//	.wren(SCSP_RAM_WE[1]),
//	.q(SCSP_RAM_Q[15:8])
//);




wire PAL = status[7];

reg new_vmode;
always @(posedge clk_sys) begin
	reg old_pal;
	int to;
	
	if(~(reset | cart_download)) begin
		old_pal <= PAL;
		if(old_pal != PAL) to <= 5000000;
	end
	else to <= 5000000;
	
	if(to) begin
		to <= to - 1;
		if(to == 1) new_vmode <= ~new_vmode;
	end
end





assign VGA_F1 = 0;
assign {AUDIO_L,AUDIO_R} = '0;

reg interlace = 0;
reg [1:0] resolution = 2'b01;

//lock resolution for the whole frame.
reg [1:0] res = 2'b01;
//always @(posedge clk_sys) begin
//	reg old_vbl;
//	
//	old_vbl <= vblank;
//	if(old_vbl & ~vblank) res <= resolution;
//end


wire [2:0] scale = status[3:1];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;

assign CLK_VIDEO = clk_ram;
assign VGA_SL = {~interlace,~interlace}&sl[1:0];

reg old_ce_pix;
always @(posedge CLK_VIDEO) old_ce_pix <= ce_pix;

video_mixer #(.LINE_LENGTH(320), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
(
	.*,

	.clk_vid(CLK_VIDEO),
	.ce_pix(~old_ce_pix & ce_pix),
	.ce_pix_out(CE_PIXEL),

	.scanlines(0),
	.scandoubler(~interlace && (scale || forced_scandoubler)),
	.hq2x(scale==1),

	.mono(0),

	.R(r),
	.G(g),
	.B(b),

	// Positive pulses.
	.HSync(~hs),
	.VSync(~vs),
	.HBlank(~hblank),
	.VBlank(~vblank)
);

reg  [1:0] region_req;
reg        region_set = 0;


//debug
reg  [5:0] SCRN_EN = 6'b111111;
reg        DBG_PAUSE_EN = 0;

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state = 0;

	old_state <= ps2_key[10];
	if((ps2_key[10] != old_state) && pressed) begin
		casex(code)
			'h005: begin SCRN_EN[0] <= ~SCRN_EN[0]; end 	// F1
			'h006: begin SCRN_EN[1] <= ~SCRN_EN[1]; end 	// F2
			'h004: begin SCRN_EN[2] <= ~SCRN_EN[2]; end 	// F3
			'h00C: begin SCRN_EN[3] <= ~SCRN_EN[3]; end 	// F4
			'h003: begin SCRN_EN[4] <= ~SCRN_EN[4]; end 	// F5
			'h00B: begin SCRN_EN[5] <= ~SCRN_EN[5]; end 	// F6
			'h083: begin  end 	// F7
			'h00A: begin  end 	// F8
			'h001: begin  end 	// F9
			'h009: begin  end 	// F10
			'h078: begin  end 	// F11
			'h177: begin DBG_PAUSE_EN <= ~DBG_PAUSE_EN; end 	// Pause
		endcase
	end
end


endmodule
