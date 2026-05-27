`ifndef BRGTC6_UPSTREAM_V0
`define BRGTC6_UPSTREAM_V0

`include "credit/ClkGen.sv"

//=========================================================================
// Upstream Module Link V0
//=========================================================================
module Upstream #(
    parameter bit_width = 5,
    parameter clk_div = 1
) (
    input  logic                   clk,
    input  logic                   reset,

    input  logic [bit_width-1:0]   istream_msg,
    input  logic                   istream_val,
    output logic                   istream_rdy,

    output logic [bit_width-1:0]   link_msg,
    output logic                   link_val,
    output logic                   link_clk,
    output logic                   link_rst
);

ClkGen #(
   .clk_div_factor(clk_div),
   .reset_delay(8)
) clk_gen (
    .clk(clk),
    .reset(reset),
    .o_clk(link_clk),
    .o_reset(link_rst),
    .en(istream_rdy)
);

endmodule

`endif // BRGTC6_UPSTREAM_V0