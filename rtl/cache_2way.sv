//
// 2015, rok.krajnc@gmail.com
// 2020, Alexey Melnikov
//
// this is a 2-way set-associative cache
// write-through, look-through
// 16kB cache size, 8kB per way
// Optimized for 64bit DRAM
//
//

module cache_2way
(
	// system
	input             clk,            // clock
	input             rst,            // cache reset

	input             cache_enable,
	input             cache_clear,
	input             cache_inhibit,  // cache inhibit update

	// cpu    
	input             cpu_cs,         // cpu activity
	input      [30:2] cpu_adr,        // cpu address
	input       [3:0] cpu_bs,         // cpu byte selects
	input             cpu_we,         // cpu write
	input             cpu_rd,         // cpu data read
	input      [31:0] cpu_dat_w,      // cpu write data
	output reg [31:0] cpu_dat_r,      // cpu read data
	output reg        cpu_ack,        // cpu acknowledge

	// writebuffer
	output reg        wb_en,          // writebuffer enable

	// sdram
	input      [63:0] mem_dat_r,      // sdram read data
	output reg        mem_read_req,   // sdram read request from cache
	input             mem_read_ack    // sdram read acknowledge to cache
);


//// internal signals ////

reg cc_en;
reg cc_clr;
always @ (posedge clk) begin
	if (rst) begin
		cc_en  <= 1'b0;
		cc_clr <= 1'b0;
	end else if (!cpu_cs) begin
		cc_en  <= cache_enable;
		cc_clr <= cache_clear;
	end
end 

// slice up cpu address
wire        cpu_adr_blk = cpu_adr[2];    // cache block address (inside cache row), 2 bits for 4x16 rows
wire  [9:0] cpu_adr_idx = cpu_adr[12:3];   // cache row address, 8 bits
wire [17:0] cpu_adr_tag = cpu_adr[30:13];  // tag, 18 bits

// cpu side state machine
localparam [3:0]
	CPU_SM_INIT  = 4'd0,
	CPU_SM_IDLE  = 4'd1,
	CPU_SM_WRITE = 4'd2,
	CPU_SM_WB    = 4'd3,
	CPU_SM_READ  = 4'd4,
	CPU_SM_WAIT  = 4'd5,
	CPU_SM_FILL  = 4'd6,
	CPU_SM_FILLW = 4'd7;

reg  [3:0] cpu_sm_state;
reg        cpu_sm_dtag_we;
reg        cpu_sm_dram0_we;
reg        cpu_sm_dram1_we;
reg  [3:0] cpu_sm_bs;
reg [31:0] cpu_sm_mem_dat_w;
reg [39:0] cpu_sm_tag_dat_w;
reg  [9:0] upd_sm_adr;
reg        upd_sm_dram0_we;
reg        upd_sm_dram1_we;
reg [63:0] upd_data;

always @ (posedge clk) begin
  if (rst) begin
    mem_read_req      <= 1'b0;
    wb_en             <= 1'b0;
    cpu_ack           <= 1'b0;
    cpu_sm_state      <= CPU_SM_INIT;
    cpu_sm_dtag_we    <= 1'b0;
    cpu_sm_dram0_we   <= 1'b0;
    cpu_sm_dram1_we   <= 1'b0;
    cpu_sm_bs         <= 4'b1111;
    upd_sm_dram0_we   <= 1'b0;
    upd_sm_dram1_we   <= 1'b0;
  end else begin
    // default values
    mem_read_req      <= 1'b0;
    wb_en             <= 1'b0;
    cpu_sm_dtag_we    <= 1'b0;
    cpu_sm_dram0_we   <= 1'b0;
    cpu_sm_dram1_we   <= 1'b0;
    cpu_sm_bs         <= 4'b1111;
    upd_sm_dram0_we   <= 1'b0;
    upd_sm_dram1_we   <= 1'b0;
    // state machine
    case (cpu_sm_state)
      CPU_SM_INIT : begin
        // waiting for cache init
        if (cache_init_done) begin
          cpu_sm_state <= CPU_SM_IDLE;
        end else begin
          cpu_sm_state <= CPU_SM_INIT;
        end
      end
      CPU_SM_IDLE : begin
        // waiting for CPU access
        if (cpu_cs) begin
          if (cpu_we) begin
            cpu_sm_state <= CPU_SM_WRITE;
          end else begin
            cpu_sm_state <= CPU_SM_READ;
          end
        end else begin
          if (cc_clr)
            cpu_sm_state <= CPU_SM_INIT;
          else
            cpu_sm_state <= CPU_SM_IDLE;
        end
      end
      CPU_SM_WRITE : begin
        // on hit update cache, on miss no update neccessary; tags don't get updated on writes
        cpu_sm_bs <= cpu_bs;
        cpu_sm_mem_dat_w <= cpu_dat_w;
        cpu_sm_dram0_we <= dtag0_match && dtag0_valid;
        cpu_sm_dram1_we <= dtag1_match && dtag1_valid;
        cpu_sm_state <= CPU_SM_WB;
        wb_en <= 1'b1;
        if (!cpu_cs) cpu_sm_state <= CPU_SM_IDLE;
      end
      CPU_SM_WB : begin
        if (!cpu_cs) cpu_sm_state <= CPU_SM_IDLE;
        else wb_en <= 1'b1;
      end
      CPU_SM_READ : begin
        if (cc_en && dtag0_match && dtag0_valid) begin
          // data is already in data cache way 0
          cpu_dat_r <= ddram0_cpu_dat_r;
          cpu_ack <= 1'b1;
          cpu_sm_dtag_we <= 1'b1;
          cpu_sm_tag_dat_w <= {1'b0, dtram_cpu_dat_r[38:0]};
          cpu_sm_state <= CPU_SM_WAIT;
        end
		  else if (cc_en && dtag1_match && dtag1_valid) begin
          // data is already in data cache way 1
          cpu_dat_r <= ddram1_cpu_dat_r;
          cpu_ack <= 1'b1;
          cpu_sm_dtag_we <= 1'b1;
          cpu_sm_tag_dat_w <= {1'b1, dtram_cpu_dat_r[38:0]};
          cpu_sm_state <= CPU_SM_WAIT;
        end
		  else begin
          // on miss fetch data from SDRAM
          mem_read_req <= 1'b1;
          cpu_sm_state <= CPU_SM_FILL;
        end
      end
      CPU_SM_WAIT : begin
        if (!cpu_cs) cpu_sm_state <= CPU_SM_IDLE;
      end
      CPU_SM_FILL : begin
        upd_sm_adr <= cpu_adr_idx; 
        if (mem_read_ack) begin
          // read data to cpu
          cpu_dat_r <= mem_dat_r[{cpu_adr_blk, 5'b00000} +:32];
          cpu_ack <= 1'b1;
          if (cache_inhibit) begin
            // don't update cache if caching is inhibited
            cpu_sm_state <= CPU_SM_FILLW;
          end else begin      
            // update tag ram
            if (dtag_lru) begin
              cpu_sm_tag_dat_w <= {1'b0, 1'b1, dtram_cpu_dat_r[37], 1'b0, dtram_cpu_dat_r[35:18], cpu_adr_tag};
            end else begin
              cpu_sm_tag_dat_w <= {1'b1, dtram_cpu_dat_r[38], 1'b1, 1'b0, cpu_adr_tag, dtram_cpu_dat_r[17: 0]};
            end
            cpu_sm_dtag_we <= 1;
            // cache line fill 1st word
            upd_data <= mem_dat_r;
            upd_sm_dram0_we <=  dtag_lru;
            upd_sm_dram1_we <= !dtag_lru;
            cpu_sm_state <= CPU_SM_FILLW;
          end
        end
      end
      CPU_SM_FILLW : begin
        if (!cpu_ack) cpu_sm_state <= CPU_SM_IDLE;
      end
    endcase
    // when CPU lowers its request signal, lower ack too
    if (!cpu_cs) cpu_ack <= 1'b0;
  end
end


//// sdram side ////

localparam [3:0]
	SDR_SM_INIT0 = 4'd0,
	SDR_SM_INIT1 = 4'd1,
	SDR_SM_IDLE  = 4'd2,
	SDR_SM_WAIT  = 4'd3;

reg [3:0] sdr_sm_state;
reg [9:0] sdr_sm_adr;
reg       sdr_sm_dtag_we;
reg       cache_init_done;

// sdram side state machine
always @ (posedge clk) begin
  if (rst) begin
    cache_init_done   <= 1'b0;
    sdr_sm_state      <= SDR_SM_INIT0;
    sdr_sm_dtag_we    <= 1'b0;
  end else begin
    // default values
    cache_init_done   <= 1'b1;
    sdr_sm_dtag_we    <= 1'b0;
    // state machine
    case (sdr_sm_state)
      SDR_SM_INIT0 : begin
        // prepare to clear cache
        cache_init_done <= 1'b0;
        sdr_sm_adr <= 10'd0;
        sdr_sm_dtag_we <= 1'b1;
        sdr_sm_state <= SDR_SM_INIT1;
      end
      SDR_SM_INIT1 : begin
        // clear cache
        cache_init_done <= 1'b0;
        sdr_sm_adr <= sdr_sm_adr + 1'd1;
        sdr_sm_dtag_we <= 1'b1;
        if (&sdr_sm_adr) begin
          sdr_sm_state <= SDR_SM_IDLE;
        end else begin
          sdr_sm_state <= SDR_SM_INIT1;
        end
      end
      SDR_SM_IDLE : begin
        if (cc_clr) sdr_sm_state <= SDR_SM_INIT0;
      end
    endcase
  end
end


//// data data memories ////

// data tag ram
wire dtag0_match = (cpu_adr_tag == dtram_cpu_dat_r[17:0]);
wire dtag1_match = (cpu_adr_tag == dtram_cpu_dat_r[35:18]);
wire dtag_lru    = dtram_cpu_dat_r[39];
wire dtag0_valid = dtram_cpu_dat_r[38];
wire dtag1_valid = dtram_cpu_dat_r[37];

wire [39:0] dtram_cpu_dat_r;

dpram #(10,40) dtram (
  .clock      (clk              ),

  .address_a  (cpu_adr_idx      ),
  .wren_a     (cpu_sm_dtag_we   ),
  .data_a     (cpu_sm_tag_dat_w ),
  .q_a        (dtram_cpu_dat_r  ),

  .address_b  (sdr_sm_adr       ),
  .wren_b     (sdr_sm_dtag_we   )
);

// data data ram 0
wire [31:0] ddram0_cpu_dat_r;
cache_be ddram0 (
  .clock      (clk              ),

  .address_a  ({cpu_adr_idx, cpu_adr_blk}),
  .byteena_a  (cpu_sm_bs        ),
  .wren_a     (cpu_sm_dram0_we  ),
  .data_a     (cpu_sm_mem_dat_w ),
  .q_a        (ddram0_cpu_dat_r ),

  .address_b  (upd_sm_adr       ),
  .wren_b     (upd_sm_dram0_we  ),
  .data_b     (upd_data         )
);

// data data ram 1
wire [31:0] ddram1_cpu_dat_r;
cache_be ddram1 (
  .clock      (clk              ),

  .address_a  ({cpu_adr_idx, cpu_adr_blk}),
  .byteena_a  (cpu_sm_bs        ),
  .wren_a     (cpu_sm_dram1_we  ),
  .data_a     (cpu_sm_mem_dat_w ),
  .q_a        (ddram1_cpu_dat_r ),

  .address_b  (upd_sm_adr       ),
  .wren_b     (upd_sm_dram1_we  ),
  .data_b     (upd_data         )
);

endmodule


module cache_be
(
	input         clock,

	input	 [11:0] address_a,
	input	  [3:0] byteena_a,
	input	 [31:0] data_a,
	input         wren_a,
	output [31:0] q_a,

	input	  [9:0] address_b,
	input	 [63:0] data_b,
	input	        wren_b
);

generate
	genvar i;
	for(i=0; i<8; i++) begin: ramblock

		wire [7:0] dout;

		if(i[1:0] == 2'b00) 
			assign q_a[31:24] = (address_a[1] == i[2]) ? dout : 8'bZ;
		else if(i[1:0] == 2'b01) 
			assign q_a[23:16] = (address_a[1] == i[2]) ? dout : 8'bZ;
		else if(i[1:0] == 2'b10) 
			assign q_a[15:8] = (address_a[1] == i[2]) ? dout : 8'bZ;
		else
			assign q_a[7:0]  = (address_a[1] == i[2]) ? dout : 8'bZ;
 
		spram #(10,8," ",{"MEM",{4'h3,i[3:0]}}) ram
		(
			.clock(clock),
			.address(wren_b ? address_b : address_a[11:2]),
			.data(wren_b ? data_b[(i<<3) +:8] : i[1:0] == 2'b00 ? data_a[31:24] : 
			                                    i[1:0] == 2'b01 ? data_a[23:16] :
															i[1:0] == 2'b10 ? data_a[15:8] :
															data_a[7:0]),
			.wren(wren_b | (wren_a & byteena_a[i[1:0]])),
			.cs(wren_b | address_a[1] == i[2]),
			.q(dout)
		);
	end
endgenerate

endmodule
