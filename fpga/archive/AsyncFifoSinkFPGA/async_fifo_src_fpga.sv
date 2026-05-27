`include "pattern.sv"


module AsyncFifoSrcFPGA (
    input   logic       clk,
    input   logic       reset,
    input   logic       start,

    output  logic       ostream_val,
    output  logic [4:0] ostream_msg,
    input   logic       ostream_rdy
);

    logic pattern_send_val;
    logic pattern_send_rdy;

    logic started;

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