`include "PatternGen.sv"

module AsyncFifoSrcFPGA (
    input   logic       clk,
    input   logic       reset_n,
    input   logic       start,

    output  logic       ostream_val,
    output  logic [4:0] ostream_msg,
    input   logic       ostream_rdy,

    output  logic       started,
    output  logic       ostream_val_dup,
    output  logic       ostream_rdy_dup,
    output  logic       i_reset,
    output  logic       i_clk
);
    logic pattern_send_val;
    logic pattern_send_rdy;

    assign i_clk = clk;

    logic reset;
    assign reset = ~reset_n;

    assign ostream_val_dup = ostream_val;
    assign ostream_rdy_dup = ostream_rdy;
    assign i_reset = reset;

    PatternGen #(
        .bit_width(5)
    ) pattern (
        .clk(clk),
        .reset(reset),
        .ostream_val(pattern_send_val),
        .ostream_msg(ostream_msg),
        .ostream_rdy(pattern_send_rdy)
    );

    always_ff @(posedge clk) begin
        if(reset) begin
            started <= 1'b0;
        end else if(start) begin
            started <= 1'b1;
        end
    end

    assign ostream_val = pattern_send_val && started;
    assign pattern_send_rdy = ostream_rdy && started;

endmodule