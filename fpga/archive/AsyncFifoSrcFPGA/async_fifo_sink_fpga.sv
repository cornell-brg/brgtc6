`include "pattern.sv"
`include "async_fifo.sv"

module AsyncFifoSinkFPGA (
    input   logic       o_clk,
    input   logic       o_reset,
    input   logic       start,

    input   logic       i_clk,
    input   logic       i_reset,
    input   logic       istream_val,
    input   logic [4:0] istream_msg,
    output  logic       istream_rdy,
    output  logic [1:0] state
);

    logic pattern_recv_rdy;
    logic fifo_istream_val;
    logic started;

    logic [4:0] ostream_msg;
    logic ostream_val, ostream_rdy;

    AsyncFifo #(
        .num_entries(8),
        .bit_width(5)
    ) async_fifo (
        .istream_val(fifo_istream_val),
        .istream_rdy(pattern_recv_rdy),
        .*
    );

    PatternChk #(
        .bit_width(5)
    ) pattern (
        .clk(o_clk),
        .reset(o_reset),
        .istream_val(ostream_val),
        .istream_msg(ostream_msg),
        .istream_rdy(ostream_rdy),
        .state(state)
    );

    always_ff @(posedge o_clk) begin
        if(o_reset) begin
            started <= 1'b0;
        end else if(start) begin
            started <= 1'b1;
        end
    end

    assign istream_rdy = pattern_recv_rdy && started;
    assign fifo_istream_val = istream_val && started;

endmodule