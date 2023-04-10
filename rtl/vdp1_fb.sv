module vdp1_fb_352x256x16
(
	input             clock,
	input      [16:0] address,
	input      [15:0] data,
	input       [1:0] wren,
	output     [15:0] q
);
	
	wire [15:0] ram64Kx16_q,ram16Kx16_q,ram8Kx16_q;
	spram #(16,8)	ram64Kx16l
	(
		.clock(clock),
		.address(address[15:0]),
		.data(data[7:0]),
		.wren(wren[0] & ~address[16]),
		.q(ram64Kx16_q[7:0])
	);
	spram #(16,8)	ram64Kx16h
	(
		.clock(clock),
		.address(address[15:0]),
		.data(data[15:8]),
		.wren(wren[1] & ~address[16]),
		.q(ram64Kx16_q[15:8])
	);
	
	spram #(14,8)	ram16Kx16l
	(
		.clock(clock),
		.address(address[13:0]),
		.data(data[7:0]),
		.wren(wren[0] & address[16] & ~address[15] & ~address[14]),
		.q(ram16Kx16_q[7:0])
	);
	spram #(14,8)	ram16Kx16h
	(
		.clock(clock),
		.address(address[13:0]),
		.data(data[15:8]),
		.wren(wren[1] & address[16] & ~address[15] & ~address[14]),
		.q(ram16Kx16_q[15:8])
	);
	
	spram #(13,8)	ram8Kx16l
	(
		.clock(clock),
		.address(address[12:0]),
		.data(data[7:0]),
		.wren(wren[0] & address[16] & ~address[15] & address[14] & ~address[13]),
		.q(ram8Kx16_q[7:0])
	);
	spram #(13,8)	ram8Kx16h
	(
		.clock(clock),
		.address(address[12:0]),
		.data(data[15:8]),
		.wren(wren[1] & address[16] & ~address[15] & address[14] & ~address[13]),
		.q(ram8Kx16_q[15:8])
	);
	assign q = !address[16]                 ? ram64Kx16_q :
	           !address[15] && !address[14] ? ram16Kx16_q :
						                           ram8Kx16_q;


endmodule
