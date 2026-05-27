`timescale 1ns/1ps

`ifndef BRGTC6_CREDIT_RECV_UNIT_TEST
`define BRGTC6_CREDIT_RECV_UNIT_TEST

`include "credit/CreditRecv.sv"
`include "utils/manual/ManualCheckSingleClkTB.sv"

`ifndef BRGTC6_TIME_SEED
`define BRGTC6_TIME_SEED
import "DPI-C" function int get_system_time_seed();
`endif

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam            p_num_duts                  = 5;
  localparam integer    p_bit_widths[p_num_duts]    = '{4, 8, 16, 32, 64};
  localparam integer    p_buffer_depths[p_num_duts] = '{64, 32, 16, 8, 4};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  // Generate test benches
  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      CreditRecvTest #(
        .p_bit_width(p_bit_widths[i]),
        .p_buffer_depth(p_buffer_depths[i])
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
// Top
//----------------------------------------------------------------------
module CreditRecvTest #(
  parameter p_bit_width        = 8,
  parameter p_buffer_depth     = 8,
  parameter p_max_clock_period = 100,
  parameter p_max_rst_delay    = 100,
  parameter p_max_wait_cycles  = 100,
  parameter p_max_msg_val      = 2**(p_bit_width - 1),
  parameter p_max_msg_delay    = 100
) (
  input  logic go,
  output logic done,
  output logic pass
);

logic                   clk;
logic                   reset;

// source side
logic [p_bit_width-1:0] out_msg;
logic                   out_val;
logic                   out_rdy;

// sink side
logic [p_bit_width-1:0] cred_msg;
logic                   cred_val;
logic                   cred_clk;
logic                   cred_rst;
logic                   cred_cred;

integer                 cred_clk_period = 2;

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
CreditRecv #(
  .p_bit_width(p_bit_width),
  .p_buffer_depth(p_buffer_depth)
) dut ( .* );

// Credit clock
initial cred_clk = 0;
always begin
  #(cred_clk_period/2) cred_clk <= ~cred_clk;
end

//----------------------------------------------------------------------
// test_single_msg
//----------------------------------------------------------------------
task automatic test_single_msg (
  string name,
  integer clk_period        = -1,
  integer l_cred_clk_period = -1,
  integer rst_delay         = -1,
  integer seed              = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  if (clk_period        == -1) clk_period      = 2 + ($urandom() % (p_max_clock_period - 1));
  if (l_cred_clk_period == -1) cred_clk_period = 2 + ($urandom() % (p_max_clock_period - 1));
  else cred_clk_period                         = l_cred_clk_period;

  // Guarantee reset is at least one cycle of credit clock so that it is captured on a positive edge
  if (rst_delay         == -1) rst_delay       = cred_clk_period + ($urandom() % (p_max_rst_delay - cred_clk_period + 1));

  // Synchronous reset
  @(posedge cred_clk);
  cred_rst = 1;
  tb.test_case_begin (
    name,
    clk_period,
    rst_delay,
    seed
  );

  // initialize signals to valid logic levels
  cred_rst = 0;
  cred_val = 0;
  out_rdy  = 0;

  // wait for reset synchronizer to propagate
  @(negedge cred_clk);
  @(negedge cred_clk);
  @(negedge cred_clk);
  
  // reset state - all zeros
  tb.test_case_check(0, cred_cred, "cred_cred");
  tb.test_case_check(0, p_bit_width'(dut.sent_cred_cnt), "sent_cred_cnt");
  tb.test_case_check(0, p_bit_width'(dut.sent_cred_ovfl), "sent_cred_ovfl");
  tb.test_case_check(0, p_bit_width'(dut.owed_cred_sync), "owed_cred_cnt");
  tb.test_case_check(0, p_bit_width'(dut.owed_cred_ovfl_sync), "owed_cred_ovfl");

  // send 1 message
  @(negedge cred_clk);
  cred_msg = {p_bit_width{1'b1}};
  cred_val = 1;
  @(negedge cred_clk);
  cred_val = 0;

  // consume 1 message when available
  while(out_val == 0) #1;
  @(negedge clk);
  out_rdy = 1;

  // send credit to source when message consumed
  while(dut.owed_cred_sync != 1 || dut.owed_cred_sync - dut.sent_cred_cnt == 1) #1;
  tb.test_case_check(1, cred_cred, "cred_cred");
  @(negedge clk);
  out_rdy = 0;

  // check that owed credits are sent
  @(negedge cred_clk);
  @(negedge cred_clk);
  @(negedge cred_clk);
  tb.test_case_check(1, p_bit_width'(dut.owed_cred_sync), "owed_cred_cnt");
  tb.test_case_check(0, p_bit_width'(dut.owed_cred_ovfl_sync), "owed_cred_ovfl"); // no overflow
  tb.test_case_check(1, p_bit_width'(dut.sent_cred_cnt), "sent_cred_cnt");

  #100;
endtask

//----------------------------------------------------------------------
// test_overflow
//----------------------------------------------------------------------
task automatic test_overflow (
  string name,
  integer clk_period        = -1,
  integer l_cred_clk_period = -1,
  integer rst_delay         = -1,
  integer seed              = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  if (clk_period        == -1) clk_period      = 2 + ($urandom() % (p_max_clock_period - 1));
  if (l_cred_clk_period == -1) cred_clk_period = 2 + ($urandom() % (p_max_clock_period - 1));
  else cred_clk_period                         = l_cred_clk_period;

  // Guarantee reset is at least one cycle of credit clock so that it is captured on a positive edge
  if (rst_delay         == -1) rst_delay       = cred_clk_period + ($urandom() % (p_max_rst_delay - cred_clk_period + 1));

  // Synchronous reset
  @(posedge cred_clk);
  cred_rst = 1;
  tb.test_case_begin (
    name,
    clk_period,
    rst_delay,
    seed
  );

  // initialize signals to valid logic levels
  cred_rst = 0;
  cred_val = 0;
  out_rdy  = 0;

  // wait for reset synchronizer to propagate
  @(negedge cred_clk);
  @(negedge cred_clk);
  @(negedge cred_clk);
  
  // reset state - all zeros
  tb.test_case_check(0, cred_cred, "cred_cred");
  tb.test_case_check(0, p_bit_width'(dut.sent_cred_cnt), "sent_cred_cnt");
  tb.test_case_check(0, p_bit_width'(dut.sent_cred_ovfl), "sent_cred_ovfl");
  tb.test_case_check(0, p_bit_width'(dut.owed_cred_sync), "owed_cred_cnt");
  tb.test_case_check(0, p_bit_width'(dut.owed_cred_ovfl_sync), "owed_cred_ovfl");

  // send and receieve p_buffer_depth messages
  fork
    for (int i = 0; i < p_buffer_depth; i++) begin
      @(negedge cred_clk);
      cred_msg = p_bit_width'(1 + ($urandom() % (p_max_msg_val)));
      cred_val = 1;
      @(negedge cred_clk);
      cred_val = 0;
      #(1 + ($urandom() % (p_max_msg_delay)));
    end
    for (int i = 0; i < p_buffer_depth; i++) begin
      while(out_val == 0) #1;
      @(negedge clk);
      out_rdy = 1;
      @(negedge clk);
      out_rdy = 0;
    end
  join

  // send and receive one more message (right before overflow occurs)
  fork
    begin
      @(negedge cred_clk);
      cred_msg = p_bit_width'(1 + ($urandom() % (p_max_msg_val)));
      cred_val = 1;
      @(negedge cred_clk);
      cred_val = 0;
      #(1 + ($urandom() % (p_max_msg_delay)));
    end
    begin
      while(out_val == 0) #1;
      @(negedge clk);
      out_rdy = 1;
      @(negedge clk);
      out_rdy = 0;
    end
  join

  // check that owed credits are sent
  @(negedge cred_clk);
  @(negedge cred_clk);
  @(negedge cred_clk);
  @(negedge cred_clk);
  tb.test_case_check(p_bit_width'(p_buffer_depth+1), p_bit_width'(dut.owed_cred_sync), "owed_cred_cnt");
  tb.test_case_check(0, p_bit_width'(dut.owed_cred_ovfl_sync), "owed_cred_ovfl"); // no overflow
  tb.test_case_check(p_bit_width'(p_buffer_depth+1), p_bit_width'(dut.sent_cred_cnt), "sent_cred_cnt");
  tb.test_case_check(0, p_bit_width'(dut.sent_cred_ovfl), "sent_cred_ovfl"); // no overflow

  // cause overflow
  fork
    begin
      @(negedge cred_clk);
      cred_msg = p_bit_width'(1 + ($urandom() % (p_max_msg_val)));
      cred_val = 1;
      @(negedge cred_clk);
      cred_val = 0;
      #(1 + ($urandom() % (p_max_msg_delay)));
    end
    begin
      while(out_val == 0) #1;
      @(negedge clk);
      out_rdy = 1;
      @(negedge clk);
      out_rdy = 0;
    end
  join

  // check that owed credits are sent
  @(negedge cred_clk);
  @(negedge cred_clk);
  @(negedge cred_clk);
  @(negedge cred_clk);
  tb.test_case_check(0, p_bit_width'(dut.owed_cred_sync), "owed_cred_cnt");
  tb.test_case_check(1, p_bit_width'(dut.owed_cred_ovfl_sync), "owed_cred_ovfl"); // no overflow
  tb.test_case_check(0, p_bit_width'(dut.owed_cred_sync), "sent_cred_cnt");
  tb.test_case_check(1, p_bit_width'(dut.owed_cred_ovfl_sync), "sent_cred_ovfl"); // no overflow

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_bw_%0d_bd_%0d", p_bit_width, p_buffer_depth);
  tb.test_bench_start($sformatf("CreditRecvTest%s", suffix));

  // single message tests
  if (tb.test_case == 1  || tb.test_case == 0) test_single_msg($sformatf("single_msg_rand%s", suffix), -1, -1, -1);
  if (tb.test_case == 2  || tb.test_case == 0) test_single_msg($sformatf("single_msg_eq_clocks%s", suffix), 10, 10, -1);
  if (tb.test_case == 3  || tb.test_case == 0) test_single_msg($sformatf("single_msg_lg_cred_clk%s", suffix), 2, 10);
  if (tb.test_case == 4  || tb.test_case == 0) test_single_msg($sformatf("single_msg_lg_out_clk%s", suffix), 10, 2);

  // overflow tests
  if (tb.test_case == 5  || tb.test_case == 0) test_overflow($sformatf("overflow_rand%s", suffix));
  if (tb.test_case == 6  || tb.test_case == 0) test_overflow($sformatf("overflow_eq_clocks%s", suffix), 10, 10);
  if (tb.test_case == 7  || tb.test_case == 0) test_overflow($sformatf("overflow_lg_cred_clk%s", suffix), 2, 10);
  if (tb.test_case == 8  || tb.test_case == 0) test_overflow($sformatf("overflow_lg_out_clk%s", suffix), 10, 2);

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
