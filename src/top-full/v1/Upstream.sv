`ifndef BRGTC6_UPSTREAM_V1
`define BRGTC6_UPSTREAM_V1

`include "credit/CreditSend.sv"

//=========================================================================
// Upstream Module Link V1
//=========================================================================
module Upstream #(
    parameter bit_width = 5,
    parameter max_cred = 8,
    parameter clk_width = 4
) (
    input  logic                   clk,
    input  logic                   reset,

    input  logic [bit_width-1:0]   istream_msg,
    input  logic                   istream_val,
    output logic                   istream_rdy,

    output logic [bit_width-1:0]   cred_msg,
    output logic                   cred_val,
    output logic                   cred_clk,
    output logic                   cred_rst,
    input  logic                   cred_cred
);

CreditSend #(
    .p_bit_width(bit_width),
    .p_max_cred(max_cred),
    .p_clk_width(clk_width)
) credit_send (
    .clk(clk),
    .reset(reset),
    .in_msg(istream_msg),
    .in_val(istream_val),
    .in_rdy(istream_rdy),
    .clk_div(4'd8),
    .clk_skew(4'd1),
    .cred_msg(cred_msg),
    .cred_val(cred_val),
    .cred_clk(cred_clk),
    .cred_rst(cred_rst),
    .cred_cred(cred_cred)
);

endmodule


`endif /* BRGTC6_UPSTREAM_V1 */
