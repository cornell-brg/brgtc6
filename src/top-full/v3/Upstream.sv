`ifndef BRGTC6_UPSTREAM_V3
`define BRGTC6_UPSTREAM_V3

`include "credit/CreditSend.sv"
`include "pattern/pattern_bypass/PatternGenBypass.sv"

//=========================================================================
// Upstream Module Link V3
//=========================================================================
module Upstream #(
    parameter p_bit_width = 5,
    parameter p_max_cred  = 8,
    parameter p_clk_width = 4
) (
    input  logic                   clk,
    input  logic                   reset,

    input  logic                   bypass,
    input  logic                   fixed_pattern,

    input  logic [p_clk_width-1:0] clk_div,
    input  logic [p_clk_width-1:0] clk_skew,

    input  logic [p_bit_width-1:0] istream_msg,
    input  logic                   istream_val,
    output logic                   istream_rdy,

    input  logic [p_bit_width-1:0] pattern_1,
    input  logic [p_bit_width-1:0] pattern_2,

    output logic [p_bit_width-1:0] cred_msg,
    output logic                   cred_val,
    output logic                   cred_clk,
    output logic                   cred_rst,
    input  logic                   cred_cred
);

logic [p_bit_width-1:0] pattern_msg;
logic                   pattern_val;
logic                   pattern_rdy;

PatternGenBypass #(
    .p_bit_width (p_bit_width)
) pattern_gen (
    .clk           (clk),
    .reset         (reset),
    .bypass        (bypass),
    .fixed_pattern (fixed_pattern),
    .istream_msg   (istream_msg),
    .istream_val   (istream_val),
    .istream_rdy   (istream_rdy),
    .pattern_1     (pattern_1),
    .pattern_2     (pattern_2),
    .ostream_msg   (pattern_msg),
    .ostream_val   (pattern_val),
    .ostream_rdy   (pattern_rdy)
);

CreditSend #(
    .p_bit_width (p_bit_width),
    .p_max_cred  (p_max_cred),
    .p_clk_width (p_clk_width)
) credit_send (
    .clk       (clk),
    .reset     (reset),
    .in_msg    (pattern_msg),
    .in_val    (pattern_val),
    .in_rdy    (pattern_rdy),
    .clk_div   (clk_div),
    .clk_skew  (clk_skew),
    .cred_msg  (cred_msg),
    .cred_val  (cred_val),
    .cred_clk  (cred_clk),
    .cred_rst  (cred_rst),
    .cred_cred (cred_cred)
);

endmodule

`endif /* BRGTC6_UPSTREAM_V3 */
