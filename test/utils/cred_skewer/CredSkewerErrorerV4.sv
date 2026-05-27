`ifndef BRGTC6_TEST_BENCH_CRED_SKEWER_ERRORER_V4
`define BRGTC6_TEST_BENCH_CRED_SKEWER_ERRORER_V4

`timescale 1ns/1ps

`include "utils/cred_skewer/SkewShreg.sv"

`ifndef BRGTC6_TIME_SEED
`define BRGTC6_TIME_SEED
import "DPI-C" function int get_system_time_seed();
`endif

//----------------------------------------------------------------------
// CredSkewerErrorerV4 - configurable fixed skew and error on each bit of interface for V4 link
//----------------------------------------------------------------------
/*verilator coverage_off*/
module CredSkewerErrorerV4 #(
  parameter p_msg_nbits = 8,
  parameter p_max_skew  = 50 // all input skews must be <= p_max_skew
)(
  input  logic                   en,

  // Config signals
  input  logic [31:0]            msg_skews [p_msg_nbits],
  input  logic [31:0]            val_skew,
  input  logic [31:0]            clk_skew,
  input  logic [31:0]            rst_skew,
  input  logic [31:0]            cred_skew,
  input  logic [31:0]            crc_skew,
  input  logic [31:0]            repair_skew,
  input  logic [p_msg_nbits+4:0] error_en, // bit set - 0: CRC, 1: Cred, 2: Rst, 3: Clk, 4: Val, 5+: Msg

  // Input side
  input  logic [p_msg_nbits-1:0] up_cred_msg,
  input  logic                   up_cred_val,
  input  logic                   up_cred_clk,
  input  logic                   up_cred_rst,
  output logic                   up_cred_cred,
  input  logic                   up_cred_crc,
  input  logic                   up_cred_repair,

  // Output side
  output logic [p_msg_nbits-1:0] down_cred_msg,
  output logic                   down_cred_val,
  output logic                   down_cred_clk,
  output logic                   down_cred_rst,
  input  logic                   down_cred_cred,
  output logic                   down_cred_crc,
  output logic                   down_cred_repair
);

// Sim clock
logic sim_clk;
initial sim_clk = 1'b0;
always #(500ps) sim_clk <= ~sim_clk;

// Msg skew and error
logic [p_msg_nbits-1:0] int_cred_msg;
genvar i;
generate
  for (i = 0; i < p_msg_nbits; i++) begin : gen_skew_error
    SkewShreg #(
      .p_max_stages(p_max_skew)
    ) skew (
      .clk(sim_clk),
      .data_in(up_cred_msg[i]),
      .en(en),
      .stage_num(msg_skews[i]),
      .data_out(int_cred_msg[i])
    );

    assign down_cred_msg[i] = (error_en[i+5] ? 1'b0 : int_cred_msg[i]);

  end
endgenerate

// Val
logic int_cred_val;

SkewShreg #(
  .p_max_stages(p_max_skew)
) val_skew_shreg (
  .clk(sim_clk),
  .data_in(up_cred_val),
  .en(en),
  .stage_num(val_skew),
  .data_out(int_cred_val)
);

assign down_cred_val = (error_en[4] ? 1'b0 : int_cred_val);

// Clk
logic int_cred_clk;

SkewShreg #(
  .p_max_stages(p_max_skew)
) clk_skew_shreg (
  .clk(sim_clk),
  .data_in(up_cred_clk),
  .en(en),
  .stage_num(clk_skew),
  .data_out(int_cred_clk)
);

assign down_cred_clk = (error_en[3] ? 1'b0 : int_cred_clk);

// Rst
logic int_cred_rst;

SkewShreg #(
  .p_max_stages(p_max_skew)
) rst_skew_shreg (
  .clk(sim_clk),
  .data_in(up_cred_rst),
  .en(en),
  .stage_num(rst_skew),
  .data_out(int_cred_rst)
);

assign down_cred_rst = (error_en[2] ? 1'b0 : int_cred_rst);

// Cred
logic int_cred_cred;

SkewShreg #(
  .p_max_stages(p_max_skew)
) cred_skew_shreg (
  .clk(sim_clk),
  .data_in(down_cred_cred),
  .en(en),
  .stage_num(cred_skew),
  .data_out(int_cred_cred)
);

assign up_cred_cred = (error_en[1] ? 1'b0 : int_cred_cred);

// CRC
logic int_cred_crc;

SkewShreg #(
  .p_max_stages(p_max_skew)
) crc_skew_shreg (
  .clk(sim_clk),
  .data_in(up_cred_crc),
  .en(en),
  .stage_num(crc_skew),
  .data_out(int_cred_crc)
);

assign down_cred_crc = (error_en[0] ? 1'b0 : int_cred_crc);

// Repair
SkewShreg #(
  .p_max_stages(p_max_skew)
) repair_skew_shreg (
  .clk(sim_clk),
  .data_in(up_cred_repair),
  .en(en),
  .stage_num(repair_skew),
  .data_out(down_cred_repair)
);

endmodule
/*verilator coverage_on*/

`endif
