`ifndef BRGTC6_DOWNSTREAM_V0
`define BRGTC6_DOWNSTREAM_V0

`include "asyncfifo/AsyncFifo.sv"

//=========================================================================
// Downstream Module Link V0
//=========================================================================
module Downstream #(
    parameter bit_width = 5,
    parameter buffer_depth = 8
) (
    input  logic                   clk,
    input  logic                   reset,

    input  logic [bit_width-1:0]   link_clk,
    input  logic [bit_width-1:0]   link_msg,
    input  logic                   link_val,
    input  logic                   link_rst,

    output logic [bit_width-1:0]   ostream_msg,
    output logic                   ostream_val,
    input  logic                   ostream_rdy
);

AsyncFifo #(
    .num_entries(buffer_depth),
    .bit_width(bit_width)
) downstream (
    .i_clk(link_clk),
    .i_reset(link_rst),
    .istream_val(link_val),
    // verilator lint_off PINCONNECTEMPTY
    .istream_rdy(),
    // verilator lint_on PINCONNECTEMPTY
    .istream_msg(link_msg),
    .o_clk(clk),
    .o_reset(reset),
    .ostream_val(ostream_val),
    .ostream_rdy(ostream_rdy),
    .ostream_msg(ostream_msg)
);

endmodule

`endif // BRGTC6_DOWNSTREAM_V0