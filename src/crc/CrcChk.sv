`ifndef BRGTC6_CRC_CHK
`define BRGTC6_CRC_CHK

`include "common/Synchronizer.sv"

//=========================================================================
// CRC Checking Mechanism - can only detect off number of errors
//=========================================================================
module CrcChk #(
  parameter p_bit_width = 8
) (
    input  logic                   clk,
    input  logic                   reset,

    // input credit interface
    input  logic [p_bit_width-1:0] in_cred_msg,
    input  logic                   in_cred_val,
    input  logic                   in_cred_clk,
    input  logic                   in_cred_rst,
    output logic                   in_cred_cred,
    input  logic                   in_cred_crc,

    // output credit interface
    output logic [p_bit_width-1:0] out_cred_msg,
    output logic                   out_cred_val,
    output logic                   out_cred_clk,
    output logic                   out_cred_rst,
    input  logic                   out_cred_cred,

    // CRC error bit to config
    output logic                   crc_error_bit
);

// even parity
logic async_crc_error_bit;

always @(posedge in_cred_clk) begin
    if (in_cred_rst | reset) async_crc_error_bit <= 1'b0;
    else if ((^({in_cred_msg, in_cred_crc})) == 1'b1) async_crc_error_bit <= 1'b1;
end

Synchronizer #(
  .p_bit_width(1)
) crc_error_synch (
  .clk(clk),
  .reset(reset),
  .d(async_crc_error_bit),
  .q(crc_error_bit)
);

// passthrough
assign out_cred_msg = in_cred_msg;
assign out_cred_val = in_cred_val;
assign out_cred_clk = in_cred_clk;
assign out_cred_rst = in_cred_rst;
assign in_cred_cred = out_cred_cred;

endmodule

`endif /* BRGTC6_CRC_CHK */
