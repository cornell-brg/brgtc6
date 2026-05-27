`ifndef BRGTC6_TEST_BENCH_CRED_SKEWER
`define BRGTC6_TEST_BENCH_CRED_SKEWER

`timescale 1ns/1ps

`include "utils/cred_skewer/SkewShreg.sv"

`ifndef BRGTC6_TIME_SEED
`define BRGTC6_TIME_SEED
import "DPI-C" function int get_system_time_seed();
`endif

//----------------------------------------------------------------------
// CredSkewer - configurable fixed skew on each bit of interface
//----------------------------------------------------------------------
/*verilator coverage_off*/
module CredSkewer #(
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

  // Input side
  input  logic [p_msg_nbits-1:0] up_cred_msg,
  input  logic                   up_cred_val,
  input  logic                   up_cred_clk,
  input  logic                   up_cred_rst,
  output logic                   up_cred_cred,

  // Output side
  output logic [p_msg_nbits-1:0] down_cred_msg,
  output logic                   down_cred_val,
  output logic                   down_cred_clk,
  output logic                   down_cred_rst,
  input  logic                   down_cred_cred
);

// Sim clock
logic sim_clk;
initial sim_clk = 1'b0;
always #(500ps) sim_clk <= ~sim_clk;

// Msg
genvar i;
generate
  for (i = 0; i < p_msg_nbits; i++) begin : gen_skew
    SkewShreg #(
      .p_max_stages(p_max_skew)
    ) skew (
      .clk(sim_clk),
      .data_in(up_cred_msg[i]),
      .en(en),
      .stage_num(msg_skews[i]),
      .data_out(down_cred_msg[i])
    );
  end
endgenerate

// Val
SkewShreg #(
  .p_max_stages(p_max_skew)
) val_skew_shreg (
  .clk(sim_clk),
  .data_in(up_cred_val),
  .en(en),
  .stage_num(val_skew),
  .data_out(down_cred_val)
);

// Clk
SkewShreg #(
  .p_max_stages(p_max_skew)
) clk_skew_shreg (
  .clk(sim_clk),
  .data_in(up_cred_clk),
  .en(en),
  .stage_num(clk_skew),
  .data_out(down_cred_clk)
);

// Rst
SkewShreg #(
  .p_max_stages(p_max_skew)
) rst_skew_shreg (
  .clk(sim_clk),
  .data_in(up_cred_rst),
  .en(en),
  .stage_num(rst_skew),
  .data_out(down_cred_rst)
);

// Cred
SkewShreg #(
  .p_max_stages(p_max_skew)
) cred_skew_shreg (
  .clk(sim_clk),
  .data_in(down_cred_cred),
  .en(en),
  .stage_num(cred_skew),
  .data_out(up_cred_cred)
);

endmodule
/*verilator coverage_on*/

`endif
