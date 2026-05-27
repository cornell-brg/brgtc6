`ifndef BRGTC6_DOWNSTREAM_V4
`define BRGTC6_DOWNSTREAM_V4

`include "pattern/pattern_bypass/PatternChkBypass.sv"
`include "credit/CreditRecvV4.sv"
`include "crc/CrcChk.sv"
`include "repair/RepairDownstream.sv"

//=========================================================================
// Downstream Module Link V4
//=========================================================================
module Downstream #(
    parameter p_bit_width    = 8,
    parameter p_buffer_depth = 8
) (
    input  logic                   clk,
    input  logic                   reset,

    // Config data
    input  logic                   bypass,
    input  logic                   fixed_pattern,
    output logic [p_bit_width-1:0] pattern_1,
    output logic [p_bit_width-1:0] pattern_2,
    output logic [1:0]             state,
    output logic [4:0]             err_count,
    input  logic [p_bit_width-1:0] repair_sel,
    output logic                   crc_error_bit,
    output logic [2:0]             dbg_tick_cnt,

    // Input Credit + Repair + CRC
    input  logic [p_bit_width-1:0] cred_msg,
    input  logic                   cred_val,
    input  logic                   cred_clk,
    input  logic                   cred_rst,
    output logic                   cred_cred,
    input  logic                   cred_crc,
    input  logic                   cred_repair,

    // Output Val/Rdy
    output logic [p_bit_width-1:0] ostream_msg,
    output logic                   ostream_val,
    input  logic                   ostream_rdy
);

// Repair Credit -> CRC
logic [p_bit_width-1:0] repair_crc_msg;
logic                   repair_crc_val;
logic                   repair_crc_clk;
logic                   repair_crc_rst;
logic                   repair_crc_cred;
logic                   repair_crc_crc;

// CRC -> CreditRecv Credit
logic [p_bit_width-1:0] crc_credrecv_msg;
logic                   crc_credrecv_val;
logic                   crc_credrecv_clk;
logic                   crc_credrecv_rst;
logic                   crc_credrecv_cred;

// CreditRecv -> Pattern Val/Rdy
logic [p_bit_width-1:0] credrecv_pattern_msg;
logic                   credrecv_pattern_val;
logic                   credrecv_pattern_rdy;

RepairDownstream #(
    .p_bit_width  (p_bit_width)
) repair (
    .in_cred_msg    (cred_msg),
    .in_cred_val    (cred_val),
    .in_cred_clk    (cred_clk),
    .in_cred_rst    (cred_rst),
    .in_cred_cred   (cred_cred),
    .in_cred_crc    (cred_crc),
    .in_cred_repair (cred_repair),
    .out_cred_msg   (repair_crc_msg),
    .out_cred_val   (repair_crc_val),
    .out_cred_clk   (repair_crc_clk),
    .out_cred_rst   (repair_crc_rst),
    .out_cred_cred  (repair_crc_cred),
    .out_cred_crc   (repair_crc_crc),
    .repair_sel     (repair_sel)
);

CrcChk #(
    .p_bit_width   (p_bit_width)
) crc_chk (
    .clk           (clk),
    .reset         (reset),
    .in_cred_msg   (repair_crc_msg),
    .in_cred_val   (repair_crc_val),
    .in_cred_clk   (repair_crc_clk),
    .in_cred_rst   (repair_crc_rst),
    .in_cred_cred  (repair_crc_cred),
    .in_cred_crc   (repair_crc_crc),
    .out_cred_msg  (crc_credrecv_msg),
    .out_cred_val  (crc_credrecv_val),
    .out_cred_clk  (crc_credrecv_clk),
    .out_cred_rst  (crc_credrecv_rst),
    .out_cred_cred (crc_credrecv_cred),
    .crc_error_bit (crc_error_bit)
);

CreditRecvV4 #(
    .p_bit_width    (p_bit_width),
    .p_buffer_depth (p_buffer_depth)
) credit_recv (
    .clk            (clk),
    .reset          (reset),
    .tick_cnt       (dbg_tick_cnt),
    .cred_msg       (crc_credrecv_msg),
    .cred_val       (crc_credrecv_val),
    .cred_clk       (crc_credrecv_clk),
    .cred_rst       (crc_credrecv_rst),
    .cred_cred      (crc_credrecv_cred),
    .out_msg        (credrecv_pattern_msg),
    .out_val        (credrecv_pattern_val),
    .out_rdy        (credrecv_pattern_rdy)
);

PatternChkBypass #(
    .p_bit_width   (p_bit_width)
) pattern_chk (
    .clk           (clk),
    .reset         (reset),
    .bypass        (bypass),
    .fixed_pattern (fixed_pattern),
    .pattern_1     (pattern_1),
    .pattern_2     (pattern_2),
    .state         (state),
    .err_count     (err_count),
    .istream_msg   (credrecv_pattern_msg),
    .istream_val   (credrecv_pattern_val),
    .istream_rdy   (credrecv_pattern_rdy),
    .ostream_msg   (ostream_msg),
    .ostream_val   (ostream_val),
    .ostream_rdy   (ostream_rdy)
);

endmodule

`endif /* BRGTC6_DOWNSTREAM_V4 */
