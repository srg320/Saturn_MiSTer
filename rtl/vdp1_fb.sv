module vdp1_fb
(
	input             clock,
	input      [16:0] address,
	input      [15:0] data,
	input       [1:0] wren,
	output     [15:0] q
);
	
	wire [15:0] ram64Kx16_q,ram16Kx16_q,ram8Kx16_q;
	spram #(16,16)	ram64Kx16
	(
		.clock(clock),
		.address(address[15:0]),
		.data(data),
		.wren(|wren & ~address[16]),
		.q(ram64Kx16_q)
	);
	spram #(14,16)	ram16Kx16
	(
		.clock(clock),
		.address(address[13:0]),
		.data(data),
		.wren(|wren & address[16] & ~address[15] & ~address[14]),
		.q(ram16Kx16_q)
	);
	spram #(13,16)	ram8Kx16
	(
		.clock(clock),
		.address(address[12:0]),
		.data(data),
		.wren(|wren & address[16] & ~address[15] & address[14] & ~address[13]),
		.q(ram8Kx16_q)
	);
	assign q = !address[16]                 ? ram64Kx16_q :
	           !address[15] && !address[14] ? ram16Kx16_q :
						                           ram8Kx16_q;


endmodule
