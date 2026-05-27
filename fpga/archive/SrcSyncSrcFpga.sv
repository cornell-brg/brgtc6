`include "LFSR.sv"

module SrcSyncSrcFPGA (
    input   logic       clk,
    input   logic       reset_n,
    output  logic [4:0] out,
    output  logic       i_clk
);

logic reset;
assign reset = ~reset_n;

logic clk2;
always_ff @(posedge clk) begin
    if(reset) begin
        clk2 <= 1'b0;
    end else begin
        clk2 <= ~clk2;
    end
end

assign i_clk = ~clk2;

//assign i_reset = reset;

LFSR #(
    .bit_width(5)
) lfsr (
    .clk(clk),
    .next(clk2),
    .reset(reset),
    .out(out)
);

endmodule