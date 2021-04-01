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

assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;
//assign {SDRAM_CLK, SDRAM_A, SDRAM_BA} = '0;
//assign SDRAM_DQ = 'Z;
//assign {SDRAM_DQML, SDRAM_DQMH, SDRAM_nCS, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nWE, SDRAM_CKE} = '1;
assign {SDRAM2_CLK, SDRAM2_A, SDRAM2_BA} = '0;
assign SDRAM2_DQ = 'Z;
assign {SDRAM2_nCS, SDRAM2_nCAS, SDRAM2_nRAS, SDRAM2_nWE} = '1;

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
// XXXXXXXXXXXX XXXXXXXXXXXXXXXXXXX XX XXXXXXXXXXXXX               

`include "build_id.v"
localparam CONF_STR = {
	"Saturn;;",
	"FS0,BIN;",
	"FS1,BIN;",
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
wire [11:0] joystick_0,joystick_1,joystick_2,joystick_3,joystick_4;
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

assign sd_buff_din = '0;

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

wire [18:1] SCSP_RAM_A;
wire [15:0] SCSP_RAM_D;
wire [15:0] SCSP_RAM_Q;
wire  [1:0] SCSP_RAM_WE;
wire        SCSP_RAM_RD;
wire        SCSP_RAM_CS;
wire        SCSP_RAM_RDY;

wire [15:0] SOUND_L;
wire [15:0] SOUND_R;

bit         SCCE_R;
bit         SCCE_F;
bit  [23:1] SCA;
bit  [15:0] SCDI;
bit  [15:0] SCDO;
bit         SCRW_N;
bit         SCAS_N;
bit         SCLDS_N;
bit         SCUDS_N;
bit         SCDTACK_N;
bit   [2:0] SCFC;
bit         SCAVEC_N;
bit   [2:0] SCIPL_N;
	
wire        SCSP_IO_RDY_N;
	

reg CE_R, CE_F;
always @(posedge clk_sys) begin
	CE_R <= ~CE_R;
end
assign CE_F = ~CE_R;

wire SCSP_CE;
CEGen SCSPCEGen
(
	.CLK(clk_sys),
	.RST_N(~reset),
	.IN_CLK(53693175),
	.OUT_CLK(22579200),
	.CE(SCSP_CE)
);


SCSP SCSP
(
	.CLK(clk_sys),
	.RST_N(~(reset) & (SCSP_IO_RST_N | ioctl_index[0])),
	.CE(SCSP_CE),
	
	.RES_N(1'b1),
		
	.CE_R(CE_R),
	.CE_F(CE_F),
	.DI(SCSP_IO_D),
	.DO(),
	.AD_N(SCSP_IO_AD_N),
	.DTEN_N(SCSP_IO_DTEN_N),
	.CS_N(SCSP_IO_CS_N),
	.WE_N({2{SCSP_IO_WE_N}}),
	.RDY_N(SCSP_IO_RDY_N),
		
	.SCCE_R(SCCE_R),
	.SCCE_F(SCCE_F),
	.SCA(SCA),
	.SCDI(SCDI),
	.SCDO(SCDO),
	.SCRW_N(SCRW_N),
	.SCAS_N(SCAS_N),
	.SCLDS_N(SCLDS_N),
	.SCUDS_N(SCUDS_N),
	.SCDTACK_N(SCDTACK_N),
	.SCFC(SCFC),
	.SCAVEC_N(SCAVEC_N),
	.SCIPL_N(SCIPL_N),
	
	.RAM_A(SCSP_RAM_A),
	.RAM_D(SCSP_RAM_D),
	.RAM_WE(SCSP_RAM_WE),
	.RAM_RD(SCSP_RAM_RD),
	.RAM_CS(SCSP_RAM_CS),
	.RAM_Q(SCSP_RAM_Q),
	.RAM_RDY(SCSP_RAM_RDY),
	
	.SOUND_L(SOUND_L),
	.SOUND_R(SOUND_R)
);

fx68k M68K
(
	.clk(clk_sys),
	.extReset(reset | ~(SCSP_IO_CPURST_N | ioctl_index[0])),
	.pwrUp(reset),
	.enPhi1(SCCE_R),
	.enPhi2(SCCE_F),

	.eab(SCA),
	.iEdb(SCDO),
	.oEdb(SCDI),
	.eRWn(SCRW_N),
	.ASn(SCAS_N),
	.LDSn(SCLDS_N),
	.UDSn(SCUDS_N),
	.DTACKn(SCDTACK_N),

	.IPL0n(SCIPL_N[0]),
	.IPL1n(SCIPL_N[1]),
	.IPL2n(SCIPL_N[2]),

	.VPAn(SCAVEC_N),
	
	.FC0(SCFC[0]),
	.FC1(SCFC[1]),
	.FC2(SCFC[2]),

	.BGn(),
	.BRn(1),
	.BGACKn(1),

	.BERRn(1),
	.HALTn(1)
);


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
	.rd0(SCSP_RAM_RD & SCSP_RAM_CS),
	.wrl0(SCSP_RAM_WE[0] & SCSP_RAM_CS),
	.wrh0(SCSP_RAM_WE[1] & SCSP_RAM_CS),
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

//wire [31:0] ddr_do;
//wire        ddr_busy;
//ddram ddram
//(
//	.*,
//	.clk(clk_ram),
//
//	.mem_addr({9'b000000000,VDP1_VRAM_A[18:1]}),
//	.mem_dout(ddr_do),
//	.mem_din({16'h0000,VDP1_VRAM_D}),
//	.mem_rd(VDP1_VRAM_RD),
//	.mem_wr({2'b00,VDP1_VRAM_WE}),
//	.mem_16b(1),
//	.mem_busy(ddr_busy)
//);
//assign VDP1_VRAM_Q = ddr_do[15:0];
//assign VDP1_VRAM_RDY = ~ddr_busy;


`ifdef DUAL_SDRAM
//wire [31:0] sdr2ch2_do;
//wire sdr2ch2_ardy,sdr2ch2_drdy;
//sdram2 sdram2
//(
//	.SDRAM_CLK(SDRAM2_CLK),
//	.SDRAM_A(SDRAM2_A),
//	.SDRAM_BA(SDRAM2_BA),
//	.SDRAM_DQ(SDRAM2_DQ),
//	.SDRAM_nCS(SDRAM2_nCS),
//	.SDRAM_nWE(SDRAM2_nWE),
//	.SDRAM_nRAS(SDRAM2_nRAS),
//	.SDRAM_nCAS(SDRAM2_nCAS),
//	
//	.init(~locked | reset),
//	.clk(clk_ram),
//	.sync(ce_pix),
//
//	.addr_a0({|RA1_WE,3'b0000,RA0_A}), // 0000000-001FFFF
//	.addr_a1({|RA1_WE,3'b0000,RA1_A}),
//	.din_a(RA0_D),
//	.wr_a(RA0_WE|RA1_WE),
//	.rd_a(RA0_RD|RA1_RD),
//	.dout_a0(RA0_Q),
//	.dout_a1(RA1_Q),
//
//	.addr_b0({|RB1_WE,3'b0000,RB0_A}),
//	.addr_b1({|RB1_WE,3'b0000,RB1_A}),
//	.din_b(RB0_D),
//	.wr_b(RB0_WE|RB1_WE),
//	.rd_b(RB0_RD|RB1_RD),
//	.dout_b0(RB0_Q),
//	.dout_b1(RB1_Q),
//	
//	.ch2addr({3'b000,VDP1_VRAM_A[18:1]}),
//	.ch2din(VDP1_VRAM_D),
//	.ch2wr(VDP1_VRAM_WE),
//	.ch2rd(VDP1_VRAM_RD),
//	.ch2dout(sdr2ch2_do),
//	.ch2ardy(sdr2ch2_ardy),
//	.ch2drdy(sdr2ch2_drdy)
//);
//assign VDP1_VRAM_Q = sdr2ch2_do;
//assign VDP1_VRAM_ARDY = sdr2ch2_ardy;
//assign VDP1_VRAM_DRDY = sdr2ch2_drdy;
`endif

reg [3:0] io_state = 0;
parameter IO_IDLE = 0;
parameter IO_RST = 1;
parameter IO_RAM = 4;
parameter IO_RAM2 = 5;
parameter IO_COMM = 6;
parameter IO_COMM2 = 7;
parameter IO_END = 12;

reg [15:0] SCSP_IO_D;
reg        SCSP_IO_AD_N;
reg        SCSP_IO_DTEN_N;
reg        SCSP_IO_CS_N;
reg        SCSP_IO_WE_N;
reg        SCSP_IO_RST_N;
reg        SCSP_IO_CPURST_N;
	
always @(posedge clk_sys) begin
	reg [1:0] step;
	reg [15:0] ram_addr;
	reg [2:0] data_pos;
	
	case (io_state)
		IO_IDLE: begin
			if (cart_download) begin
				ioctl_wait <= 1;
				SCSP_IO_RST_N <= 0;
				SCSP_IO_CPURST_N <= 0;
				io_state <= IO_RST;
			end else if (comm_set) begin
				ram_addr <= comm_addr;
				data_pos <= '0;
				io_state <= IO_COMM;
			end
			step <= 2'd0;
			SCSP_IO_AD_N <= 1; 
			SCSP_IO_DTEN_N <= 1; 
			SCSP_IO_CS_N <= 1; 
			SCSP_IO_WE_N <= 1;
		end
		
		IO_RST: begin
			step <= step + 2'd1;
			if (step == 2'd3) begin
				SCSP_IO_RST_N <= 1;
				ioctl_wait <= 0;
				io_state <= IO_RAM;
			end
		end
		
		IO_RAM: begin
			if (ioctl_wr) begin
				ioctl_wait <= 1;
				io_state <= IO_RAM2;
			end
		end
		
		IO_RAM2: if (CE_R) begin
			case (step)
				2'd0: begin SCSP_IO_D <= {12'h0000,1'b0,ioctl_addr[18:16]};  SCSP_IO_AD_N <= 1; SCSP_IO_DTEN_N <= 1; SCSP_IO_CS_N <= 0; SCSP_IO_WE_N <= 0; step <= 2'd1; end
				2'd1: begin SCSP_IO_D <= {ioctl_addr[15:1],1'b0};            SCSP_IO_AD_N <= 1; SCSP_IO_DTEN_N <= 1; SCSP_IO_CS_N <= 0; SCSP_IO_WE_N <= 0; step <= 2'd2; end
				2'd2: begin SCSP_IO_D <= {ioctl_data[7:0],ioctl_data[15:8]}; SCSP_IO_AD_N <= 0; SCSP_IO_DTEN_N <= 0; SCSP_IO_CS_N <= 0; SCSP_IO_WE_N <= 0; step <= 2'd3; end
				2'd3: if (!SCSP_IO_RDY_N) begin SCSP_IO_D <= 16'h0000;       SCSP_IO_AD_N <= 1; SCSP_IO_DTEN_N <= 1; SCSP_IO_CS_N <= 1; SCSP_IO_WE_N <= 1; step <= 2'd0; end
			endcase
			if (step == 2'd3 && !SCSP_IO_RDY_N) begin
				ioctl_wait <= 0;
				if (ioctl_addr[19:1] == 19'h3FFFF) io_state <= IO_END;
				else io_state <= IO_RAM;
			end
		end
		
		IO_COMM: begin
			io_state <= IO_COMM2;
		end
		
		IO_COMM2: if (CE_R) begin
			case (step)
				2'd0: begin SCSP_IO_D <= 16'h0000;                     SCSP_IO_AD_N <= 1; SCSP_IO_DTEN_N <= 1; SCSP_IO_CS_N <= 0; SCSP_IO_WE_N <= 0; step <= 2'd1; end
				2'd1: begin SCSP_IO_D <= ram_addr;                     SCSP_IO_AD_N <= 1; SCSP_IO_DTEN_N <= 1; SCSP_IO_CS_N <= 0; SCSP_IO_WE_N <= 0; step <= 2'd2; end
				2'd2: begin SCSP_IO_D <= comm_data[data_pos];          SCSP_IO_AD_N <= 0; SCSP_IO_DTEN_N <= 0; SCSP_IO_CS_N <= 0; SCSP_IO_WE_N <= 0; step <= 2'd3; end
				2'd3: if (!SCSP_IO_RDY_N) begin SCSP_IO_D <= 16'h0000; SCSP_IO_AD_N <= 1; SCSP_IO_DTEN_N <= 1; SCSP_IO_CS_N <= 1; SCSP_IO_WE_N <= 1; step <= 2'd0; end
			endcase
			if (step == 2'd3 && !SCSP_IO_RDY_N) begin
				ram_addr <= ram_addr + 16'd2;
				data_pos <= data_pos + 3'd1;
				if (data_pos == 3'd7) io_state <= IO_END;
				else io_state <= IO_COMM;
			end
		end
		
		IO_END: begin
			if (!cart_download) begin
				io_state <= IO_IDLE;
				SCSP_IO_CPURST_N <= 1;
			end
		end
	endcase
end


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


reg [7:0] r=0, g=0, b=0;
reg vs=0,hs=0;
reg hblank=0, vblank=0;


assign VGA_F1 = 0;
assign {AUDIO_L,AUDIO_R} = {SOUND_L,SOUND_R};

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

wire ce_pix = 0;
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
reg [15:0] comm_data[8];
reg [15:0] comm_addr;
reg comm_set = 0;

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state = 0;
	reg [3:0] comm_n = 4'd0;
	reg start = 0;
	
	start <= 0;
			
	old_state <= ps2_key[10];
	if((ps2_key[10] != old_state) && pressed) begin
		casex(code)
			'h005: begin comm_n <= 2'd0; start <= 1; end 	// F1
			'h006: begin comm_n <= 2'd1; start <= 1;  end 	// F2
			'h004: begin  end 	// F3
			'h00C: begin  end 	// F4
			'h003: begin  end 	// F5
			'h00B: begin  end 	// F6
			'h083: begin  end 	// F7
			'h00A: begin  end 	// F8
			'h001: begin  end 	// F9
			'h009: begin  end 	// F10
			'h078: begin  end 	// F11
			'h177: begin  end 	// Pause
			'h016: begin  end 	// 1
			'h01E: begin  end 	// 2
			'h026: begin  end 	// 3
			'h025: begin  end 	// 4
			'h075: begin  end 	// Up
			'h06B: begin  end 	// Left
			'h072: begin  end 	// Down
			'h074: begin  end 	// Right
		endcase
	end
	
	comm_set <= 0;
	if (start) begin
		case (comm_n)
			4'd0:    begin comm_addr <= 16'h0700; comm_data <= '{16'h8500,16'h0000,16'h5000,16'h8000,16'h7942,16'h0700,16'h0000,16'h0000}; end
			4'd1:    begin comm_addr <= 16'h0760; comm_data <= '{16'h0100,16'h0300,16'h030F,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000}; end
			default: begin comm_addr <= 16'h0700; comm_data <= '{16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000,16'h0000}; end
		endcase
		comm_set <= 1;
	end
end

endmodule
