`timescale 1ns/1ps

`ifndef BRGTC6_SYNC_FIFO_UNIT_TEST
`define BRGTC6_SYNC_FIFO_UNIT_TEST

`include "common/SyncFifo.sv"
`include "utils/manual/ManualCheckSingleClkTB.sv"

import "DPI-C" function int get_system_time_seed();

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam            p_num_duts                = 5;
  localparam integer    p_bit_widths[p_num_duts]  = '{4, 8, 16, 32, 64};
  localparam integer    p_num_entries[p_num_duts] = '{64, 32, 16, 8, 4};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  // Generate test benches
  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      SyncFifoTest #(
        .p_bit_width(p_bit_widths[i]),
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
// SyncFifoTest
//----------------------------------------------------------------------
module SyncFifoTest # (
  parameter p_bit_width        = 8,
  parameter p_num_entries      = 8,
  parameter p_max_msgs         = 50,
  parameter p_max_clock_period = 100,
  parameter p_max_msg_delay    = 100,
  parameter p_max_rst_delay    = 100
)(
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

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
ManualCheckSingleClkTB #(
  .p_chk_nbits(p_bit_width),
  .p_timeout_period(100000)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
SyncFifo #(
  .p_num_entries(p_num_entries),
  .p_bit_width(p_bit_width)
) dut (
  .clk(clk),
  .reset(reset),
  .istream_val(src_val),
  .istream_rdy(src_rdy),
  .istream_msg(src_msg),
  .ostream_val(sink_val),
  .ostream_rdy(sink_rdy),
  .ostream_msg(sink_msg)
);

//----------------------------------------------------------------------
// write_fifo
//----------------------------------------------------------------------
task automatic write_fifo (
  integer num_msgs,
  integer msg_delay = -1,
  logic [p_bit_width-1:0] src_msgs[],
  integer seed      = 32'(get_system_time_seed() + $time)
);
  if(msg_delay == -1) msg_delay = $urandom() % (p_max_msg_delay + 1);
  
  for (int i = 0; i < num_msgs; i++) begin

    // Wait for DUT to be able to accept input
    while (!src_rdy) #1;

    // Send message
    @(negedge clk);
    src_msg = src_msgs[i];
    src_val = 1;
    @(negedge clk);
    src_val = 0;

    // Wait for some random amount of time before next action
    #msg_delay;
  end
endtask

//----------------------------------------------------------------------
// read_fifo
//----------------------------------------------------------------------
task automatic read_fifo (
  integer num_msgs,
  integer msg_delay = -1,
  logic [p_bit_width-1:0] src_msgs[],
  integer seed      = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  if(msg_delay == -1) msg_delay = $urandom() % (p_max_msg_delay + 1);
  
  for (int i = 0; i < num_msgs; i++) begin

    // Check result once DUT has produced it and set ready high
    if (!sink_val) @(posedge sink_val);
    @(negedge clk);
    sink_rdy = 1;
    tb.test_case_check(p_bit_width'(src_msgs[i]), p_bit_width'(sink_msg));
    
    // Deassert sink_rdy so DUT knows the sink has taken the value
    @(negedge clk);
    sink_rdy = 0;

    // Wait for some random amount of time before next action
    #msg_delay;
  end
endtask

//----------------------------------------------------------------------
// test_standard
//----------------------------------------------------------------------
task automatic test_standard (
  string  name,
  integer num_msgs   = -1, 
  integer clk_period = -1, 
  integer msg_delay  = -1,
  integer rst_delay  = -1,
  integer seed       = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  logic [p_bit_width-1:0] src_msgs[];
  src_msgs = new[num_msgs];

  if (num_msgs   == -1) num_msgs   = 1 + ($urandom() % (p_max_msgs));
  if (clk_period == -1) clk_period = 2 + ($urandom() % (p_max_clock_period - 1));
  if (msg_delay  == -1) msg_delay  = 1 + ($urandom() % (p_max_msg_delay));
  if (rst_delay  == -1) rst_delay  = clk_period + ($urandom() % (p_max_rst_delay - clk_period + 1));

  // Initialize test case (synchronous reset)
  @(posedge clk);
  tb.test_case_begin (
    name,
    clk_period,
    rst_delay,
    seed
  );

  src_val  = 0;
  sink_rdy = 0;

  // Initialize messages to send and receive
  for (int i = 0; i < num_msgs; i++)
    src_msgs[i] = p_bit_width'($urandom() % (2**p_bit_width + 1));

  // Write and read messages in parallel
  fork
    write_fifo (
      num_msgs,
      msg_delay,
      src_msgs,
      seed
    );
    read_fifo (
      num_msgs,
      msg_delay,
      src_msgs,
      seed
    );
  join

  #100;
endtask

//----------------------------------------------------------------------
// test_reset
//----------------------------------------------------------------------
task automatic test_reset (
  string  name,
  integer num_msgs   = -1, 
  integer clk_period = -1,
  integer msg_delay  = -1,
  integer rst_delay  = -1,
  integer seed       = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);
  
  logic [p_bit_width-1:0] src_msgs[];
  src_msgs = new[num_msgs];

  if (num_msgs   == -1) num_msgs   = 1 + ($urandom() % (p_max_msgs));
  if (clk_period == -1) clk_period = 2 + ($urandom() % (p_max_clock_period - 1));
  if (msg_delay  == -1) msg_delay  = 1 + ($urandom() % (p_max_msg_delay));
  if (rst_delay  == -1) rst_delay  = clk_period + ($urandom() % (p_max_rst_delay - clk_period + 1));

  // Initialize test case (synchronous reset)
  @(posedge clk);
  tb.test_case_begin (
    name,
    clk_period,
    rst_delay,
    seed
  );

  src_val  = 0;
  sink_rdy = 0;

  // Initialize messages to send and receive
  for (int i = 0; i < num_msgs; i++)
    src_msgs[i] = p_bit_width'($urandom() % (2**p_bit_width + 1));

  // Partially fill FIFO
  write_fifo (
    num_msgs,
    msg_delay,
    src_msgs,
    seed
  );

  // Reset and check pointers
  tb.do_reset(
    rst_delay
  );

  tb.test_case_check(0, p_bit_width'(dut.r_ptr), "r_ptr");
  tb.test_case_check(0, p_bit_width'(dut.w_ptr), "w_ptr");

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_bw_%0d_ne_%0d", p_bit_width, p_num_entries);
  tb.test_bench_start($sformatf("SyncFifoTest%s", suffix));
  
  // One element
  if (tb.test_case == 1  || tb.test_case == 0) test_standard($sformatf("one_elem_small_clk%s", suffix), 1, 2);
  if (tb.test_case == 2  || tb.test_case == 0) test_standard($sformatf("one_elem_large_clk%s", suffix), 1, 10);
  if (tb.test_case == 3  || tb.test_case == 0) test_standard($sformatf("one_elem_xlarge_clk%s", suffix), 1, 100);

  // Two elements
  if (tb.test_case == 4  || tb.test_case == 0) test_standard($sformatf("two_elems_small_clk%s", suffix), 2, 2);
  if (tb.test_case == 5  || tb.test_case == 0) test_standard($sformatf("two_elems_large_clk%s", suffix), 2, 10);
  if (tb.test_case == 6  || tb.test_case == 0) test_standard($sformatf("two_elems_xlarge_clk%s", suffix), 2, 100);

  // Max elements
  if (tb.test_case == 7  || tb.test_case == 0) test_standard($sformatf("max_elems_small_clk%s", suffix), p_num_entries, 2);
  if (tb.test_case == 8  || tb.test_case == 0) test_standard($sformatf("max_elems_large_clk%s", suffix), p_num_entries, 10);
  if (tb.test_case == 9  || tb.test_case == 0) test_standard($sformatf("max_elems_xlarge_clk%s", suffix), p_num_entries, 100);

  // Double max elements
  if (tb.test_case == 10 || tb.test_case == 0) test_standard($sformatf("double_max_elems_small_clk_full%s", suffix), 2*p_num_entries, 2, 50);
  if (tb.test_case == 11 || tb.test_case == 0) test_standard($sformatf("double_max_elems_large_clk_full%s", suffix), 2*p_num_entries, 10, 50);
  if (tb.test_case == 12 || tb.test_case == 0) test_standard($sformatf("double_max_elems_xlarge_clk_full%s", suffix), 2*p_num_entries, 100, 50);

  // Reset tests
  if (tb.test_case == 13 || tb.test_case == 0) test_reset($sformatf("ptrs_on_reset%s", suffix), 2, 10);

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
