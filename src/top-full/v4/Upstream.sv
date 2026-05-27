`ifndef BRGTC6_UPSTREAM_V4
`define BRGTC6_UPSTREAM_V4

`include "pattern/pattern_bypass/PatternGenBypass.sv"
`include "credit/CreditSendV4.sv"
`include "crc/CrcGen.sv"
`include "repair/RepairUpstream.sv"

//=========================================================================
// Upstream Module Link V4
//=========================================================================
module Upstream #(
    parameter p_bit_width  = 8,
    parameter p_max_credit = 8,
    parameter p_clk_width  = 4
) (
    input  logic                   clk,
    input  logic                   reset,

    // Config data
    input  logic                   bypass,
    input  logic                   fixed_pattern,
    input  logic [p_clk_width-1:0] clk_div,
    input  logic [p_clk_width-1:0] clk_skew,
    input  logic [p_bit_width-1:0] pattern_1,
    input  logic [p_bit_width-1:0] pattern_2,
    input  logic [p_bit_width-1:0] repair_sel,
    output logic [$clog2(p_max_credit+1)-1:0] dbg_next_cred_cnt,
    output logic [1:0]             dbg_cred_rst_delay,

    // Input Val/Rdy
    input  logic [p_bit_width-1:0] istream_msg,
    input  logic                   istream_val,
    output logic                   istream_rdy,

    // Output Credit + Repair + CRC
    output logic [p_bit_width-1:0] cred_msg,
    output logic                   cred_val,
    output logic                   cred_clk,
    output logic                   cred_rst,
    input  logic                   cred_cred,
    output logic                   cred_crc,
    output logic                   cred_repair
);

// Pattern -> CreditSend Val/Rdy
logic [p_bit_width-1:0] pattern_credsend_msg;
logic                   pattern_credsend_val;
logic                   pattern_credsend_rdy;

// CreditSend -> CRC Credit
logic [p_bit_width-1:0] credsend_crc_msg;
logic                   credsend_crc_val;
logic                   credsend_crc_clk;
logic                   credsend_crc_rst;
logic                   credsend_crc_cred;

// CRC -> Repair Credit
logic [p_bit_width-1:0] crc_repair_msg;
logic                   crc_repair_val;
logic                   crc_repair_clk;
logic                   crc_repair_rst;
logic                   crc_repair_cred;
logic                   crc_repair_crc;

PatternGenBypass #(
    .p_bit_width   (p_bit_width)
) pattern_gen (
    .clk           (clk),
    .reset         (reset),
    .bypass        (bypass),
    .fixed_pattern (fixed_pattern),
    .istream_msg   (istream_msg),
    .istream_val   (istream_val),
    .istream_rdy   (istream_rdy),
    .pattern_1     (pattern_1),
    .pattern_2     (pattern_2),
    .ostream_msg   (pattern_credsend_msg),
    .ostream_val   (pattern_credsend_val),
    .ostream_rdy   (pattern_credsend_rdy)
);

CreditSendV4 #(
    .p_bit_width  (p_bit_width),
    .p_max_credit (p_max_credit),
    .p_clk_width  (p_clk_width)
) credit_send (
    .clk         (clk),
    .reset       (reset),
    .clk_div     (clk_div),
    .clk_skew    (clk_skew),
    .dbg_next_cred_cnt (dbg_next_cred_cnt),
    .cred_rst_delay (dbg_cred_rst_delay),
    .in_msg      (pattern_credsend_msg),
    .in_val      (pattern_credsend_val),
    .in_rdy      (pattern_credsend_rdy),
    .cred_msg    (credsend_crc_msg),
    .cred_val    (credsend_crc_val),
    .cred_clk    (credsend_crc_clk),
    .cred_rst    (credsend_crc_rst),
    .cred_cred   (credsend_crc_cred)
);

CrcGen #(
    .p_bit_width   (p_bit_width)
) crc_gen (
    .in_cred_msg   (credsend_crc_msg),
    .in_cred_val   (credsend_crc_val),
    .in_cred_clk   (credsend_crc_clk),
    .in_cred_rst   (credsend_crc_rst),
    .in_cred_cred  (credsend_crc_cred),
    .out_cred_msg  (crc_repair_msg),
    .out_cred_val  (crc_repair_val),
    .out_cred_clk  (crc_repair_clk),
    .out_cred_rst  (crc_repair_rst),
    .out_cred_cred (crc_repair_cred),
    .out_cred_crc  (crc_repair_crc)
);

RepairUpstream #(
    .p_bit_width     (p_bit_width)
) repair (
    .in_cred_msg     (crc_repair_msg),
    .in_cred_val     (crc_repair_val),
    .in_cred_clk     (crc_repair_clk),
    .in_cred_rst     (crc_repair_rst),
    .in_cred_cred    (crc_repair_cred),
    .in_cred_crc     (crc_repair_crc),
    .out_cred_msg    (cred_msg),
    .out_cred_val    (cred_val),
    .out_cred_clk    (cred_clk),
    .out_cred_rst    (cred_rst),
    .out_cred_cred   (cred_cred),
    .out_cred_crc    (cred_crc),
    .out_cred_repair (cred_repair),
    .repair_sel      (repair_sel)
);

endmodule

`endif /* BRGTC6_UPSTREAM_V4 */
