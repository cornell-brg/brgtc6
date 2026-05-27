`timescale 1ns/1ps

`ifndef BRGTC6_WRITE_PTR_BLK_UNIT_TEST
`define BRGTC6_WRITE_PTR_BLK_UNIT_TEST

`include "asyncfifo/WritePtrBlk.sv"
`include "utils/manual/ManualCheckSingleClkTB.sv"

import "DPI-C" function int get_system_time_seed();

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam            p_num_duts                     = 5;
  localparam integer    p_num_entries[p_num_duts]      = '{4, 8, 16, 32, 64};
  localparam integer    p_max_clock_period[p_num_duts] = '{64, 64, 64, 64, 64};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      WritePtrBlkTest #(
        .p_num_entries(p_num_entries[i]),
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
// WritePtrBlkTest
//----------------------------------------------------------------------
module WritePtrBlkTest # (
  parameter p_chk_nbits        = 8,
  parameter p_num_entries      = 8,
  parameter p_ptr_width        = $clog2(p_num_entries) + 1,
  parameter p_max_clock_period = 100,
  parameter p_max_rst_delay    = 100,
  parameter p_max_wait_cycles  = 100
)(
  input  logic go,
  output logic done,
  output logic pass
);

logic clk;
logic reset;

// Pointers
logic [p_ptr_width-1:0] b_write_ptr;
logic [p_ptr_width-1:0] g_write_ptr;
logic [p_ptr_width-1:0] g_read_ptr_async;

// Control signals
logic w_en;
logic full;

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
ManualCheckSingleClkTB #(
  .p_chk_nbits(p_chk_nbits)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
WritePtrBlk #(
  .p_num_entries(p_num_entries)
) dut (
  .async_rst(reset),
  .*
);

//----------------------------------------------------------------------
// test_simple_pointer_movement - test basic movement of pointers
//----------------------------------------------------------------------
task automatic test_simple_pointer_movement (
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
    rst_delay
  );
  w_en = 0;
  g_read_ptr_async = 0;
  @(posedge clk);
  @(posedge clk);

  // Initialize inputs and propagate asynchronous read pointer through synchronizer
  @(negedge clk);
  g_read_ptr_async = 1;
  @(posedge clk);
  @(posedge clk);

  // Confirm read pointer movement and still not full (asynchronous)
  @(negedge clk);
  tb.test_case_check(1, dut.g_read_ptr, "g_read_ptr");
  tb.test_case_check(0, full, "full");

  // Next write pointers increment combinationally with w_en
  // No posedge has passed so write pointers should not have updated
  @(negedge clk);
  w_en = 1;
  #1
  tb.test_case_check(1, dut.b_write_ptr_next, "b_write_ptr_next");
  tb.test_case_check(1, dut.g_write_ptr_next, "g_write_ptr_next");
  tb.test_case_check(0, b_write_ptr, "b_write_ptr");
  tb.test_case_check(0, g_write_ptr, "g_write_ptr");

  // Posedge has passed, so write pointers should have updated
  // Write enable is zero so next write pointers should not have changed
  // Read pointer should have updated (synchronous)
  @(negedge clk);
  g_read_ptr_async = 4;
  w_en = 0;
  #1
  tb.test_case_check(1, dut.b_write_ptr_next, "b_write_ptr_next");
  tb.test_case_check(1, dut.g_write_ptr_next, "g_write_ptr_next");
  tb.test_case_check(1, b_write_ptr, "b_write_ptr");
  tb.test_case_check(1, g_write_ptr, "g_write_ptr");
  tb.test_case_check(0, full, "full");
  @(posedge clk);
  @(posedge clk);
  @(negedge clk);
  tb.test_case_check(4, dut.g_read_ptr, "g_read_ptr");

  // Write enable is one so next write pointers should have changed
  // No posedge has passed so write pointers should not have updated
  @(negedge clk);
  w_en = 1;
  #1
  tb.test_case_check(2, dut.b_write_ptr_next, "b_write_ptr_next");
  tb.test_case_check(3, dut.g_write_ptr_next, "g_write_ptr_next");
  tb.test_case_check(1, b_write_ptr, "b_write_ptr");
  tb.test_case_check(1, g_write_ptr, "g_write_ptr");
  tb.test_case_check(0, full, "full");

  #100;
endtask

//----------------------------------------------------------------------
// test_full - test full condition
//----------------------------------------------------------------------
task automatic test_full (
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
  w_en = 0;
  g_read_ptr_async = 0;
  @(posedge clk);
  @(posedge clk);

  // Confirm empty
  @(negedge clk);
  tb.test_case_check(0, dut.g_read_ptr, "g_read_ptr");
  tb.test_case_check(0, full, "full");

  @(negedge clk);

  // Set asynchronous read pointer and wait for sync, now full
  for (int i = 0; i < p_num_entries; i++) begin
    #(1 + ($urandom() % (p_max_wait_cycles)));
    @(negedge clk);
    w_en = 1;
    @(negedge clk);
    w_en = 0;
  end
  tb.test_case_check(1, full, "full");

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_mcp_%0d_ne_%0d", p_max_clock_period, p_num_entries);
  tb.test_bench_start($sformatf("WritePtrBlkTest%s", suffix));

  if (tb.test_case == 1  || tb.test_case == 0) test_simple_pointer_movement($sformatf("test_basic_movement%s", suffix));
  if (tb.test_case == 2  || tb.test_case == 0) test_full($sformatf("test_basic_full%s", suffix));

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
