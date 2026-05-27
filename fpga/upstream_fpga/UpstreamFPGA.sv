`include "top-full/Upstream.sv"
`include "../Hex5.sv"

module UpstreamFPGA (
    input   logic       reset_n,
    input  logic        clk,
    output logic [4:0]  cred_msg,
    output logic        cred_val,
    output logic        cred_clk,
    output logic        cred_rst,
    input  logic        cred_cred
);

logic reset;
assign reset = ~reset_n;

Upstream #(
    .bit_width(5),
    .max_cred(8),
    .clk_width(4)
) upstream (
    .clk(clk),
    .reset(reset),
    .cred_msg(cred_msg),
    .cred_val(cred_val),
    .cred_clk(cred_clk),
    .cred_rst(cred_rst),
    .cred_cred(cred_cred)
);

endmodule