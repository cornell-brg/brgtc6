`timescale 1ns/1ps

`ifndef BRGTC6_CREDIT_SEND_UNIT_TEST
`define BRGTC6_CREDIT_SEND_UNIT_TEST

`include "credit/CreditSend.sv"
`include "utils/manual/ManualCheckSingleClkTB.sv"

import "DPI-C" function int get_system_time_seed();

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam            p_num_duts               = 5;
  localparam integer    p_bit_widths[p_num_duts] = '{4, 8, 16, 32, 64};
  localparam integer    p_max_creds[p_num_duts]  = '{64, 32, 16, 8, 4};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  // Generate test benches
  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      CreditSendTest #(
        .p_bit_width(p_bit_widths[i]),
        .p_max_cred(p_max_creds[i])
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
// CreditSendTest
//----------------------------------------------------------------------
module CreditSendTest #(
  parameter p_bit_width        = 8,
  parameter p_max_cred         = 8,
  parameter p_max_clk_pd_mult  = 5,
  parameter p_max_clk_div_mult = 5,
  parameter p_clk_width        = p_max_clk_pd_mult + 1,
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

logic [p_clk_width-1:0] clk_div;
logic [p_clk_width-1:0] clk_skew;

// source side
logic [p_bit_width-1:0] in_msg;
logic                   in_val;
logic                   in_rdy;

// Output credit interface
logic [p_bit_width-1:0] cred_msg;
logic                   cred_val;
logic                   cred_clk;
logic                   cred_rst;
logic                   cred_cred;

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
CreditSend #(
  .p_bit_width(p_bit_width),
  .p_max_cred(p_max_cred),
  .p_clk_width(p_clk_width)
) dut ( .* );

//----------------------------------------------------------------------
// test_single_msg_no_cred
//----------------------------------------------------------------------
task automatic test_single_msg_no_cred (
  string name,
  integer clk_pd_mult  = -1,
  integer clk_div_mult = -1,
  integer l_clk_skew   = -1,
  integer rst_delay    = -1,
  integer seed         = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  integer sent_msg = 0;

  if (clk_pd_mult  == -1) clk_pd_mult  = 1 + ($urandom() % (p_max_clk_pd_mult));
  if (clk_div_mult == -1) clk_div_mult = $urandom() % (p_max_clk_div_mult + 1);
  if (l_clk_skew   == -1) l_clk_skew   = $urandom() % (2**clk_div_mult);

  // Guarantee reset is at least one cycle of clock so that it is captured on a positive edge
  if (rst_delay    == -1) rst_delay    = 2**clk_pd_mult + ($urandom() % (p_max_rst_delay - 2**clk_pd_mult + 1));

  // Initialize test case on positive edge of clock so reset takes effect (synchronous reset)
  @(posedge clk);
  tb.test_case_begin (
    name,
    2**clk_pd_mult,
    rst_delay,
    seed
  );

  // Initialize signals
  clk_div = p_clk_width'(2**clk_div_mult);
  clk_skew = p_clk_width'(l_clk_skew);
  in_msg = 0;
  in_val = 0;
  cred_cred = 0;

  // Confirm reset signals
  tb.test_case_check(0, p_bit_width'(dut.used_cred_cnt), "used_cred_cnt");
  tb.test_case_check(0, cred_val, "cred_val");
  tb.test_case_check(1, cred_rst, "cred_rst");

  // Wait for clock generator reset delay (10 cycles)
  for (int i = 0; i < 10; i++) @(posedge clk);
  tb.test_case_check(0, in_rdy, "in_rdy"); // not ready yet

  // Wait for credit reset delay (3 cycles)
  for (int i = 0; i < 3; i++) @(posedge clk);
  
  // Confirm reset values
  @(negedge clk);
  tb.test_case_check(0, cred_rst, "cred_rst"); // o_reset is deasserted at this point
  tb.test_case_check(0, p_bit_width'(dut.used_cred_cnt), "used_cred_cnt");

  // Send 1 message
  in_msg = {p_bit_width{1'b1}};
  while (sent_msg == 0) begin
    in_val = 1;
    @(posedge clk);
    if (in_rdy == 1) begin
      sent_msg = 1;
      #1; // hold time
    end
    in_val = 0;
    #(1 + ($urandom() % (p_max_msg_delay)));
  end
  @(negedge clk);
  tb.test_case_check(1, p_bit_width'(dut.used_cred_cnt), "used_cred_cnt"); // used one credit
  while(dut.clk_en == 0) #1;
  tb.test_case_check(1, in_rdy, "in_rdy"); // no more credits

  #100;
endtask

//----------------------------------------------------------------------
// test_max_msgs_no_cred
//----------------------------------------------------------------------
task automatic test_max_msgs_no_cred (
  string name,
  integer clk_pd_mult  = -1,
  integer clk_div_mult = -1,
  integer l_clk_skew   = -1,
  integer rst_delay    = -1,
  integer seed         = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  integer send_idx = 0;

  if (clk_pd_mult  == -1) clk_pd_mult  = 1 + ($urandom() % (p_max_clk_pd_mult));
  if (clk_div_mult == -1) clk_div_mult = $urandom() % (p_max_clk_div_mult + 1);
  if (l_clk_skew   == -1) l_clk_skew   = $urandom() % (2**clk_div_mult);

  // Guarantee reset is at least one cycle of clock so that it is captured on a positive edge
  if (rst_delay    == -1) rst_delay    = 2**clk_pd_mult + ($urandom() % (p_max_rst_delay - 2**clk_pd_mult + 1));

  // Initialize test case on positive edge of clock so reset takes effect (synchronous reset)
  @(posedge clk);
  tb.test_case_begin (
    name,
    2**clk_pd_mult,
    rst_delay,
    seed
  );

  // Initialize signals
  clk_div = p_clk_width'(2**clk_div_mult);
  clk_skew = p_clk_width'(l_clk_skew);
  in_msg = 0;
  in_val = 0;
  cred_cred = 0;

  // Wait for clock generator reset and credit reset delays (13 cycles)
  for (int i = 0; i < 10; i++) @(posedge clk);
  for (int i = 0; i < 3; i++) @(posedge clk);

  // Send max messages without needing more credit
  in_msg = p_bit_width'(1 + ($urandom() % (p_max_msg_val)));
  while (send_idx < p_max_cred) begin
    in_val = 1;
    @(posedge clk);
    if (in_rdy == 1) begin
      in_msg = p_bit_width'(1 + ($urandom() % (p_max_msg_val)));
      tb.test_case_check(p_bit_width'(send_idx), p_bit_width'(dut.used_cred_cnt), "used_cred_cnt");
      send_idx++;
      #1; // hold time
    end
    in_val = 0;
    #(1 + ($urandom() % (p_max_msg_delay)));
  end
  @(negedge clk);
  tb.test_case_check(p_bit_width'(send_idx), p_bit_width'(dut.used_cred_cnt), "used_cred_cnt");
  tb.test_case_check(0, in_rdy, "in_rdy"); // no more credits

  #100;
endtask

//----------------------------------------------------------------------
// test_max_msgs_cred
//----------------------------------------------------------------------
task automatic test_max_msgs_cred (
  string name,
  integer clk_pd_mult  = -1,
  integer clk_div_mult = -1,
  integer l_clk_skew   = -1,
  integer rst_delay    = -1,
  integer seed         = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  integer send_idx = 0;

  if (clk_pd_mult  == -1) clk_pd_mult  = 1 + ($urandom() % (p_max_clk_pd_mult));
  if (clk_div_mult == -1) clk_div_mult = $urandom() % (p_max_clk_div_mult + 1);
  if (l_clk_skew   == -1) l_clk_skew   = $urandom() % (2**clk_div_mult);

  // Guarantee reset is at least one cycle of clock so that it is captured on a positive edge
  if (rst_delay    == -1) rst_delay    = 2**clk_pd_mult + ($urandom() % (p_max_rst_delay - 2**clk_pd_mult + 1));

  // Initialize test case on positive edge of clock so reset takes effect (synchronous reset)
  @(posedge clk);
  tb.test_case_begin (
    name,
    2**clk_pd_mult,
    rst_delay,
    seed
  );

  // Initialize signals
  clk_div = p_clk_width'(2**clk_div_mult);
  clk_skew = p_clk_width'(l_clk_skew);
  in_msg = 0;
  in_val = 0;
  cred_cred = 0;

  // Wait for clock generator reset and credit reset delays (13 cycles)
  for (int i = 0; i < 10; i++) @(posedge clk);
  for (int i = 0; i < 3; i++) @(posedge clk);

  // Send max messages without needing more credit
  in_msg = p_bit_width'(1 + ($urandom() % (p_max_msg_val)));
  while (send_idx < p_max_cred) begin
    in_val = 1;
    @(posedge clk);
    if (in_rdy == 1) begin
      in_msg = p_bit_width'(1 + ($urandom() % (p_max_msg_val)));
      tb.test_case_check(p_bit_width'(send_idx), p_bit_width'(dut.used_cred_cnt), "used_cred_cnt"); // checks last one
      send_idx++;
      #1; // hold time
    end
    in_val = 0;
    #(1 + ($urandom() % (p_max_msg_delay)));
  end
  @(negedge clk);
  tb.test_case_check(p_bit_width'(send_idx), p_bit_width'(dut.used_cred_cnt), "used_cred_cnt");
  tb.test_case_check(0, in_rdy, "in_rdy"); // no more credits

  // Simulate CreditRecv behavior (change signal on posedge)
  #(1 + ($urandom() % (p_max_msg_delay)));
  @(posedge cred_clk);
  cred_cred = 1;
  @(posedge cred_clk);
  cred_cred = 0;

  // Wait for credit signal to propagate through synchronizer
  while(dut.sync_cred == 0) #1;

  // Wait for sync_cred to update used_cred_cnt
  @(posedge clk);
  @(negedge clk);
  while(dut.clk_en == 0) #1;

  // Wait for used_cred_cnt to update
  @(posedge clk);
  @(negedge clk);
  tb.test_case_check(p_bit_width'(p_max_cred-1), p_bit_width'(dut.used_cred_cnt), "used_cred_cnt");

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_bw_%0d_mc_%0d", p_bit_width, p_max_cred);
  tb.test_bench_start($sformatf("CreditSendTest%s", suffix));

  // Random tests
  if (tb.test_case == 1  || tb.test_case == 0) test_single_msg_no_cred($sformatf("single_msg_no_cred_rand%s", suffix));
  if (tb.test_case == 2  || tb.test_case == 0) test_max_msgs_no_cred($sformatf("max_msgs_no_cred_rand%s", suffix));
  if (tb.test_case == 3  || tb.test_case == 0) test_max_msgs_cred($sformatf("max_msgs_cred_rand%s", suffix));

  // High-div tests (period = 4, div = 32)
  if (tb.test_case == 4  || tb.test_case == 0) test_single_msg_no_cred($sformatf("single_msg_no_cred_high_div%s", suffix), 2, 5);
  if (tb.test_case == 5  || tb.test_case == 0) test_max_msgs_no_cred($sformatf("max_msgs_no_cred_high_div%s", suffix), 2, 5);
  if (tb.test_case == 6  || tb.test_case == 0) test_max_msgs_cred($sformatf("max_msgs_cred_high_div%s", suffix), 2, 5);

  // High-skew tests (period = 4, div = 32, skew = 31)
  if (tb.test_case == 7  || tb.test_case == 0) test_single_msg_no_cred($sformatf("single_msg_no_cred_high_skew%s", suffix), 2, 5, 31);
  if (tb.test_case == 8  || tb.test_case == 0) test_max_msgs_no_cred($sformatf("max_msgs_no_cred_high_skew%s", suffix), 2, 5, 31);
  if (tb.test_case == 9  || tb.test_case == 0) test_max_msgs_cred($sformatf("max_msgs_cred_high_skew%s", suffix), 2, 5, 31);

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
