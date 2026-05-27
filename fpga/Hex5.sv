`ifndef C2C_HEX5
`define C2C_HEX5

//=========================================================================
// Hex5
//=========================================================================

module Hex5(
	input logic [4:0] q,
	output logic [6:0] seg_1,
	output logic [6:0] seg_2
);

logic [2:0] d2;
logic [3:0] d1;

localparam seg_D0 = 7'b100_0000;
localparam seg_D1 = 7'b111_1001;
localparam seg_D2 = 7'b010_0100;
localparam seg_D3 = 7'b011_0000;
localparam seg_D4 = 7'b001_1001;
localparam seg_D5 = 7'b001_0010;
localparam seg_D6 = 7'b000_0010;
localparam seg_D7 = 7'b111_1000;
localparam seg_D8 = 7'b000_0000;
localparam seg_D9 = 7'b001_0000;

always_comb begin
	d2 =  q >= 5'd30 ? 3 : (q >= 20 ? 2 : (q >= 10 ? 1 : 0));
	d1 = q - d2 * 10;
	
	case(d1)
		0: seg_1 = seg_D0;
		1: seg_1 = seg_D1;
		2: seg_1 = seg_D2;
		3: seg_1 = seg_D3;
		4: seg_1 = seg_D4;
		5: seg_1 = seg_D5;
		6: seg_1 = seg_D6;
		7: seg_1 = seg_D7;
		8: seg_1 = seg_D8;
		9: seg_1 = seg_D9;
		default: seg_1 = 7'b111_1111;
	endcase

	case(d2)
		0: seg_2 = seg_D0;
		1: seg_2 = seg_D1;
		2: seg_2 = seg_D2;
		3: seg_2 = seg_D3;
		default: seg_2 = 7'b111_1111;
	endcase
end

endmodule

`endif /* C2C_HEX5 */