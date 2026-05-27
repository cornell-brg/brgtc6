`ifndef BRGTC6_DOWNSTREAM_V1
`define BRGTC6_DOWNSTREAM_V1

//=========================================================================
// Downstream Module Link V1
//=========================================================================
`include "credit/CreditRecv.sv"

module Downstream #(
    parameter bit_width = 5,
    parameter buffer_depth = 8
) (
    input  logic                   clk,
    input  logic                   reset,

    // Output 
    output logic [bit_width-1:0]   ostream_msg,
    output logic                   ostream_val,
    input  logic                   ostream_rdy,

    // Credit interface
    input  logic [bit_width-1:0]   cred_msg,
    input  logic                   cred_val,
    input  logic                   cred_clk,
    input  logic                   cred_rst,
    output logic                   cred_cred
);

CreditRecv #(
    .p_bit_width(bit_width),
    .p_buffer_depth(buffer_depth)
) credit_recv (
    .clk(clk),
    .reset(reset),
    .out_msg(ostream_msg),
    .out_val(ostream_val),
    .out_rdy(ostream_rdy),
    .cred_msg(cred_msg),
    .cred_val(cred_val),
    .cred_clk(cred_clk),
    .cred_rst(cred_rst),
    .cred_cred(cred_cred)
);

endmodule

`endif /* BRGTC6_DOWNSTREAM_V1 */
