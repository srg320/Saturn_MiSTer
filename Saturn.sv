//============================================================================
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
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

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

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
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

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
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
	assign BUTTONS   = {1'b0,osd_btn};
	assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
	assign USER_OUT = '0;

	always_comb begin
		if (status[10]) begin
			VIDEO_ARX = 8'd16;
			VIDEO_ARY = 8'd9;
		end else begin
			casez(res)
				4'b00?0: begin // 320 x 224
					VIDEO_ARX = status[30] ? 8'd10: 8'd64;
					VIDEO_ARY = status[30] ? 8'd7 : 8'd49;
				end
	
				4'b00?1: begin // 352 x 224
					VIDEO_ARX = status[30] ? 8'd22: 8'd64;
					VIDEO_ARY = status[30] ? 8'd14: 8'd49;
				end
	
				4'b01?0: begin // 320 x 240
					VIDEO_ARX = status[30] ? 8'd4 : 8'd128;
					VIDEO_ARY = status[30] ? 8'd3 : 8'd105;
				end
	
				4'b01?1: begin // 352 x 240
					VIDEO_ARX = status[30] ? 8'd22: 8'd128;
					VIDEO_ARY = status[30] ? 8'd15: 8'd105;
				end
	
				4'b10?0: begin // 320 x 256
					VIDEO_ARX = status[30] ? 8'd5 : 8'd64;
					VIDEO_ARY = status[30] ? 8'd4 : 8'd49;
				end
	
				4'b10?1: begin // 352 x 256
					VIDEO_ARX = status[30] ? 8'd11: 8'd128;
					VIDEO_ARY = status[30] ? 8'd8 : 8'd105;
				end
	
				default: begin // not supported
					VIDEO_ARX = status[30] ? 8'd10: 8'd64;
					VIDEO_ARY = status[30] ? 8'd7 : 8'd49;
				end
			endcase
		end
	end
	
	assign AUDIO_S = 1;
	assign AUDIO_MIX = 0;
	assign HDMI_FREEZE = 0;
	
	assign LED_DISK  = 0;
	assign LED_POWER = 0;
	assign LED_USER  = bios_download;
	assign VGA_SCALER= 0;


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
		"S0,CUE,Insert Disk;",
		"FS,BIN;",
		"-;",
		"oG,Time set,No,Yes;",
		"oHJ,Region,Japan,Taiwan,USA,Brazil,Korea,Asia,Europe;",
		"-;",
		"P1,Audio & Video;",
		"P1-;",
		"P1OA,Aspect Ratio,4:3,16:9;",
		"P1OU,320x224 Aspect,Original,Corrected;",
		"P1O13,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
		"P1-;",
		"P1OT,Border,No,Yes;",
		"P1oEF,Composite Blend,Off,On,Adaptive;",
//		"P1-;",
//		"P1OEF,Audio Filter,Model 1,Model 2,Minimal,No Filter;",
//		"P1OB,FM Chip,YM2612,YM3438;",
//		"P1ON,HiFi PCM,No,Yes;",
	
//		"P2,Input;",
//		"P2-;",
//		"P2O4,Swap Joysticks,No,Yes;",
//		"P2O5,6 Buttons Mode,No,Yes;",
//		"P2o57,Multitap,Disabled,4-Way,TeamPlayer: Port1,TeamPlayer: Port2,J-Cart;",
//		"P2-;",
//		"P2OIJ,Mouse,None,Port1,Port2;",
//		"P2OK,Mouse Flip Y,No,Yes;",
//		"P2-;",
//		"P2oD,Serial,OFF,SNAC;",
//		"P2-;",
//		"P2o89,Gun Control,Disabled,Joy1,Joy2,Mouse;",
//		"D4P2oA,Gun Fire,Joy,Mouse;",
//		"D4P2oBC,Cross,Small,Medium,Big,None;",
	
		"-;",
		"R0,Reset;",
		"J1,A,B,C,Start,R,X,Y,Z,L;",
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
	
	reg  [31:0] sd_lba = '0;
	reg         sd_rd = 0;
	reg         sd_wr = 0;
	wire        sd_ack;
	wire  [7:0] sd_buff_addr;
	wire [15:0] sd_buff_dout;
	wire [15:0] sd_buff_din = '0;
	wire        sd_buff_wr;
	wire        img_mounted;
	wire        img_readonly;
	wire [63:0] img_size;
	
	wire        forced_scandoubler;
	wire [10:0] ps2_key;
	wire [24:0] ps2_mouse;
	
	wire [35:0] EXT_BUS;
	
	wire [21:0] gamma_bus;
	wire [15:0] sdram_sz;
	
	hps_io #(.CONF_STR(CONF_STR), .WIDE(1)) hps_io
	(
		.clk_sys(clk_sys),
		.HPS_BUS(HPS_BUS),
	
		.joystick_0(joystick_0),
		.joystick_1(joystick_1),
		.joystick_2(joystick_2),
		.joystick_3(joystick_3),
		.joystick_4(joystick_4),
		.joystick_l_analog_0({joy0_y, joy0_x}),
		.joystick_l_analog_1({joy1_y, joy1_x}),
	
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
	
		.sd_lba('{sd_lba}),
		.sd_rd(sd_rd),
		.sd_wr(sd_wr),
		.sd_ack(sd_ack),
		.sd_buff_addr(sd_buff_addr),
		.sd_buff_dout(sd_buff_dout),
		.sd_buff_din('{sd_buff_din}),
		.sd_buff_wr(sd_buff_wr),
		.img_mounted(img_mounted),
		.img_readonly(img_readonly),
		.img_size(img_size),
	
		.gamma_bus(gamma_bus),
		.sdram_sz(sdram_sz),
	
		.ps2_key(ps2_key),
		.ps2_mouse(ps2_mouse),
	
		.EXT_BUS(EXT_BUS)
	
	);
	
	reg  [1:0] region_req = '0;
	reg        region_set = 0;
	
	wire [96:0] cd_in;
	wire [96:0] cd_out;
	hps_ext hps_ext
	(
		.clk_sys(clk_sys),
		.EXT_BUS(EXT_BUS),
		.cd_in(cd_in),
		.cd_out(cd_out)
	);
	
	wire bios_download = ioctl_download & (ioctl_index[5:2] == 4'b0000);
	wire cdd_download = ioctl_download & (ioctl_index[5:2] == 4'b0001);//[0]:0=speed 1x,1=speed 2x; [1]:0=data,1=cdda;
	
	reg osd_btn = 0;
//	always @(posedge clk_sys) begin
//		integer timeout = 0;
//		reg     has_bootrom = 0;
//		reg     last_rst = 0;
//	
//		if (RESET) last_rst = 0;
//		if (status[0]) last_rst = 1;
//	
//		if (bios_download & ioctl_wr & status[0]) has_bootrom <= 1;
//	
//		if(last_rst & ~status[0]) begin
//			osd_btn <= 0;
//			if(timeout < 24000000) begin
//				timeout <= timeout + 1;
//				osd_btn <= ~has_bootrom;
//			end
//		end
//	end

	///////////////////////////////////////////////////
	wire clk_sys, clk_ram, locked;
	pll pll
	(
		.refclk(CLK_50M),
		.rst(0),
		.outclk_0(clk_sys),
		.outclk_1(clk_ram),
		.reconfig_to_pll(reconfig_to_pll),
		.reconfig_from_pll(reconfig_from_pll), 
		.locked(locked)
	);
	
	wire [63:0] reconfig_to_pll;
	wire [63:0] reconfig_from_pll;
	wire        cfg_waitrequest;
	reg         cfg_write;
	reg   [5:0] cfg_address;
	reg  [31:0] cfg_data;
	
	pll_cfg pll_cfg
	(
		.mgmt_clk(CLK_50M),
		.mgmt_reset(0),
		.mgmt_waitrequest(cfg_waitrequest),
		.mgmt_read(0),
		.mgmt_readdata(),
		.mgmt_write(cfg_write),
		.mgmt_address(cfg_address),
		.mgmt_writedata(cfg_data),
		.reconfig_to_pll(reconfig_to_pll),
		.reconfig_from_pll(reconfig_from_pll)
	);

	always @(posedge CLK_50M) begin
//		reg pald = 0, pald2 = 0;
		reg hres = 0, hres2 = 0;
		reg [2:0] state = 0;

//		pald  <= PAL;
//		pald2 <= pald;
		
		hres  <= HRES[0];
		hres2 <= hres;
	
		cfg_write <= 0;
		if (hres2 != hres) state <= 1;
	
		if (!cfg_waitrequest) begin
			if (state) state <= state + 1'd1;
			case (state)
				1: begin
						cfg_address <= 0;
						cfg_data <= 0;
						cfg_write <= 1;
					end
				3: begin
						cfg_address <= 4;
						cfg_data <= !hres2 ? 32'h00000404 : 32'h00020504;
						cfg_write <= 1;
					end
				5: begin
						cfg_address <= 7;
						cfg_data <= !hres2 ? 2532450157 : 702807747;
						cfg_write <= 1;
					end
				7: begin
						cfg_address <= 2;
						cfg_data <= 0;
						cfg_write <= 1;
					end
			endcase
		end
	end 
	
	
	wire reset = RESET | status[0] | buttons[1] | bios_download;
	
	wire  [3:0] area_code = status[51:49] == 3'd0 ? 4'h1 :	//Japan area
									status[51:49] == 3'd1 ? 4'h2 :	//Asia NTSC area
									status[51:49] == 3'd2 ? 4'h4 :	//North America area
									status[51:49] == 3'd3 ? 4'h5 :	//Central/S. America NTSC area
									status[51:49] == 3'd4 ? 4'h6 :	//Korea area
									status[51:49] == 3'd5 ? 4'hA :	//Asia PAL area
									status[51:49] == 3'd6 ? 4'hC :	//Europe PAL area
																	4'h3;		//Reserved
	wire [15:0] joy1 = {~joystick_0[0],~joystick_0[1],~joystick_0[2],~joystick_0[3],~joystick_0[7],~joystick_0[4],~joystick_0[6],~joystick_0[5],
							  ~joystick_0[8],~joystick_0[9],~joystick_0[10],~joystick_0[11],~joystick_0[12],3'b111};
	wire [15:0] joy2 = {~joystick_1[0],~joystick_1[1],~joystick_1[2],~joystick_1[3],~joystick_1[7],~joystick_1[4],~joystick_1[6],~joystick_1[5],
							  ~joystick_1[8],~joystick_1[9],~joystick_1[10],~joystick_1[11],~joystick_1[12],3'b111};
	
	wire [24:0] MEM_A;
	wire [31:0] MEM_DI;
	wire [31:0] MEM_DO;
	wire        ROM_CS_N;
	wire        SRAM_CS_N;
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
	wire        VDP1_VRAM_RDY;
	wire [17:1] VDP1_FB0_A;
	wire [15:0] VDP1_FB0_D;
	wire [15:0] VDP1_FB0_Q;
	wire  [1:0] VDP1_FB0_WE;
	wire        VDP1_FB0_RD;
	wire [17:1] VDP1_FB1_A;
	wire [15:0] VDP1_FB1_D;
	wire [15:0] VDP1_FB1_Q;
	wire  [1:0] VDP1_FB1_WE;
	wire        VDP1_FB1_RD;
	
	wire [17:1] VDP2_RA0_A;
	wire [16:1] VDP2_RA1_A;
	wire [63:0] VDP2_RA_D;
	wire  [7:0] VDP2_RA_WE;
	wire        VDP2_RA_RD;
	wire [31:0] VDP2_RA0_Q;
	wire [31:0] VDP2_RA1_Q;
	wire [17:1] VDP2_RB0_A;
	wire [16:1] VDP2_RB1_A;
	wire [63:0] VDP2_RB_D;
	wire  [7:0] VDP2_RB_WE;
	wire        VDP2_RB_RD;
	wire [31:0] VDP2_RB0_Q;
	wire [31:0] VDP2_RB1_Q;
	
	wire [18:1] SCSP_RAM_A;
	wire [15:0] SCSP_RAM_D;
	wire  [1:0] SCSP_RAM_WE;
	wire        SCSP_RAM_RD;
	wire        SCSP_RAM_CS;
	wire [15:0] SCSP_RAM_Q;
	wire        SCSP_RAM_RFS;
	wire        SCSP_RAM_RDY;
	
	reg         CD_CDATA = 0;
	wire        CD_HDATA;
	wire        CD_COMCLK;
	reg         CD_COMREQ_N = 1;
	reg         CD_COMSYNC_N = 1;
	
	wire [18:1] CD_RAM_A;
	wire [15:0] CD_RAM_D;
	wire  [1:0] CD_RAM_WE;
	wire        CD_RAM_RD;
	wire        CD_RAM_CS;
	wire [15:0] CD_RAM_Q;
	wire        CD_RAM_RDY;
	
	wire  [7:0] R, G, B;
	wire        HS_N,VS_N;
	wire        DCLK;
	wire        HBL_N, VBL_N;
	wire        FIELD;
	wire        INTERLACE;
	wire  [1:0] HRES;
	wire  [1:0] VRES;
	wire        DCE_R;

	wire [31:0] in_clk = !HRES[0] ? 53685200 : 57272720;
	wire SCSP_CE;		//SCSP clock 22.5792MHz
	CEGen SCSP_CEGen
	(
		.CLK(clk_sys),
		.RST_N(1/*RST_N*/),
		.IN_CLK(in_clk),
		.OUT_CLK(22579200),
		.CE(SCSP_CE)
	);
	
	wire CD_CE;			//CD clock freq 20.000MHz
	CEGen CD_CEGen
	(
		.CLK(clk_sys),
		.RST_N(1/*RST_N*/),
		.IN_CLK(in_clk),
		.OUT_CLK(20000000*2),
		.CE(CD_CE)
	);
	
	wire CDD_2X_CE;	//CD data clock 44.1kHz x 2(channel) x 2(speed)
	CEGen CDD_CEGen
	(
		.CLK(clk_sys),
		.RST_N(1/*RST_N*/),
		.IN_CLK(in_clk),
		.OUT_CLK(44100*2*2),
		.CE(CDD_2X_CE)
	);
	
	Saturn saturn
	(
		.RST_N(~reset),
		.CLK(clk_sys),
		.CE(1),
		.EN(1),
		
		.SRES_N(~status[0]),
		
		.TIME_SET(~status[48]),
		.AREA(area_code),
		
		.MEM_A(MEM_A),
		.MEM_DI(MEM_DI),
		.MEM_DO(MEM_DO),
		.MEM_DQM_N(MEM_DQM_N),
		.ROM_CS_N(ROM_CS_N),
		.SRAM_CS_N(SRAM_CS_N),
		.RAML_CS_N(RAML_CS_N),
		.RAMH_CS_N(RAMH_CS_N),
		.MEM_RD_N(MEM_RD_N),
		.MEM_WAIT_N(MEM_WAIT_N),
		
		.VDP1_VRAM_A(VDP1_VRAM_A),
		.VDP1_VRAM_D(VDP1_VRAM_D),
		.VDP1_VRAM_WE(VDP1_VRAM_WE),
		.VDP1_VRAM_RD(VDP1_VRAM_RD),
		.VDP1_VRAM_Q(VDP1_VRAM_Q),
		.VDP1_VRAM_RDY(VDP1_VRAM_RDY),
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
		.VDP1_FB_RDY(1),
			
		.VDP2_RA0_A(VDP2_RA0_A),
		.VDP2_RA1_A(VDP2_RA1_A),
		.VDP2_RA_D(VDP2_RA_D),
		.VDP2_RA_WE(VDP2_RA_WE),
		.VDP2_RA_RD(VDP2_RA_RD),
		.VDP2_RA0_Q(VDP2_RA0_Q),
		.VDP2_RA1_Q(VDP2_RA1_Q),
		.VDP2_RB0_A(VDP2_RB0_A),
		.VDP2_RB1_A(VDP2_RB1_A),
		.VDP2_RB_D(VDP2_RB_D),
		.VDP2_RB_WE(VDP2_RB_WE),
		.VDP2_RB_RD(VDP2_RB_RD),
		.VDP2_RB0_Q(VDP2_RB0_Q),
		.VDP2_RB1_Q(VDP2_RB1_Q),
		
		.SCSP_CE(SCSP_CE),
		.SCSP_RAM_A(SCSP_RAM_A),
		.SCSP_RAM_D(SCSP_RAM_D),
		.SCSP_RAM_WE(SCSP_RAM_WE),
		.SCSP_RAM_RD(SCSP_RAM_RD),
		.SCSP_RAM_CS(SCSP_RAM_CS),
		.SCSP_RAM_Q(SCSP_RAM_Q),
		.SCSP_RAM_RFS(SCSP_RAM_RFS),
		.SCSP_RAM_RDY(SCSP_RAM_RDY),
		
		.CD_CE(CD_CE),
		.CDD_CE(CDD_2X_CE),
		.CD_CDATA(CD_CDATA),
		.CD_HDATA(CD_HDATA),
		.CD_COMCLK(CD_COMCLK),
		.CD_COMREQ_N(CD_COMREQ_N),
		.CD_COMSYNC_N(CD_COMSYNC_N),
		.CD_D(cdc_d),
		.CD_CK(cdc_wr),
		.CD_RAM_A(CD_RAM_A),
		.CD_RAM_D(CD_RAM_D),
		.CD_RAM_WE(CD_RAM_WE),
		.CD_RAM_RD(CD_RAM_RD),
		.CD_RAM_CS(CD_RAM_CS),
		.CD_RAM_Q(CD_RAM_Q),
		.CD_RAM_RDY(CD_RAM_RDY),
		
		.R(R),
		.G(G),
		.B(B),
		.DCLK(DCLK),
		.VS_N(VS_N),
		.HS_N(HS_N),
		.HBL_N(HBL_N),
		.VBL_N(VBL_N),
		
		.FIELD(FIELD),
		.INTERLACE(INTERLACE),
		.HRES(HRES), 				//[1]:0-normal,1-hi-res; [0]:0-320p,1-352p
		.VRES(VRES), 				//0-224,1-240,2-256
		.DCE_R(DCE_R),
		
		.SOUND_L(AUDIO_L),
		.SOUND_R(AUDIO_R),
			
		.JOY1(joy1),
		.JOY2(joy2),
		
		.SCRN_EN(SCRN_EN),
		.SND_EN(SND_EN),
		.DBG_PAUSE(DBG_PAUSE),
		.DBG_BREAK(DBG_BREAK),
		.DBG_RUN(DBG_RUN),
		.H320_END_INC(H320_END_INC),
		.H320_END_DEC(H320_END_DEC),
		.H352_END_INC(H352_END_INC),
		.H352_END_DEC(H352_END_DEC)
	);
	
	reg [7:0] HOST_COMM[12];
	reg [7:0] CDD_STAT[12] = '{8'h12,8'h41,8'h01,8'h01,8'h00,8'h02,8'h03,8'h04,8'h00,8'h04,8'h03,8'h9A};
	reg       cdd_trans_start = 0;
	reg [3:0] cdd_trans_wait = '0;
	reg       cd_in96 = 0;
	reg [7:0] cmd06_cnt;
	reg [7:0] cmd09_cnt;
	always @(posedge clk_sys) begin
		reg cd_out96_last = 1;
	
		cdd_trans_start <= 0;
		if (cd_out[96] != cd_out96_last)  begin
			cd_out96_last <= cd_out[96];
			{CDD_STAT[11],CDD_STAT[10],CDD_STAT[9],CDD_STAT[8],CDD_STAT[7],CDD_STAT[6],CDD_STAT[5],CDD_STAT[4],CDD_STAT[3],CDD_STAT[2],CDD_STAT[1],CDD_STAT[0]} <= cd_out[95:0];
//			cdd_trans_start <= 1;
			cdd_trans_wait <= '1;
		end else if (cdd_trans_wait) begin
			cdd_trans_wait <= cdd_trans_wait - 4'd1;
			cdd_trans_start <= (cdd_trans_wait == 4'd1);
		end /*else 
			cdd_trans_start <= 0;*/
		
		if (cdd_comm_rdy) begin
			cd_in[95:0] <= {HOST_COMM[11],HOST_COMM[10],cmd06_cnt/*HOST_COMM[9]*/,cmd09_cnt/*HOST_COMM[8]*/,HOST_COMM[7],HOST_COMM[6],HOST_COMM[5],HOST_COMM[4],HOST_COMM[3],HOST_COMM[2],HOST_COMM[1],HOST_COMM[0]};
			cd_in[96] <= ~cd_in[96];
//			cd_in96 <= ~cd_in96;
			if (HOST_COMM[0] == 8'h06) cmd06_cnt <= cmd06_cnt + 8'd1;
			if (HOST_COMM[0] == 8'h09) cmd09_cnt <= cmd09_cnt + 8'd1;
		end
	
		if (reset) begin
			cmd06_cnt <= 0;
			cmd09_cnt <= 0;
		end
	end
//	assign cd_in = {cd_in96,HOST_COMM[11],HOST_COMM[10],HOST_COMM[9],HOST_COMM[8],HOST_COMM[7],HOST_COMM[6],HOST_COMM[5],HOST_COMM[4],HOST_COMM[3],HOST_COMM[2],HOST_COMM[1],HOST_COMM[0]};
			
	reg [7:0] HOST_DATA = '0;
	reg [7:0] CDD_DATA = '0;
	reg cdd_trans_next = 0;
	reg cdd_trans_done = 0;
	reg cdd_comm_rdy = 0;
	always @(posedge clk_sys) begin
		reg [3:0] byte_cnt = '0;
		reg [2:0] bit_cnt = '0;
		reg COMCLK_OLD = 0;
		reg [10:0] cdd_next_delay = '0;
		
		if (cdd_trans_start) CD_COMREQ_N <= 1;
		if (cdd_trans_next) CD_COMREQ_N <= 0;
		
		COMCLK_OLD <= CD_COMCLK;
		cdd_trans_done <= 0;
		if (reset) begin
			cdd_trans_done <= 0;
			bit_cnt <= '0;
		end else if (cdd_trans_start) begin
			cdd_trans_done <= 0;
			bit_cnt <= '0;
		end else if (!CD_COMCLK && COMCLK_OLD) begin
			{CDD_DATA,CD_CDATA} <= {1'b0,CDD_DATA};
		end else if (CD_COMCLK && !COMCLK_OLD) begin
			HOST_DATA <= {CD_HDATA,HOST_DATA[7:1]};
			CD_COMREQ_N <= 1;
			bit_cnt <= bit_cnt + 3'd1;
			if (bit_cnt == 3'd7) begin
				cdd_trans_done <= 1;
			end
		end
		
		cdd_trans_next <= 0;
		cdd_comm_rdy <= 0;
		if (reset) begin
			cdd_trans_next <= 0;
			cdd_comm_rdy <= 0;
			byte_cnt <= '0;
		end else if (cdd_trans_start) begin
			CDD_DATA <= CDD_STAT[0];
			CD_COMSYNC_N <= 0;
			byte_cnt <= 4'd0;
			cdd_next_delay <= 11'h3FF;
		end else if (cdd_trans_done) begin
			HOST_COMM[byte_cnt] <= HOST_DATA;
			CD_COMSYNC_N <= 1;
			byte_cnt <= byte_cnt + 4'd1;
			if (byte_cnt < 4'd11) begin
				CDD_DATA <= CDD_STAT[byte_cnt + 4'd1];
				cdd_next_delay <= 11'h3FF;
			end else if (byte_cnt == 4'd11) begin
				CDD_DATA <= 8'h00;
				cdd_next_delay <= 11'h3FF;
				cdd_comm_rdy <= 1;
			end
		end
		
		if (cdd_next_delay) begin
			cdd_next_delay <= cdd_next_delay - 11'h001;
			cdd_trans_next <= (cdd_next_delay == 11'h001);
		end
	end
	
	
	reg [17:0] cdc_d;
	reg        cdc_wr;
	reg        cdc_speed;
	reg        cdc_audio;
	always @(posedge clk_sys) begin
		reg [1:0] cnt = 0;
		reg [1:0] state = 0;
	
		case (state)
			0: if (cdd_download && ioctl_wr) begin
				{cdc_audio,cdc_speed} <= ioctl_data[1:0];
				state <= 1;
			end
			
			1: if (!cdd_download) begin
				state <= 0;
			end else if (cdd_download && ioctl_wr) begin
				cnt <= 0;
				cdc_wr <= 1;
				cdc_d[17:0] <= {cdc_audio,cdc_speed,ioctl_data[7:0],ioctl_data[15:8]};
				state <= 2;
			end
			
			2: begin
				cnt <= cnt - 1'd1;
				if (!cnt) begin
					cdc_wr <= 0;
					state <= 1;
				end
			end
		endcase
	end

	//SDRAM1
	sdram1 sdram1
	(
		.SDRAM_CLK(SDRAM_CLK),
		.SDRAM_A(SDRAM_A),
		.SDRAM_BA(SDRAM_BA),
		.SDRAM_DQ(SDRAM_DQ),
		.SDRAM_DQML(SDRAM_DQML),
		.SDRAM_DQMH(SDRAM_DQMH),
		.SDRAM_nCS(SDRAM_nCS),
		.SDRAM_nWE(SDRAM_nWE),
		.SDRAM_nRAS(SDRAM_nRAS),
		.SDRAM_nCAS(SDRAM_nCAS),
		.SDRAM_CKE(SDRAM_CKE),
		
		.clk(clk_ram),
		.init(reset),
		.sync(DCE_R),
	
		.addr_a0({VDP2_RA0_A[17],3'b0000,VDP2_RA0_A[16:1]}),
		.addr_a1({               3'b0000,VDP2_RA1_A[16:1]}),
		.din_a(VDP2_RA_D),
		.wr_a(VDP2_RA_WE),
		.rd_a(VDP2_RA_RD),
		.dout_a0(VDP2_RA0_Q),
		.dout_a1(VDP2_RA1_Q),
	
		.addr_b0({VDP2_RB0_A[17],3'b0000,VDP2_RB0_A[16:1]}),
		.addr_b1({               3'b0000,VDP2_RB1_A[16:1]}),
		.din_b(VDP2_RA_D),///////////////
		.wr_b(VDP2_RB_WE),
		.rd_b(VDP2_RB_RD),
		.dout_b0(VDP2_RB0_Q),
		.dout_b1(VDP2_RB1_Q),
		
		.ch2addr({3'b000,SCSP_RAM_A}),
		.ch2din(SCSP_RAM_D),
		.ch2wr(SCSP_RAM_WE & {2{SCSP_RAM_CS}}),
		.ch2rd(SCSP_RAM_RD & SCSP_RAM_CS),
		.ch2dout(SCSP_RAM_Q),
		.ch2rdy(SCSP_RAM_RDY)
	);

	//DDRAM
	always @(posedge clk_sys) begin
		reg old_busy;
		
		old_busy <= ddr_busy[6];
		if (bios_download && ioctl_addr[24:4] && !ioctl_addr[3:1] && ioctl_wr) ioctl_wait <= 1;
		if (~ddr_busy[6] && old_busy) ioctl_wait <= 0;
	end

	parameter bit [7:0] SRAM_INIT[16] = '{8'h42,8'h61,8'h63,8'h6B,8'h55,8'h70,8'h52,8'h61,8'h6D,8'h20,8'h46,8'h6F,8'h72,8'h6D,8'h61,8'h74};
	wire [7:0] SRAM_INIT_DATA = !ioctl_addr[15:7] ? SRAM_INIT[ioctl_addr[4:1]] : 8'h00;
	wire       SRAM_INIT_WE = bios_download & ~|ioctl_addr[18:16] & ioctl_wr;
	
	wire [31:0] ddr_do[8];
	wire        ddr_busy[8];
	ddram ddram
	(
		.*,
		.clk(clk_ram),
	
		//VDP1 VRAM
		.mem0_addr({ 9'b000001000,   VDP1_VRAM_A[18:1]}       ),
		.mem0_din ({16'h0000,VDP1_VRAM_D}                     ),
		.mem0_wr  ({2'b00,VDP1_VRAM_WE}                       ),
		.mem0_rd  (VDP1_VRAM_RD                               ),
		.mem0_dout(ddr_do[0]                                  ),
		.mem0_16b (1                                          ),
		.mem0_wcen(1                                          ),
		.mem0_busy(ddr_busy[0]                                ),
	
		//CD RAM
		.mem1_addr({ 9'b000010000,   CD_RAM_A[18:1]}          ),
		.mem1_din ({16'h0000,CD_RAM_D}                        ),
`ifdef MISTER_DUAL_SDRAM
		.mem1_wr  ('0                                         ),
		.mem1_rd  (0                                          ),
`else
		.mem1_wr  ({2'b00,CD_RAM_WE & {2{CD_RAM_CS}}}         ),
		.mem1_rd  (CD_RAM_RD & CD_RAM_CS                      ),
`endif
		.mem1_dout(ddr_do[1]                                  ),
		.mem1_16b (1                                          ),
		.mem1_wcen(1                                          ),
		.mem1_busy(ddr_busy[1]                                ),
	
		//CPU bus (ROM,SRAM)
		.mem2_addr({ 8'b00000000,ROM_CS_N,MEM_A[18:1]}        ),
		.mem2_din (MEM_DO                    ),
		.mem2_wr  ({3'b000,~SRAM_CS_N & ~MEM_DQM_N[0]}        ),
		.mem2_rd  ((~ROM_CS_N | ~SRAM_CS_N) & ~MEM_RD_N       ),
		.mem2_dout(ddr_do[2]                                  ),
		.mem2_16b (1                                          ),
		.mem2_wcen(0                                          ),
		.mem2_busy(ddr_busy[2]                                ),
	
		//CPU bus (RAMH)
		.mem3_addr({ 8'b00000010,    MEM_A[19:2],1'b0}        ),
		.mem3_din (MEM_DO                                     ),
		.mem3_wr  ({4{~RAMH_CS_N}} & ~MEM_DQM_N               ),
		.mem3_rd  (~RAMH_CS_N & ~MEM_RD_N                     ),
		.mem3_dout(ddr_do[3]                                  ),
		.mem3_16b (0                                          ),
		.mem3_wcen(1                                          ),
		.mem3_busy(ddr_busy[3]                                ),
		
		//CPU bus (RAML)
		.mem4_addr({ 8'b00000001,    MEM_A[19:1]}             ),
		.mem4_din (MEM_DO                                     ),
		.mem4_wr  ({4{~RAML_CS_N}} & ~MEM_DQM_N               ),
		.mem4_rd  (~RAML_CS_N & ~MEM_RD_N                     ),
		.mem4_dout(ddr_do[4]                                  ),
		.mem4_16b (1                                          ),
		.mem4_wcen(1                                          ),
		.mem4_busy(ddr_busy[4]                                ),
		
		//
		.mem5_addr('0                                         ),
		.mem5_din ('0                                         ),
		.mem5_wr  ('0                                         ),
		.mem5_rd  (0                                          ),
		.mem5_dout(ddr_do[5]                                  ),
		.mem5_16b (1                                          ),
		.mem5_wcen(0                                          ),
		.mem5_busy(ddr_busy[5]                                ),
		
		//BIOS ROM
		.mem6_addr({ 9'b000000000,ioctl_addr[18:1]}           ),
		.mem6_din ({16'h0000,ioctl_data[7:0],ioctl_data[15:8]}),
		.mem6_wr  ({2'b00,{2{bios_download & ioctl_wr}}}      ),
		.mem6_rd  (0                                          ),
		.mem6_dout(ddr_do[6]                                  ),
		.mem6_16b (1                                          ),
		.mem6_wcen(0                                          ),
		.mem6_busy(ddr_busy[6]                                ),
		
		//SRAM backup
		.mem7_addr({12'b000000001000,ioctl_addr[15:1]}        ),
		.mem7_din ({24'h000000,SRAM_INIT_DATA}                ),
		.mem7_wr  ({3'b000,SRAM_INIT_WE}                      ),
		.mem7_rd  (0                                          ),
		.mem7_dout(ddr_do[7]                                  ),
		.mem7_16b (1                                          ),
		.mem7_wcen(0                                          ),
		.mem7_busy(ddr_busy[7]                                )
	);
	assign VDP1_VRAM_Q = {2{ddr_do[0][15:0]}};
	assign VDP1_VRAM_RDY = ~ddr_busy[0];
	assign MEM_DI     = !ROM_CS_N  ? ddr_do[2] :
							  !SRAM_CS_N ? ddr_do[2] :
							  !RAML_CS_N ? ddr_do[4] :
												ddr_do[3];
	assign MEM_WAIT_N = ~(ddr_busy[2] | ddr_busy[3] | ddr_busy[4]);

`ifndef MISTER_DUAL_SDRAM
	assign CD_RAM_Q = ddr_do[1][15:0];
	assign CD_RAM_RDY = ~ddr_busy[1];
`endif


`ifdef MISTER_DUAL_SDRAM
	//SDRAM2
	wire sdr2_busy0, sdr2_busy1, sdr2_busy2;
	wire [15:0] sdr2_do0,sdr2_do1,sdr2_do2;
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
		
		.init(reset),
		.clk(clk_ram),

		.rfs(0/*SCSP_RAM_RFS*/),
		
		.addr0({6'b000001,SCSP_RAM_A[18:1]}),
		.din0(SCSP_RAM_D),
		.dout0(sdr2_do0),
		.rd0(0/*SCSP_RAM_RD & SCSP_RAM_CS*/),
		.wrl0(0/*SCSP_RAM_WE[0] & SCSP_RAM_CS*/),
		.wrh0(0/*SCSP_RAM_WE[1] & SCSP_RAM_CS*/),
		.busy0(sdr2_busy0),

		.addr1({6'b000000,CD_RAM_A[18:1]}),
		.din1(CD_RAM_D),
		.dout1(sdr2_do1),
		.rd1(CD_RAM_RD & CD_RAM_CS),
		.wrl1(CD_RAM_WE[0] & CD_RAM_CS),
		.wrh1(CD_RAM_WE[1] & CD_RAM_CS),
		.busy1(sdr2_busy1),

		.addr2({6'b000010,VDP1_VRAM_A[18:1]}),
		.din2(VDP1_VRAM_D),
		.dout2(sdr2_do2),
		.rd2(0/*VDP1_VRAM_RD*/),
		.wrl2(0/*VDP1_VRAM_WE[0]*/),
		.wrh2(0/*VDP1_VRAM_WE[1]*/),
		.busy2(sdr2_busy2)
	);
//	assign SCSP_RAM_Q = sdr2_do0;
//	assign SCSP_RAM_RDY = ~sdr2_busy0;
	assign CD_RAM_Q = sdr2_do1;
	assign CD_RAM_RDY = ~sdr2_busy1;
`endif


	//VDP1 FB
	vdp1_fb_352x512x16 vdp1_fb0
	(
		.clock(clk_sys),
		.address({VDP1_FB0_A[9:1],VDP1_FB0_A[17:10]}),
		.data(VDP1_FB0_D),
		.wren(VDP1_FB0_WE),
		.q(VDP1_FB0_Q)
	);

	vdp1_fb_352x512x16 vdp1_fb1
	(
		.clock(clk_sys),
		.address({VDP1_FB1_A[9:1],VDP1_FB1_A[17:10]}),
		.data(VDP1_FB1_D),
		.wren(VDP1_FB1_WE),
		.q(VDP1_FB1_Q)
	);


	wire PAL = (area_code >= 4'hA);//status[7];
	
	reg new_vmode;
	always @(posedge clk_sys) begin
		reg old_pal;
		int to;
		
		if(!reset) begin
			old_pal <= PAL;
			if(old_pal != PAL) to <= 5000000;
		end
		else to <= 5000000;
		
		if(to) begin
			to <= to - 1;
			if(to == 1) new_vmode <= ~new_vmode;
		end
	end
	
	assign VGA_F1 = FIELD;
	
	//lock resolution for the whole frame.
	reg [3:0] res = 4'b0000;
	always @(posedge clk_sys) begin
		reg old_vbl;
		
		old_vbl <= VBL_N;
		if(old_vbl & ~VBL_N) res <= {VRES,HRES};
	end
	
	
	wire [2:0] scale = status[3:1];
	wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
	
	assign CLK_VIDEO = clk_ram;
	assign VGA_SL = {~INTERLACE,~INTERLACE} & sl[1:0];
	
//	reg [7:0] RS,GS,BS;
	reg DCLK_OLD;
	always @(posedge CLK_VIDEO) begin
//		{RS,GS,BS} <= {R,G,B};
		DCLK_OLD <= DCLK;
	end
	wire ce_pix = DCLK & ~DCLK_OLD;
	
	video_mixer #(.LINE_LENGTH((352*2)+8), .HALF_DEPTH(0), .GAMMA(1)) video_mixer
	(
		.*,
	
		.ce_pix(ce_pix),	
		.scandoubler(~INTERLACE && (scale || forced_scandoubler)),
		.hq2x(scale==1),	
		.freeze_sync(),
	
		.R(R),
		.G(G),
		.B(B),
	
		// Positive pulses.
		.HSync(~HS_N),
		.VSync(~VS_N),
		.HBlank(~HBL_N),
		.VBlank(~VBL_N)
	);


	//debug
	reg  [6:0] SCRN_EN = 7'b1111111;
	reg  [2:0] SND_EN = 3'b111;
	reg        DBG_PAUSE = 0;
	reg        DBG_BREAK = 0;
	reg        DBG_RUN = 0;
	
	reg        H320_END_INC = 0;
	reg        H320_END_DEC = 0;
	reg        H352_END_INC = 0;
	reg        H352_END_DEC = 0;
	
	wire       pressed = ps2_key[9];
	wire [8:0] code    = ps2_key[8:0];
	always @(posedge clk_sys) begin
		reg old_state = 0;
	
		DBG_RUN <= 0;
		H320_END_INC <= 0;
		H320_END_DEC <= 0;
		H352_END_INC <= 0;
		H352_END_DEC <= 0;
		
		old_state <= ps2_key[10];
		if((ps2_key[10] != old_state) && pressed) begin
			casex(code)
				'h005: begin SCRN_EN[0] <= ~SCRN_EN[0]; end 	// F1
				'h006: begin SCRN_EN[1] <= ~SCRN_EN[1]; end 	// F2
				'h004: begin SCRN_EN[2] <= ~SCRN_EN[2]; end 	// F3
				'h00C: begin SCRN_EN[3] <= ~SCRN_EN[3]; end 	// F4
				'h003: begin SCRN_EN[4] <= ~SCRN_EN[4]; end 	// F5
				'h00B: begin SCRN_EN[5] <= ~SCRN_EN[5]; end 	// F6
				'h083: begin SCRN_EN[6] <= ~SCRN_EN[6]; end 	// F7
				'h00A: begin SND_EN[0] <= ~SND_EN[0]; end 	// F8
				'h001: begin SND_EN[1] <= ~SND_EN[1]; end 	// F9
				'h009: begin SND_EN[2] <= ~SND_EN[2]; end 	// F10
				'h078: begin SCRN_EN <= '1; SND_EN <= '1; end 	// F11
`ifdef DEBUG
//				'h009: begin DBG_BREAK <= ~DBG_BREAK; end 	// F10
//				'h078: begin DBG_RUN <= 1; end 	// F11
				'h177: begin DBG_PAUSE <= ~DBG_PAUSE; end 	// Pause
				'h016: begin H320_END_DEC <= 1; end 	// 1
				'h01E: begin H320_END_INC <= 1; end 	// 2
				'h026: begin H352_END_DEC <= 1; end 	// 3
				'h025: begin H352_END_INC <= 1; end 	// 4
`endif
			endcase
		end
	end

endmodule
