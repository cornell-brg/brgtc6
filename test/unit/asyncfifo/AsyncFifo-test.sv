`timescale 1ns/1ps

`ifndef BRGTC6_ASYNC_FIFO_UNIT_TEST
`define BRGTC6_ASYNC_FIFO_UNIT_TEST

`include "asyncfifo/AsyncFifo.sv"
`include "utils/manual/ManualCheckDualClkTB.sv"

`ifndef BRGTC6_TIME_SEED
`define BRGTC6_TIME_SEED
import "DPI-C" function int get_system_time_seed();
`endif

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
      AsyncFifoTest #(
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
// AsyncFifoTest
//----------------------------------------------------------------------
module AsyncFifoTest #(
  parameter p_bit_width        = 32,
  parameter p_num_entries      = 8,
  parameter p_max_msgs         = 50,
  parameter p_max_clock_period = 100,
  parameter p_max_msg_delay    = 100,
  parameter p_max_rst_delay    = 100
) (
  input  logic go,
  output logic done,
  output logic pass
);

// Source side
logic                   src_clk;
logic                   src_rst;
logic                   src_val;
logic                   src_rdy;
logic [p_bit_width-1:0] src_msg;

// Sink side
logic                   sink_clk;
logic                   sink_rst;
logic                   sink_val;
logic                   sink_rdy;
logic [p_bit_width-1:0] sink_msg;

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
ManualCheckDualClkTB #(
  .p_chk_nbits(p_bit_width),
  .p_timeout_period(100000)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
AsyncFifo #(
  .p_num_entries(p_num_entries),
  .p_bit_width(p_bit_width)
) dut (
  .i_clk(src_clk),
  .istream_val(src_val),
  .istream_rdy(src_rdy),
  .istream_msg(src_msg[p_bit_width-1:0]),
  .o_clk(sink_clk),
  .async_rst(src_rst),
  .ostream_val(sink_val),
  .ostream_rdy(sink_rdy),
  .ostream_msg(sink_msg[p_bit_width-1:0])
);

//----------------------------------------------------------------------
// Cover properties
//----------------------------------------------------------------------
SrcRdySetOnReset: cover property (@(negedge src_rst) src_rdy);
OstreamValClearedOnReset: cover property (@(negedge src_rst) !sink_val);
NotEmptyAfterWrite: cover property (@(negedge src_val) !dut.empty);

//----------------------------------------------------------------------
// write_fifo
//----------------------------------------------------------------------
task automatic write_fifo (
  integer num_msgs,
  integer msg_delay,
  logic   [p_bit_width-1:0] src_msgs[]
);
  
  for (int i = 0; i < num_msgs; i++) begin

    // Wait for DUT to be able to accept input
    while (!src_rdy) #1;

    // Send message
    @(negedge src_clk);
    src_msg = src_msgs[i];
    src_val = 1;
    @(negedge src_clk);
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
  integer msg_delay,
  logic   [p_bit_width-1:0] src_msgs[]
);

  for (int i = 0; i < num_msgs; i++) begin

    // Check result once DUT has produced it and set ready high
    while (!sink_val) #1;
    @(negedge sink_clk);
    sink_rdy = 1;
    tb.test_case_check(src_msgs[i], sink_msg, "sink_msg");
    
    // Deassert sink_rdy so DUT knows the sink has taken the value
    @(negedge sink_clk);
    sink_rdy = 0;

    // Wait for some random amount of time before next action
    #msg_delay;
  end
endtask

//----------------------------------------------------------------------
// test_standard - write and read messages
//----------------------------------------------------------------------
task automatic test_standard (
  string  name,
  integer num_msgs          = -1, 
  integer src_clk_period    = -1, 
  integer sink_clk_period   = -1,
  integer src_msg_delay     = -1,
  integer sink_msg_delay    = -1,
  integer async_reset_delay = -1,
  integer seed              = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  logic [p_bit_width-1:0] src_msgs[];
  src_msgs = new[num_msgs];

  // Randomize parameters if not set (get range with: min_val + ($$urandom() % (max_val - min_val + 1)))
  if (num_msgs          == -1) num_msgs          = 1 + ($urandom() % (p_max_msgs));
  if (src_clk_period    == -1) src_clk_period    = 2 + ($urandom() % (p_max_clock_period - 1));
  if (sink_clk_period   == -1) sink_clk_period   = 2 + ($urandom() % (p_max_clock_period - 1));
  if (src_msg_delay     == -1) src_msg_delay     = 1 + ($urandom() % (p_max_msg_delay));
  if (sink_msg_delay    == -1) sink_msg_delay    = 1 + ($urandom() % (p_max_msg_delay));
  if (async_reset_delay == -1) async_reset_delay = 1 + ($urandom() % (p_max_rst_delay));

  src_val  = 0;
  sink_rdy = 0;

  // Initialize test case
  tb.test_case_begin (
    name,
    src_clk_period,
    sink_clk_period,
    async_reset_delay,
    0,
    1,
    0,
    seed
  );

  // Guarantee two cycles of idle after reset released
  @(negedge src_clk);
  @(negedge src_clk);

  // Initialize messages to send and receive
  for (int i = 0; i < num_msgs; i++)
    src_msgs[i] = p_bit_width'($urandom());

  // Write and read messages in parallel
  fork
    write_fifo (
      num_msgs,
      src_msg_delay,
      src_msgs
    );
    read_fifo (
      num_msgs,
      src_msg_delay,
      src_msgs
    );
  join

  #100;
endtask

//----------------------------------------------------------------------
// test_reset - confirm points are set to 0 upon reset
//----------------------------------------------------------------------
task automatic test_reset (
  string  name,
  integer num_msgs          = -1, 
  integer src_clk_period    = -1, 
  integer sink_clk_period   = -1,
  integer src_msg_delay     = -1,
  integer sink_msg_delay    = -1,
  integer async_reset_delay = -1,
  integer seed              = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  logic [p_bit_width-1:0] src_msgs[];
  src_msgs = new[num_msgs];

  // Randomize parameters if not set
  if (num_msgs          == -1) num_msgs          = 1 + ($urandom() % (p_max_msgs));
  if (src_clk_period    == -1) src_clk_period    = 2 + ($urandom() % (p_max_clock_period - 1));
  if (sink_clk_period   == -1) sink_clk_period   = 2 + ($urandom() % (p_max_clock_period - 1));
  if (src_msg_delay     == -1) src_msg_delay     = 1 + ($urandom() % (p_max_msg_delay));
  if (sink_msg_delay    == -1) sink_msg_delay    = 1 + ($urandom() % (p_max_msg_delay));
  if (async_reset_delay == -1) async_reset_delay = 1 + ($urandom() % (p_max_rst_delay));

  // Initialize test case and do reset (async reset is tied to src_reset)
  tb.test_case_begin (
    name,
    src_clk_period,
    sink_clk_period,
    async_reset_delay,
    0,
    1,
    0,
    seed
  );
  src_val  = 0;
  sink_rdy = 0;

  // Guarantee two cycles of idle after reset released
  @(negedge src_clk);
  @(negedge src_clk);

  // Initialize messages to send and receive
  for (int i = 0; i < num_msgs; i++)
    src_msgs[i] = {p_bit_width{1'b1}};

  // Partially fill FIFO
  write_fifo (
    num_msgs,
    src_msg_delay,
    src_msgs
  );

  // Asynchronously reset and check pointers are 0
  tb.do_reset (
    async_reset_delay,
    0,
    1,
    0
  );

  tb.test_case_check(0, p_bit_width'(dut.b_read_ptr[$clog2(p_num_entries)-1:0]),  "b_read_ptr");
  tb.test_case_check(0, p_bit_width'(dut.g_read_ptr),  "g_read_ptr");
  tb.test_case_check(0, p_bit_width'(dut.b_write_ptr[$clog2(p_num_entries)-1:0]), "b_write_ptr");
  tb.test_case_check(0, p_bit_width'(dut.g_write_ptr), "g_write_ptr");

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_bw_%0d_ne_%0d", p_bit_width, p_num_entries);
  tb.test_bench_start($sformatf("AsyncFifoTest%s", suffix));

  // One element
  if (tb.test_case == 1  || tb.test_case == 0) test_standard($sformatf("one_elem_same_clk%s", suffix), 1, 10, 10);
  if (tb.test_case == 2  || tb.test_case == 0) test_standard($sformatf("one_elem_large_in_clk%s", suffix), 1, 10, 2);
  if (tb.test_case == 3  || tb.test_case == 0) test_standard($sformatf("one_elem_large_out_clk%s", suffix), 1, 2, 10);
  if (tb.test_case == 4  || tb.test_case == 0) test_standard($sformatf("one_elem_xlarge_in_clk%s", suffix), 1, 100, 2);
  if (tb.test_case == 5  || tb.test_case == 0) test_standard($sformatf("one_elem_xlarge_out_clk%s", suffix), 1, 2, 100);

  // Two elements
  if (tb.test_case == 6  || tb.test_case == 0) test_standard($sformatf("two_elems_same_clk%s", suffix), 2, 10, 10);
  if (tb.test_case == 7  || tb.test_case == 0) test_standard($sformatf("two_elems_large_in_clk%s", suffix), 2, 10, 2);
  if (tb.test_case == 8  || tb.test_case == 0) test_standard($sformatf("two_elems_large_out_clk%s", suffix), 2, 2, 10);
  if (tb.test_case == 9  || tb.test_case == 0) test_standard($sformatf("two_elems_xlarge_in_clk%s", suffix), 2, 100, 2);
  if (tb.test_case == 10 || tb.test_case == 0) test_standard($sformatf("two_elems_xlarge_out_clk%s", suffix), 2, 2, 100);

  // Max elements
  if (tb.test_case == 11 || tb.test_case == 0) test_standard($sformatf("max_elems_same_clk%s", suffix), p_num_entries, 10, 10);
  if (tb.test_case == 12 || tb.test_case == 0) test_standard($sformatf("max_elems_large_in_clk%s", suffix), p_num_entries, 10, 2);
  if (tb.test_case == 13 || tb.test_case == 0) test_standard($sformatf("max_elems_large_out_clk%s", suffix), p_num_entries, 2, 10);
  if (tb.test_case == 14 || tb.test_case == 0) test_standard($sformatf("max_elems_xlarge_in_clk%s", suffix), p_num_entries, 100, 2);
  if (tb.test_case == 15 || tb.test_case == 0) test_standard($sformatf("max_elems_xlarge_out_clk%s", suffix), p_num_entries, 2, 100);

  // Double max elements
  if (tb.test_case == 16 || tb.test_case == 0) test_standard($sformatf("double_max_elems_same_clk_full%s", suffix), 2*p_num_entries, 10, 10, -1, 50);
  if (tb.test_case == 17 || tb.test_case == 0) test_standard($sformatf("double_max_elems_large_in_clk_full%s", suffix), 2*p_num_entries, 10, 2, -1, 50);
  if (tb.test_case == 18 || tb.test_case == 0) test_standard($sformatf("double_max_elems_large_out_clk_full%s", suffix), 2*p_num_entries, 2, 10, -1, 50);
  if (tb.test_case == 19 || tb.test_case == 0) test_standard($sformatf("double_max_elems_xlarge_in_clk_full%s", suffix), 2*p_num_entries, 100, 2, -1, 50);
  if (tb.test_case == 20 || tb.test_case == 0) test_standard($sformatf("double_max_elems_xlarge_out_clk_full%s", suffix), 2*p_num_entries, 2, 100, -1, 50);

  // Reset tests (only partially fill FIFO)
  if (tb.test_case == 21 || tb.test_case == 0) test_reset($sformatf("async_reset_delay_1%s", suffix), p_num_entries/2, -1, -1, -1, -1, 1);
  if (tb.test_case == 22 || tb.test_case == 0) test_reset($sformatf("async_reset_delay_10%s", suffix), p_num_entries/2, -1, -1, -1, -1, 10);
  if (tb.test_case == 23 || tb.test_case == 0) test_reset($sformatf("async_reset_delay_100%s", suffix), p_num_entries/2, -1, -1, -1, -1,, 100);

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif 
