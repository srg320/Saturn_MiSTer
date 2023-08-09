module HPS2CDD (
	input              CLK,
	input              RST_N,
	
	inout      [35: 0] EXT_BUS,
	
	input              CDD_CE,
	output reg         CD_CDATA,
	input              CD_HDATA,
	input              CD_COMCLK,
	output reg         CD_COMREQ_N,
	output reg         CD_COMSYNC_N,
		
	input              CDD_ACT,
	input              CDD_WR,
	input      [15: 0] CDD_DI,
		
	output     [13: 1] CD_BUF_ADDR,
	input      [15: 0] CD_BUF_DI,
	output reg         CD_BUF_RD,
	input              CD_BUF_RDY,
	
	output reg [17: 0] CD_DATA,
	output reg         CD_CK,
	output reg         CD_AUDIO
);

	bit [96: 0] cd_in;
	bit [96: 0] cd_out;
	hps_ext hps_ext
	(
		.clk_sys(CLK),
		.EXT_BUS(EXT_BUS),
		.cd_in(cd_in),
		.cd_out(cd_out)
	);
	
	bit [ 7: 0] HOST_COMM[12];
	bit [ 7: 0] CDD_STAT[12];
	bit         CDD_IO_START;
	bit         CDD_IO_DONE;
	bit         CDD_COMM_RDY;
	bit         CD_IN_MSB = 0;
	always @(posedge CLK) begin
		bit         cd_out96_last = 1;
		bit [ 3: 0] WAIT_CNT = '0;
	
		CDD_IO_START <= 0;
		if (!RST_N) begin
//			cd_out96_last = 1;
		end else if (cd_out[96] != cd_out96_last)  begin
			cd_out96_last <= cd_out[96];
			{CDD_STAT[11],CDD_STAT[10],CDD_STAT[9],CDD_STAT[8],CDD_STAT[7],CDD_STAT[6],CDD_STAT[5],CDD_STAT[4],CDD_STAT[3],CDD_STAT[2],CDD_STAT[1],CDD_STAT[0]} <= cd_out[95:0];
			WAIT_CNT <= '1;
		end else if (WAIT_CNT) begin
			WAIT_CNT <= WAIT_CNT - 4'd1;
			CDD_IO_START <= (WAIT_CNT == 4'd1);
		end
		
		if (CDD_COMM_RDY) begin
//			cd_in[95:0] <= {HOST_COMM[11],HOST_COMM[10],HOST_COMM[9],HOST_COMM[8],HOST_COMM[7],HOST_COMM[6],HOST_COMM[5],HOST_COMM[4],HOST_COMM[3],HOST_COMM[2],HOST_COMM[1],HOST_COMM[0]};
//			cd_in[96] <= ~cd_in[96];
			CD_IN_MSB <= ~CD_IN_MSB;
		end
	end
	assign cd_in = {CD_IN_MSB,HOST_COMM[11],HOST_COMM[10],HOST_COMM[9],HOST_COMM[8],HOST_COMM[7],HOST_COMM[6],HOST_COMM[5],HOST_COMM[4],HOST_COMM[3],HOST_COMM[2],HOST_COMM[1],HOST_COMM[0]};
			
	bit [7:0] HOST_DATA = '0;
	bit [7:0] CDD_DATA = '0;
	always @(posedge CLK) begin
		bit [ 3: 0] BYTE_POS;
		bit [ 2: 0] BIT_POS;
		bit         COMCLK_OLD;
		bit         CDD_NEXT_BYTE = 0;
		bit [10: 0] DELAY_CNT = '0;
		
		if (CDD_IO_START) CD_COMREQ_N <= 1;
		if (CDD_NEXT_BYTE) CD_COMREQ_N <= 0;
		
		COMCLK_OLD <= CD_COMCLK;
		CDD_IO_DONE <= 0;
		if (!RST_N) begin
			CDD_IO_DONE <= 0;
			BIT_POS <= '0;
		end else if (CDD_IO_START) begin
			CDD_IO_DONE <= 0;
			BIT_POS <= '0;
		end else if (!CD_COMCLK && COMCLK_OLD) begin
			{CDD_DATA,CD_CDATA} <= {1'b0,CDD_DATA};
		end else if (CD_COMCLK && !COMCLK_OLD) begin
			HOST_DATA <= {CD_HDATA,HOST_DATA[7:1]};
			CD_COMREQ_N <= 1;
			BIT_POS <= BIT_POS + 3'd1;
			if (BIT_POS == 3'd7) begin
				CDD_IO_DONE <= 1;
			end
		end
		
		CDD_NEXT_BYTE <= 0;
		CDD_COMM_RDY <= 0;
		if (!RST_N) begin
			CDD_NEXT_BYTE <= 0;
			CDD_COMM_RDY <= 0;
			BYTE_POS <= '0;
			DELAY_CNT <= '0;
		end else if (CDD_IO_START) begin
			CDD_DATA <= CDD_STAT[0];
			CD_COMSYNC_N <= 0;
			BYTE_POS <= 4'd0;
			DELAY_CNT <= 11'h3FF;
		end else if (CDD_IO_DONE) begin
			HOST_COMM[BYTE_POS] <= HOST_DATA;
			CD_COMSYNC_N <= 1;
			BYTE_POS <= BYTE_POS + 4'd1;
			if (BYTE_POS < 4'd11) begin
				CDD_DATA <= CDD_STAT[BYTE_POS + 4'd1];
				DELAY_CNT <= 11'h3FF;
			end else if (BYTE_POS == 4'd11) begin
				CDD_DATA <= 8'h00;
				DELAY_CNT <= 11'h3FF;
				CDD_COMM_RDY <= 1;
			end
		end
		
		if (DELAY_CNT) begin
			DELAY_CNT <= DELAY_CNT - 11'h001;
			CDD_NEXT_BYTE <= (DELAY_CNT == 11'h001);
		end
	end
	
	
	bit         SPEED[2];
	bit         AUDIO[2];
	bit [ 1: 0] BUF_N[2];
	bit         PEND[2];
	
	bit         CDD_SPEED;
	bit         CDD_AUDIO;
	bit [ 1: 0] CDD_BUF_N;
	bit [11: 1] BUF_ADDR;
	always @(posedge CLK or negedge RST_N) begin
		bit [ 2: 0] state,state2;
		bit         PAR_POS_WR;
		bit         PAR_POS_RD;
	
		if (!RST_N) begin
			state <= '0;
			state2 <= '0;			
			PEND <= '{2{0}};
			PAR_POS_WR <= 0;
			PAR_POS_RD <= 0;
			SPEED <= '{2{1'b0}};
			AUDIO <= '{2{1'b0}};
			BUF_N <= '{2{2'b00}};
			PEND <= '{2{1'b0}};
		end else begin
			CDFIFO_WR <= 0;
			case (state)
				0: if (CDD_ACT && CDD_WR) begin
					SPEED[PAR_POS_WR] <= CDD_DI[0];
					AUDIO[PAR_POS_WR] <= CDD_DI[1];
					BUF_N[PAR_POS_WR] <= CDD_DI[5:4];
					PEND[PAR_POS_WR] <= 1;
					PAR_POS_WR <= ~PAR_POS_WR;
					state <= 1;
				end
				
				1: if (!CDD_ACT) begin
					state <= 0;
				end
			endcase
			
			CD_BUF_RD <= 0;
			case (state2)
				0: if (PEND[PAR_POS_RD] && !CDD_ACT) begin
					PEND[PAR_POS_RD] <= 0;
					BUF_ADDR <= '0;
					CDD_BUF_N <= BUF_N[PAR_POS_RD];
					CDD_AUDIO <= AUDIO[PAR_POS_RD];
					CDD_SPEED <= SPEED[PAR_POS_RD];
					PAR_POS_RD <= ~PAR_POS_RD;
					state2 <= 1;
				end
				
				1: if (!CDFIFO_FULL) begin
					CD_BUF_RD <= 1;
					state2 <= 2;
				end
				
				2: if (CD_BUF_RDY && !CDD_CE) begin
					CDFIFO_WR <= 1;
					CDFIFO_DATA <= {CDD_SPEED,CDD_AUDIO,CD_BUF_DI};
					state2 <= 3;
				end
				
				3: begin
					state2 <= 1;
					BUF_ADDR <= BUF_ADDR + 1'd1;
					if (BUF_ADDR == 11'd1176 - 1)
						state2 <= 0;
				end
			endcase
		end
	end
	assign CD_BUF_ADDR = {CDD_BUF_N,BUF_ADDR ^ {11'b00000000011}};
	
	
	bit [17:0] CDFIFO_DATA;
	bit        CDFIFO_RD;
	bit        CDFIFO_WR;
	bit [17:0] CDFIFO_Q;
	bit        CDFIFO_EMPTY;
	bit        CDFIFO_FULL;
	CDFIFO fifo 
	(
		.clock(CLK),
		.data(CDFIFO_DATA),
		.wrreq(CDFIFO_WR),
		.rdreq(CDFIFO_RD),
		.q(CDFIFO_Q),
		.empty(CDFIFO_EMPTY),
		.full(CDFIFO_FULL)
	);
	
	bit        CDD_CE_DIV;
	always @(posedge CLK) if (CDD_CE) CDD_CE_DIV <= ~CDD_CE_DIV;
	
	wire [15:0] CDFIFO_Q_DATA = CDFIFO_Q[15:0];
	wire        CDFIFO_Q_AUDIO = CDFIFO_Q[16];
	wire        CDFIFO_Q_SPEED = CDFIFO_Q[17];
	always @(posedge CLK or negedge RST_N) begin
		if (!RST_N) begin
			CD_CK <= 0;
			CD_DATA <= '0;
			CDFIFO_RD <= 0;
		end else begin
			CDFIFO_RD <= 0;
			CD_CK <= 0;
			if (!CDFIFO_EMPTY && CDD_CE) begin
				if (CDFIFO_Q_SPEED || CDD_CE_DIV) begin
					CDFIFO_RD <= 1;
						
					CD_DATA <= CDFIFO_Q_DATA;
					CD_CK <= 1;
					CD_AUDIO <= CDFIFO_Q_AUDIO;
				end
			end
		end
	end

endmodule

module CDFIFO (
	clock,
	data,
	rdreq,
	wrreq,
	empty,
	full,
	q);

	input	  clock;
	input	[17:0]  data;
	input	  rdreq;
	input	  wrreq;
	output	  empty;
	output	  full;
	output	[17:0]  q;

	wire  sub_wire0;
	wire  sub_wire1;
	wire [17:0] sub_wire2;
	wire  empty = sub_wire0;
	wire  full = sub_wire1;
	wire [17:0] q = sub_wire2[17:0];

	scfifo	scfifo_component (
				.clock (clock),
				.data (data),
				.rdreq (rdreq),
				.wrreq (wrreq),
				.empty (sub_wire0),
				.full (sub_wire1),
				.q (sub_wire2),
				.aclr (),
				.almost_empty (),
				.almost_full (),
				.eccstatus (),
				.sclr (),
				.usedw ());
	defparam
		scfifo_component.add_ram_output_register = "OFF",
		scfifo_component.intended_device_family = "Cyclone V",
		scfifo_component.lpm_hint = "RAM_BLOCK_TYPE=M10K",
		scfifo_component.lpm_numwords = 64,
		scfifo_component.lpm_showahead = "ON",
		scfifo_component.lpm_type = "scfifo",
		scfifo_component.lpm_width = 18,
		scfifo_component.lpm_widthu = 6,
		scfifo_component.overflow_checking = "OFF",
		scfifo_component.underflow_checking = "OFF",
		scfifo_component.use_eab = "ON";

endmodule
