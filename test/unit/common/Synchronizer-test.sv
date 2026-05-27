`timescale 1ns/1ps

`ifndef BRGTC6_SYNCHRONIZER_UNIT_TEST
`define BRGTC6_SYNCHRONIZER_UNIT_TEST

`include "common/Synchronizer.sv"
`include "utils/manual/ManualCheckSingleClkTB.sv"

import "DPI-C" function int get_system_time_seed();

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam            p_num_duts                = 5;
  localparam integer    p_bit_widths[p_num_duts]  = '{4, 8, 16, 32, 64};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  // Generate test benches
  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      SynchronizerTest #(
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
// SynchronizerTest
//----------------------------------------------------------------------
module SynchronizerTest # (
  parameter p_bit_width        = 8,
  parameter p_max_clock_period = 100,
  parameter p_max_rst_delay    = 100,
  parameter p_max_wait_cycles  = 100
)(
  input  logic go,
  output logic done,
  output logic pass
);

logic                   clk;
logic                   reset;
logic [p_bit_width-1:0] d;
logic [p_bit_width-1:0] q;

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
ManualCheckSingleClkTB #(
  .p_chk_nbits(p_bit_width)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
Synchronizer #(
  .p_bit_width(p_bit_width)
) dut ( .* );

//----------------------------------------------------------------------
// test_standard
//----------------------------------------------------------------------
task automatic test_standard (
  string  name,
  integer clk_period = -1,
  integer rst_delay  = -1,
  integer seed       = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  if (clk_period == -1) clk_period = 2 + ($urandom() % (p_max_clock_period - 1));
  if (rst_delay  == -1) rst_delay  = clk_period + ($urandom() % (p_max_rst_delay - clk_period + 1));

  // Initialize test case (synchronous reset)
  @(posedge clk);
  tb.test_case_begin (
    name,
    clk_period,
    rst_delay,
    seed
  );
  d = {p_bit_width{1'b0}};

  // s and q should be 0 upon exiting reset
  tb.test_case_check(0, dut.s, "s");
  tb.test_case_check(0, q, "q");
  tb.test_case_check(0, reset, "reset");

  #(1 + ($urandom() % (p_max_wait_cycles)));

  // test with a single element - assert asynchronously (make sure positive on
  // the next clock edge)
  d = {p_bit_width{1'b1}};
  @(posedge clk);
  #1;
  d = {p_bit_width{1'b0}};
  tb.test_case_check({p_bit_width{1'b1}}, dut.s, "s");
  tb.test_case_check(0, q, "q");
  @(posedge clk);
  @(negedge clk);
  tb.test_case_check(0, dut.s, "s");
  tb.test_case_check({p_bit_width{1'b1}}, q, "q");
  @(negedge clk);
  tb.test_case_check(0, dut.s, "s");
  tb.test_case_check(0, q, "q");

  #100;
endtask

//----------------------------------------------------------------------
// test_close_to_edge
//----------------------------------------------------------------------
task automatic test_close_to_edge (
  string  name,
  integer clk_period = -1,
  integer rst_delay  = -1,
  integer seed       = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  integer clk_cntr;

  if (clk_period == -1) clk_period = 2 + ($urandom() % (p_max_clock_period - 1));
  if (rst_delay  == -1) rst_delay  = clk_period + ($urandom() % (p_max_rst_delay - clk_period + 1));

  // Initialize test case (synchronous reset)
  @(posedge clk);
  tb.test_case_begin (
    name,
    clk_period,
    rst_delay,
    seed
  );
  d = {p_bit_width{1'b0}};

  // s and q should be 0 upon exiting reset
  tb.test_case_check(0, dut.s, "s");
  tb.test_case_check(0, q, "q");
  tb.test_case_check(0, reset, "reset");

  #(1 + ($urandom() % (p_max_wait_cycles)));

  // wait for one cycle before next positive edge before asserting
  @(negedge clk);
  clk_cntr = 0;
  while (clk_cntr < clk_period/2 - 1) begin
    clk_cntr = clk_cntr + 1;
    #1;
  end

  // test with a single element - assert asynchronously (make sure positive on
  // the next clock edge)
  d = {p_bit_width{1'b1}};
  @(posedge clk);
  #1;
  d = {p_bit_width{1'b0}};
  tb.test_case_check({p_bit_width{1'b1}}, dut.s, "s");
  tb.test_case_check(0, q, "q");
  @(posedge clk);
  @(negedge clk);
  tb.test_case_check(0, dut.s, "s");
  tb.test_case_check({p_bit_width{1'b1}}, q, "q");
  @(negedge clk);
  tb.test_case_check(0, dut.s, "s");
  tb.test_case_check(0, q, "q");

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_bw_%0d", p_bit_width);
  tb.test_bench_start($sformatf("SynchronizerTest%s", suffix));
  
  // One element
  if (tb.test_case == 1  || tb.test_case == 0) test_standard($sformatf("random_assert%s", suffix));
  if (tb.test_case == 2  || tb.test_case == 0) test_close_to_edge($sformatf("assert_1_tick_before%s", suffix));

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
