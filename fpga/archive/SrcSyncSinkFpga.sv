`include "PatternChk.sv"
`include "Hex5.sv"
`include "AsyncFifo.sv"

module SrcSyncSinkFPGA (
    input   logic       reset_n,
    input   logic [4:0] in,
    input   logic       i_clk,
    input   logic       o_clk,

    input   logic       i_reset,

    output  logic [6:0] err_hex1,
    output  logic [6:0] err_hex2,
    output  logic [4:0] err_count,
    output  logic [1:0] state,
    output  logic [1:0] state_pre_fifo,
    output  logic       fifo_ovfl
);

logic reset;
assign reset = ~reset_n;

logic fifo_i_rdy;

logic fifo_o_val, fifo_o_rdy;

assign fifo_o_rdy = 1'b1;

logic [4:0] fifo_o_msg;

always_ff @(posedge o_clk) begin
    if(reset) begin
        fifo_ovfl <= 1'b0;
    end else if(!fifo_o_rdy) begin
        fifo_ovfl <= 1'b1;
    end
end

PatternChk #(
    .bit_width(5)
) pre_pattern (
    .clk(i_clk),
    .reset(i_reset),
    .istream_val(1'b1),
    .istream_msg(in),
    .state(state_pre_fifo),
    .err_count()
);

AsyncFifo #(
    .num_entries(16),
    .bit_width(5)
) async_fifo (
    .istream_val(1'b1),
    .istream_rdy(fifo_i_rdy),
    .istream_msg(in),
    .ostream_val(fifo_o_val),
    .ostream_rdy(fifo_o_rdy),
    .ostream_msg(fifo_o_msg),
    .i_clk(i_clk),
    .o_clk(o_clk),
    .i_reset(i_reset),
    .o_reset(reset)
);

PatternChk #(
    .bit_width(5)
) post_pattern (
    .clk(o_clk),
    .reset(reset),
    .istream_val(fifo_o_val),
    .istream_msg(fifo_o_msg),
    .state(state),
    .err_count(err_count)
);

Hex5 hex1 (
    .q(err_count),
    .seg_1(err_hex1),
    .seg_2(err_hex2)
);

endmodule