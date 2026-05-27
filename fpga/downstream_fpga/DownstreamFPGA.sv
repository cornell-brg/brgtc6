`include "pattern/pattern_non_bypass/PatternChkNonBypass.sv"
`include "../Hex5.sv"
`include "asyncfifo/AsyncFifo.sv"
`include "top-full/Downstream.sv"

module DownstreamFPGA (
    input  logic                   reset_n,

    input  logic                   clk,

    input  logic [4:0]             cred_msg,
    input  logic                   cred_val,
    input  logic                   cred_clk,
    input  logic                   cred_rst,
    output logic                   cred_cred,

    output logic [1:0]            pattern_state,
    output logic [6:0]            err_hex1,
    output logic [6:0]            err_hex2
);

logic reset;
assign reset = ~reset_n;

logic [4:0] err_count;

Downstream #(
    .bit_width(5),
    .buffer_depth(8),
    .sink_delay(0)
) downstream (
    .clk(clk),
    .reset(reset),
    .cred_msg(cred_msg),
    .cred_val(cred_val),
    .cred_clk(cred_clk),
    .cred_rst(cred_rst),
    .cred_cred(cred_cred),
    .pattern_state(pattern_state),
    .pattern_err_count(err_count)
);

Hex5 hex1 (
    .q(err_count),
    .seg_1(err_hex1),
    .seg_2(err_hex2)
);

endmodule