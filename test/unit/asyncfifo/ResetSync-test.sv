`timescale 1ns/1ps

`ifndef BRGTC6_RESET_SYNC_UNIT_TEST
`define BRGTC6_RESET_SYNC_UNIT_TEST

`include "asyncfifo/ResetSync.sv"
`include "utils/manual/ManualCheckSingleClkTB.sv"

import "DPI-C" function int get_system_time_seed();

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam            p_num_duts                      = 5;
  localparam integer    p_max_clock_period[p_num_duts]  = '{64, 128, 256, 512, 1024};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      ResetSyncTest #(
        .p_max_clock_period(p_max_clock_period[i])
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
        if (tb_done[idx] == 0) begin
          all_done = 0;
        end
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
// ResetSyncTest
//----------------------------------------------------------------------
module ResetSyncTest # (
  parameter p_chk_nbits        = 8,
  parameter p_max_clock_period = 100,
  parameter p_max_rst_delay    = 100,
  parameter p_max_wait_cycles  = 100
)(
  input  logic go,
  output logic done,
  output logic pass
);

logic clk;
logic async_reset;
logic reset;

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
ManualCheckSingleClkTB #(
  .p_chk_nbits(p_chk_nbits)  
) tb (
  .clk(clk),
  .reset(async_reset),
  .*
);

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
ResetSync dut (
  .clk(clk),
  .async_rst(async_reset), 
  .reset(reset)
);

//----------------------------------------------------------------------
// test_basic_async_reset - test basic async reset functionality
//----------------------------------------------------------------------
task automatic test_basic_async_reset (
  string name,
  integer clk_period = -1,
  integer rst_delay  = -1,
  integer seed       = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  if (clk_period == -1) clk_period = 2 + ($urandom() % (p_max_clock_period - 1));
  if (rst_delay  == -1) rst_delay  = 1 + ($urandom() % (p_max_rst_delay));

  // Initialize test case and ensure async reset is propagated through synchronizer
  tb.test_case_begin (
    name,
    clk_period,
    rst_delay,
    seed
  );
  
  // steady state - all zeros
  @(posedge clk);
  @(posedge clk);
  @(negedge clk);
  tb.test_case_check(0, dut.reg1, "reg1");
  tb.test_case_check(0, dut.reg2, "reg2");
  tb.test_case_check(0, reset, "reset");

  #(1 + ($urandom() % (p_max_wait_cycles)));

  // async reset - all ones
  @(negedge clk);
  tb.do_reset(1);
  #1;
  tb.test_case_check(1, dut.reg1, "reg1");
  tb.test_case_check(1, dut.reg2, "reg2");
  tb.test_case_check(1, reset, "reset");

  // wait for one clock cycle, reg 1 should have propagated a zero
  @(posedge clk);
  @(negedge clk);
  tb.test_case_check(0, dut.reg1, "reg1");
  tb.test_case_check(1, dut.reg2, "reg2");
  tb.test_case_check(1, reset, "reset");

  // wait for one clock cycle, reg 2 should have propagated a zero, reset is zero
  @(negedge clk);
  tb.test_case_check(0, dut.reg1, "reg1");
  tb.test_case_check(0, dut.reg2, "reg2");
  tb.test_case_check(0, reset, "reset");

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_mcp_%0d", p_max_clock_period);
  tb.test_bench_start($sformatf("ResetSyncTest%s", suffix));

  if (tb.test_case == 1  || tb.test_case == 0) test_basic_async_reset($sformatf("test_basic_async_reset%s", suffix));

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
