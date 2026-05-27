`ifndef BRGTC6_DOWNSTREAM_V3
`define BRGTC6_DOWNSTREAM_V3

`include "credit/CreditRecv.sv"
`include "pattern/pattern_bypass/PatternChkBypass.sv"

//=========================================================================
// Downstream Module Link V3
//=========================================================================
module Downstream #(
    parameter p_bit_width    = 5,
    parameter p_buffer_depth = 8
) (
    input  logic                   clk,
    input  logic                   reset,

    input  logic                   bypass,
    input  logic                   fixed_pattern,

    // Output 
    output logic [p_bit_width-1:0] ostream_msg,
    output logic                   ostream_val,
    input  logic                   ostream_rdy,

    output logic [p_bit_width-1:0] pattern_1,
    output logic [p_bit_width-1:0] pattern_2,

    output logic [1:0]             state,
    output logic [4:0]             err_count,

    // Credit interface
    input  logic [p_bit_width-1:0] cred_msg,
    input  logic                   cred_val,
    input  logic                   cred_clk,
    input  logic                   cred_rst,
    output logic                   cred_cred
);

logic [p_bit_width-1:0] pattern_msg;
logic                   pattern_val;
logic                   pattern_rdy;

CreditRecv #(
    .p_bit_width    (p_bit_width),
    .p_buffer_depth (p_buffer_depth)
) credit_recv (
    .clk       (clk),
    .reset     (reset),
    .out_msg   (pattern_msg),
    .out_val   (pattern_val),
    .out_rdy   (pattern_rdy),
    .cred_msg  (cred_msg),
    .cred_val  (cred_val),
    .cred_clk  (cred_clk),
    .cred_rst  (cred_rst),
    .cred_cred (cred_cred)
);

PatternChkBypass #(
    .p_bit_width (p_bit_width)
) pattern_chk (
    .clk           (clk),
    .reset         (reset),
    .bypass        (bypass),
    .fixed_pattern (fixed_pattern),
    .pattern_1     (pattern_1),
    .pattern_2     (pattern_2),
    .state         (state),
    .err_count     (err_count),
    .istream_msg   (pattern_msg),
    .istream_val   (pattern_val),
    .istream_rdy   (pattern_rdy),
    .ostream_msg   (ostream_msg),
    .ostream_val   (ostream_val),
    .ostream_rdy   (ostream_rdy)
);

endmodule

`endif /* BRGTC6_DOWNSTREAM_V3 */
