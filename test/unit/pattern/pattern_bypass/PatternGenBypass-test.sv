`timescale 1ns/1ps

`ifndef BRGTC6_PAT_GEN_BY_TEST
`define BRGTC6_PAT_GEN_BY_TEST

`include "utils/manual/ManualCheckSingleClkTB.sv"
`include "pattern/pattern_bypass/PatternGenBypass.sv"

import "DPI-C" function int get_system_time_seed();

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam            p_num_duts               = 3;
  localparam integer    p_bit_widths[p_num_duts] = '{4, 8, 16};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  // Generate test benches
  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      PatternGenBypassTest #(
        .p_bit_width(p_bit_widths[i])
      ) test (
        .go(tb_go[i]),
        .done(tb_done[i]),
        .pass(tb_pass[i])
      );
    end
  endgenerate

  // Start test benches
  always begin
    #1; // wait for initial values to propagate
    for (int idx = 0; idx < p_num_duts; idx++) begin
      if (tb_done[idx] == 0) tb_go[idx] <= 1;
    end
  end

  // Wait for all test benches to finish and check results
  initial begin
    bit all_done = 0, all_pass = 0;
    #1; // wait for initial values to propagate
    while(!all_done) begin
      all_done = 1;
      for (int idx = 0; idx < p_num_duts; idx++) begin
        if (tb_done[idx] == 0) all_done = 0;
      end
      #1;
    end
    all_pass = 1;
    for (int idx = 0; idx < p_num_duts; idx++) begin
      if (tb_pass[idx] == 0) all_pass = 0;
    end
    if (all_pass) begin
      $write($sformatf("\n\n%s----------------------------%s\n", `BRGTC6_GREEN, `BRGTC6_RESET));
      $write($sformatf("%s------ OVERALL PASSED ------%s\n", `BRGTC6_GREEN, `BRGTC6_RESET));
      $write($sformatf("%s----------------------------%s\n\n", `BRGTC6_GREEN, `BRGTC6_RESET));
      $finish(0);
    end
    else begin
      $write($sformatf("\n\n%s----------------------------%s\n", `BRGTC6_RED, `BRGTC6_RESET));
      $write($sformatf("%s------ OVERALL FAILED ------%s\n", `BRGTC6_RED, `BRGTC6_RESET));
      $write($sformatf("%s----------------------------%s\n\n", `BRGTC6_RED, `BRGTC6_RESET));
      $finish(1);
    end
  end
endmodule

//----------------------------------------------------------------------
// PatternGenBypassTest
//----------------------------------------------------------------------
module PatternGenBypassTest #(
  parameter p_bit_width = 5,
  parameter p_clk_pd    = 10,
  parameter p_rst_delay = 30
) (
  input  logic go,
  output logic done,
  output logic pass
);

logic                   clk;
logic                   reset;

// Source side
logic                   src_val;
logic                   src_rdy;
logic [p_bit_width-1:0] src_msg;

// Sink side
logic                   sink_val;
logic                   sink_rdy;
logic [p_bit_width-1:0] sink_msg;

logic [p_bit_width-1:0] istream_msg;
logic                   istream_val;
logic                   istream_rdy;

logic                   bypass;
logic                   fixed_pattern;

logic [p_bit_width-1:0] pattern_1;
logic [p_bit_width-1:0] pattern_2;

logic [p_bit_width-1:0] ostream_msg;
logic                   ostream_val;
logic                   ostream_rdy;

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
ManualCheckSingleClkTB #(
  .p_chk_nbits(p_bit_width),
  .p_timeout_period(1000000)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
PatternGenBypass #(
  .p_bit_width(p_bit_width)
) dut ( .* );

//----------------------------------------------------------------------
// test_basic_bypass
//----------------------------------------------------------------------
task automatic test_basic_bypass (
  string  name,
  integer seed = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);
  integer sent_msg = 0;

  // Synchronous reset
  @(posedge clk);
  tb.test_case_begin (
    name,
    p_clk_pd,
    p_rst_delay,
    seed
  );

  ostream_rdy = 1;
  istream_val = 1;
  istream_msg = {p_bit_width{1'b1}};
  bypass = 1;
  pattern_1 = {p_bit_width{1'b1}};
  pattern_2 = {p_bit_width{1'b0}};
  fixed_pattern = 0;
  #1;

  // istream_rdy should track ostream_rdy for bypass
  tb.test_case_check(ostream_rdy, istream_rdy, "rdy");
  #1;
  ostream_rdy = 0;
  #1
  tb.test_case_check(ostream_rdy, istream_rdy, "rdy");

  // ostream_val should track istream_val for bypass
  tb.test_case_check(istream_val, ostream_val, "val");
  #1;
  istream_val = 0;
  #1
  tb.test_case_check(istream_val, ostream_val, "val");

  // ostream_msg should track istream_msg for bypass
  tb.test_case_check(istream_msg, ostream_msg, "msg");
  #1;
  istream_msg = {p_bit_width{1'b0}};
  #1
  tb.test_case_check(istream_msg, ostream_msg, "msg");

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_bw_%0d", p_bit_width);
  tb.test_bench_start($sformatf("PatternGenBypassTest%s", suffix));
  
  if (tb.test_case == 1  || tb.test_case == 0) test_basic_bypass($sformatf("basic_bypass%s", suffix));

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif /* BRGTC6_PAT_GEN_BY_TEST */
