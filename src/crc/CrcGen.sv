`ifndef BRGTC6_CRC_GEN
`define BRGTC6_CRC_GEN

//=========================================================================
// CRC Generation Mechanism
//=========================================================================
module CrcGen #(
  parameter p_bit_width = 8
) (

    // input credit interface
    input  logic [p_bit_width-1:0] in_cred_msg,
    input  logic                   in_cred_val,
    input  logic                   in_cred_clk,
    input  logic                   in_cred_rst,
    output logic                   in_cred_cred,

    // output credit interface
    output logic [p_bit_width-1:0] out_cred_msg,
    output logic                   out_cred_val,
    output logic                   out_cred_clk,
    output logic                   out_cred_rst,
    input  logic                   out_cred_cred,
    output logic                   out_cred_crc
);

// even parity
assign out_cred_crc = ^in_cred_msg;

// passthrough
assign out_cred_msg = in_cred_msg;
assign out_cred_val = in_cred_val;
assign out_cred_clk = in_cred_clk;
assign out_cred_rst = in_cred_rst;
assign in_cred_cred = out_cred_cred;

endmodule

`endif /* BRGTC6_CRC_GEN */
