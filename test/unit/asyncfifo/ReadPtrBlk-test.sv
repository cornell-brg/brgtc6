`timescale 1ns/1ps

`ifndef BRGTC6_READ_PTR_BLK_UNIT_TEST
`define BRGTC6_READ_PTR_BLK_UNIT_TEST

`include "asyncfifo/ReadPtrBlk.sv"
`include "utils/manual/ManualCheckSingleClkTB.sv"

import "DPI-C" function int get_system_time_seed();

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam            p_num_duts                 = 5;
  localparam integer    p_num_entries[p_num_duts]  = '{4, 8, 16, 32, 64};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      ReadPtrBlockTest #(
        .p_num_entries(p_num_entries[i])
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
// ReadPtrBlockTest
//----------------------------------------------------------------------
module ReadPtrBlockTest # (
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
logic [p_ptr_width-1:0] b_read_ptr;
logic [p_ptr_width-1:0] g_read_ptr;
logic [p_ptr_width-1:0] g_write_ptr_async;

// Control signals
logic r_en;
logic empty;

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
ManualCheckSingleClkTB #(
  .p_chk_nbits(p_chk_nbits)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
ReadPtrBlk #(
  .p_num_entries(p_num_entries)
) dut (
  .async_rst(reset),
  .*
);

//----------------------------------------------------------------------
// test_simple_pointer_movement - test basic movement of pointers and empty
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
    rst_delay,
    seed
  );
  r_en = 0;
  g_write_ptr_async = 0;
  @(posedge clk);
  @(posedge clk);

  // Initialize inputs and propagate asynchronous write pointer through synchronizer
  @(negedge clk);
  g_write_ptr_async = 1;
  @(posedge clk);
  @(posedge clk);

  // Confirm write pointer movement and no longer empty
  @(negedge clk);
  tb.test_case_check(1, dut.g_write_ptr, "g_write_ptr");
  tb.test_case_check(0, empty, "empty");

  // Send read command and confirm read pointer movement, empty again
  @(negedge clk);
  r_en = 1;
  #1;
  tb.test_case_check(1, dut.b_read_ptr_next, "b_read_ptr_next");
  tb.test_case_check(1, dut.g_read_ptr_next, "g_read_ptr_next");
  @(negedge clk);
  tb.test_case_check(1, b_read_ptr, "b_read_ptr");
  tb.test_case_check(1, g_read_ptr, "g_read_ptr");
  tb.test_case_check(1, empty, "empty");

  // Set asynchronous write pointer and wait for sync, no longer empty
  #(1 + ($urandom() % (p_max_wait_cycles)));
  g_write_ptr_async = 2;
  @(posedge clk);
  @(posedge clk);
  @(negedge clk);
  tb.test_case_check(2, dut.g_write_ptr, "g_write_ptr");
  tb.test_case_check(0, empty, "empty");

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_ne_%0d", p_num_entries);
  tb.test_bench_start($sformatf("ReadPtrBlkTest%s", suffix));

  if (tb.test_case == 1  || tb.test_case == 0) test_simple_pointer_movement($sformatf("test_basic_movement%s", suffix));

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
