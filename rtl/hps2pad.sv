module HPS2PAD (
	input              CLK,
	input              RST_N,
	input              SMPC_CE,
	
	output     [ 6: 0] PDR1I,
	input      [ 6: 0] PDR1O,
	input      [ 6: 0] DDR1,
	output     [ 6: 0] PDR2I,
	input      [ 6: 0] PDR2O,
	input      [ 6: 0] DDR2,
	
	input              INPUT_ACT,
	input      [ 4: 0] INPUT_POS,
	output reg [ 7: 0] INPUT_DATA,
	output reg         INPUT_WE,
	
	input      [15: 0] JOY1,
	input      [15: 0] JOY2,

   input      [ 7: 0] JOY1_X1,
   input      [ 7: 0] JOY1_Y1,
   input      [ 7: 0] JOY1_X2,
   input      [ 7: 0] JOY1_Y2,
   input      [ 7: 0] JOY2_X1,
   input      [ 7: 0] JOY2_Y1,
   input      [ 7: 0] JOY2_X2,
   input      [ 7: 0] JOY2_Y2,

	input      [ 2: 0] JOY1_TYPE,
	input      [ 2: 0] JOY2_TYPE
);

	always_comb begin
		PDR1I = 7'h7F;
		if (DDR1 == 7'h00) begin
			PDR1I = 7'h7C;
		end else if (DDR1 == 7'h40) begin
			case (PDR1O[6])
				1'b0:  PDR1I = {3'b011,JOY1[15:12]};
				1'b1:  PDR1I = {3'b111,JOY1[ 3: 3],3'b100};
			endcase
		end else if (DDR1 == 7'h60) begin
			case (PDR1O[6:5])
				2'b00: PDR1I = {3'b001,JOY1[ 7: 4]};
				2'b01: PDR1I = {3'b001,JOY1[15:12]};
				2'b10: PDR1I = {3'b001,JOY1[11: 8]};
				2'b11: PDR1I = {3'b001,JOY1[ 3: 3],3'b100};
			endcase
		end
		
		PDR2I = 7'h7F;
		if (DDR2 == 7'h00) begin
			PDR2I = 7'h7C;
		end else if (DDR2 == 7'h40) begin
			case (PDR2O[6])
				1'b0:  PDR2I = {3'b011,JOY2[15:12]};
				1'b1:  PDR2I = {3'b111,JOY2[ 3: 3],3'b100};
			endcase
		end else if (DDR2 == 7'h60) begin
			case (PDR2O[6:5])
				2'b00: PDR2I = {3'b001,JOY2[ 7: 4]};
				2'b01: PDR2I = {3'b001,JOY2[15:12]};
				2'b10: PDR2I = {3'b001,JOY2[11: 8]};
				2'b11: PDR2I = {3'b001,JOY2[ 3: 3],3'b100};
			endcase
		end
	end
	
	typedef enum {
		PADSTATE_STATUS,
		PADSTATE_ID,

		PADSTATE_DIGITAL_MSB,
		PADSTATE_DIGITAL_LSB,

		PADSTATE_ANALOG_BUTTONSMSB,
		PADSTATE_ANALOG_BUTTONSLSB,
		PADSTATE_ANALOG_X1,
		PADSTATE_ANALOG_Y1,
		PADSTATE_ANALOG_Z1,
		PADSTATE_ANALOG_DUMMY,
		PADSTATE_ANALOG_X2,
		PADSTATE_ANALOG_Y2,
		PADSTATE_ANALOG_Z2,

		PADSTATE_IDLE
	} PadState_t;
	PadState_t PADSTATE;

	parameter PAD_DIGITAL     = 0;
	parameter PAD_OFF         = 1;
	parameter PAD_WHEEL       = 2;
	parameter PAD_MISSION     = 3;
	parameter PAD_3D          = 4;
	parameter PAD_DUALMISSION = 5;
	parameter PAD_LIGHTGUN    = 6;
	
	always @(posedge CLK or negedge RST_N) begin
		bit [ 1: 0]  CURRPAD_ID;
		bit [ 2: 0]  CURRPAD_TYPE;
		bit [15: 0]  CURRPAD_BUTTONS;
		bit [ 7: 0]  CURRPAD_ANALOGX1;
		bit [ 7: 0]  CURRPAD_ANALOGY1;
		bit [ 7: 0]  CURRPAD_ANALOGX2;
		bit [ 7: 0]  CURRPAD_ANALOGY2;
		
		if (!RST_N) begin
			PADSTATE <= PADSTATE_STATUS;
			CURRPAD_ID <= 0;
			INPUT_WE <= 0;
		end else if (SMPC_CE) begin
			INPUT_WE <= 0;
			if (INPUT_ACT) begin
				case (PADSTATE)
					// STATUS and ID are common to all pads
					// STATUS: F1 for directly connected, F0 for not
					PADSTATE_STATUS: begin
						case (CURRPAD_ID)
							0: begin
								CURRPAD_TYPE <= JOY1_TYPE;
								CURRPAD_BUTTONS <= JOY1;
								// MiSTer gives signed with 0,0 at center.
								// Saturn uses unsigned with 0,0 at top-left.
								CURRPAD_ANALOGX1 <= {~JOY1_X1[7], JOY1_X1[6:0]};
								CURRPAD_ANALOGY1 <= {~JOY1_Y1[7], JOY1_Y1[6:0]};
								CURRPAD_ANALOGX2 <= {~JOY1_X2[7], JOY1_X2[6:0]};
								CURRPAD_ANALOGY2 <= {~JOY1_Y2[7], JOY1_Y2[6:0]};

								case (JOY1_TYPE)
									PAD_OFF: begin
										INPUT_DATA <= 8'hF0;
										INPUT_WE <= 1;

										// done with this peripheral
										PADSTATE <= PADSTATE_STATUS;
										CURRPAD_ID <= CURRPAD_ID + 1'd1;
									end
									default: begin
										INPUT_DATA <= 8'hF1;
										INPUT_WE <= 1;
										PADSTATE <= PADSTATE_ID;
									end
								endcase
							end
							1: begin
								CURRPAD_TYPE <= JOY2_TYPE;
								CURRPAD_BUTTONS <= JOY2;
								// MiSTer gives signed with 0,0 at center.
								// Saturn uses unsigned with 0,0 at top-left.
								CURRPAD_ANALOGX1 <= {~JOY2_X1[7], JOY2_X1[6:0]};
								CURRPAD_ANALOGY1 <= {~JOY2_Y1[7], JOY2_Y1[6:0]};
								CURRPAD_ANALOGX2 <= {~JOY2_X2[7], JOY2_X2[6:0]};
								CURRPAD_ANALOGY2 <= {~JOY2_Y2[7], JOY2_Y2[6:0]};

								case (JOY2_TYPE)
									PAD_OFF: begin
										INPUT_DATA <= 8'hF0;
										INPUT_WE <= 1;

										// done with this peripheral
										PADSTATE <= PADSTATE_STATUS;
										CURRPAD_ID <= CURRPAD_ID + 1'd1;
									end
									default: begin
										INPUT_DATA <= 8'hF1;
										INPUT_WE <= 1;
										PADSTATE <= PADSTATE_ID;
									end
								endcase
							end
							2: begin
								INPUT_DATA <= 8'hF0;
								INPUT_WE <= 1;
								PADSTATE <= PADSTATE_IDLE;
							end
						endcase
					end

					// ID: unique for each pad
					PADSTATE_ID: begin
						case (CURRPAD_TYPE)
							// TODO: lightgun currently just digital
							PAD_DIGITAL, PAD_LIGHTGUN: begin
								INPUT_DATA <= 8'h02;
								INPUT_WE <= 1;
								PADSTATE <= PADSTATE_DIGITAL_MSB;
							end
							// Wheel is a 1-axis analog device
							PAD_WHEEL: begin
								INPUT_DATA <= 8'h13;
								INPUT_WE <= 1;
								PADSTATE <= PADSTATE_ANALOG_BUTTONSMSB;
							end
							// Mission Stick is a 3-axis analog device
							PAD_MISSION: begin
								INPUT_DATA <= 8'h15;
								INPUT_WE <= 1;
								PADSTATE <= PADSTATE_ANALOG_BUTTONSMSB;
							end
							// 3D Pad is a 4-axis analog device
							PAD_3D: begin
								INPUT_DATA <= 8'h16;
								INPUT_WE <= 1;
								PADSTATE <= PADSTATE_ANALOG_BUTTONSMSB;
							end
							// Dual Mission is a 6-axis device,
							// with a dummy/expansion byte
							PAD_DUALMISSION: begin
								INPUT_DATA <= 8'h19;
								INPUT_WE <= 1;
								PADSTATE <= PADSTATE_ANALOG_BUTTONSMSB;
							end
						endcase
					end


					// Saturn 6-button digital pad
					PADSTATE_DIGITAL_MSB: begin
						INPUT_DATA <= CURRPAD_BUTTONS[15:8];
						INPUT_WE <= 1;
						PADSTATE <= PADSTATE_DIGITAL_LSB;
					end
					PADSTATE_DIGITAL_LSB: begin
						INPUT_DATA <= CURRPAD_BUTTONS[7:0];
						INPUT_WE <= 1;

						// done with this peripheral
						PADSTATE <= PADSTATE_STATUS;
						CURRPAD_ID <= CURRPAD_ID + 1'd1;
					end

					// Button encoding is the same for analog pads
					PADSTATE_ANALOG_BUTTONSMSB: begin
						INPUT_DATA <= CURRPAD_BUTTONS[15:8];
						INPUT_WE <= 1;
						PADSTATE <= PADSTATE_ANALOG_BUTTONSLSB;
					end
					PADSTATE_ANALOG_BUTTONSLSB: begin
						INPUT_DATA <= CURRPAD_BUTTONS[7:0];
						INPUT_WE <= 1;
						PADSTATE <= PADSTATE_ANALOG_X1;
					end

					PADSTATE_ANALOG_X1: begin
						INPUT_DATA <= CURRPAD_ANALOGX1;
						INPUT_WE <= 1;

						case (CURRPAD_TYPE)
							PAD_WHEEL: begin
								// done with this peripheral
								PADSTATE <= PADSTATE_STATUS;
								CURRPAD_ID <= CURRPAD_ID + 1'd1;
							end
							default: begin
								PADSTATE <= PADSTATE_ANALOG_Y1;
							end
						endcase
					end

					PADSTATE_ANALOG_Y1: begin
						INPUT_DATA <= CURRPAD_ANALOGY1;
						INPUT_WE <= 1;

						case (CURRPAD_TYPE)
							// On 3D Pad, the RIGHT trigger is first
							PAD_3D: begin
								PADSTATE <= PADSTATE_ANALOG_Z2;
							end
							// Mission and Dual Mission go to Z1
							default: begin
								PADSTATE <= PADSTATE_ANALOG_Z1;
							end
						endcase
					end

					PADSTATE_ANALOG_Z1: begin
						INPUT_DATA <= 0; // TODO: left shoulder trigger
						INPUT_WE <= 1;

						case (CURRPAD_TYPE)
							PAD_DUALMISSION: begin
								PADSTATE <= PADSTATE_ANALOG_DUMMY;
							end
							default: begin
								// done with this peripheral
								PADSTATE <= PADSTATE_STATUS;
								CURRPAD_ID <= CURRPAD_ID + 1'd1;
							end
						endcase
					end

					// DUMMY, X2, Y2 all Dual Mission only
					PADSTATE_ANALOG_DUMMY: begin
						INPUT_DATA <= 0;
						INPUT_WE <= 1;
						PADSTATE <= PADSTATE_ANALOG_X2;
					end
					PADSTATE_ANALOG_X2: begin
						INPUT_DATA <= CURRPAD_ANALOGX2;
						INPUT_WE <= 1;
						PADSTATE <= PADSTATE_ANALOG_Y2;
					end
					PADSTATE_ANALOG_Y2: begin
						INPUT_DATA <= CURRPAD_ANALOGY2;
						INPUT_WE <= 1;
						PADSTATE <= PADSTATE_ANALOG_Z2;
					end

					// Z2 reached by Dual Mission and 3D Pad
					PADSTATE_ANALOG_Z2: begin
						INPUT_DATA <= 0; // TODO: right shoulder trigger
						INPUT_WE <= 1;

						case (CURRPAD_TYPE)
							PAD_3D: begin
								// triggers reversed on 3D Pad
								PADSTATE <= PADSTATE_ANALOG_Z1;
							end
							default: begin
								// done with this peripheral
								PADSTATE <= PADSTATE_STATUS;
								CURRPAD_ID <= CURRPAD_ID + 1'd1;
							end
						endcase
					end


					// all connected peripherals finished
					PADSTATE_IDLE: begin
						INPUT_DATA <= 8'h00;
						INPUT_WE <= 1;
					end

				endcase
			end
			else begin
				PADSTATE <= PADSTATE_STATUS;
				CURRPAD_ID <= 0;
			end
		end
	end
	
endmodule
