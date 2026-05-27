`ifndef BRGTC6_PATTERN_GEN
`define BRGTC6_PATTERN_GEN

`include "pattern/LFSR.sv"

//=========================================================================
// Pattern Generator
//=========================================================================
module PatternGen #(
    parameter bit_width = 5
) (
    input   logic                   clk,
    input   logic                   reset,
    output  logic                   ostream_val,
    output  logic [bit_width-1:0]   ostream_msg,
    input   logic                   ostream_rdy
);

    LFSR #(
        .p_bit_width(bit_width)
    ) lfsr (
        .clk(clk),
        .next(ostream_val && ostream_rdy),
        .reset(reset),
        .out(ostream_msg)
    );

    assign ostream_val = 1'b1;

endmodule

`endif /* BRGTC6_PATTERN_GEN */


