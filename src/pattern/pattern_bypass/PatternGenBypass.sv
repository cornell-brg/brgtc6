`ifndef BRGTC6_PATTERN_GEN_BYPASS
`define BRGTC6_PATTERN_GEN_BYPASS

`include "pattern/LFSR.sv"

//=========================================================================
// Pattern Generator
//=========================================================================
module PatternGenBypass #(
    parameter p_bit_width = 5
) (
    input   logic                   clk,
    input   logic                   reset,

    input   logic                   bypass,         // whether input is directly forwarded to output
    input   logic                   fixed_pattern,  // whether to use fixed patterns

    input   logic [p_bit_width-1:0] istream_msg,
    input   logic                   istream_val,
    output  logic                   istream_rdy,

    input   logic [p_bit_width-1:0] pattern_1,
    input   logic [p_bit_width-1:0] pattern_2,

    output  logic                   ostream_val,
    output  logic [p_bit_width-1:0] ostream_msg,
    input   logic                   ostream_rdy
);

    logic lfsr_rdy;
    logic [p_bit_width-1:0] lfsr_out;

    logic fixed_pattern_idx;

    LFSR #(
        .p_bit_width(p_bit_width)
    ) lfsr (
        .clk(clk),
        .next(lfsr_rdy),
        .reset(reset),
        .out(lfsr_out)
    );

    always_ff @(posedge clk) begin
        if(reset) begin
            fixed_pattern_idx <= 0;
        end else begin
            if(ostream_val && ostream_rdy && !bypass && fixed_pattern) begin
                fixed_pattern_idx <= ~fixed_pattern_idx;
            end
        end
    end

    assign ostream_msg = bypass ? istream_msg : (fixed_pattern ? (fixed_pattern_idx ? pattern_2 : pattern_1) : lfsr_out);
    assign ostream_val = bypass ? istream_val : 1'b1;
    assign istream_rdy = bypass ? ostream_rdy : 1'b0;

    assign lfsr_rdy = (!bypass && !fixed_pattern) ? ostream_rdy : 1'b0;
endmodule

`endif /* BRGTC6_PATTERN_GEN_BYPASS */


