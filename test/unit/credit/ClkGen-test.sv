`timescale 1ns/1ps

`ifndef BRGTC6_CLK_GEN_UNIT_TEST
`define BRGTC6_CLK_GEN_UNIT_TEST

`include "credit/ClkGen.sv"
`include "utils/manual/ManualCheckSingleClkTB.sv"

import "DPI-C" function int get_system_time_seed();

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam p_num_duts = 1;

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  // Generate test benches
  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      ClkGenTest #(
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
// ClkGenTest
//----------------------------------------------------------------------
module ClkGenTest #(
  parameter p_chk_nbits        = 8,
  parameter p_clk_reset_delay  = 10,
  parameter p_max_clk_pd_mult  = 6,
  parameter p_max_clk_div_mult = 6,
  parameter p_max_clk_skew     = 100,
  parameter p_clk_width        = p_max_clk_pd_mult + 1,
  parameter p_max_rst_delay    = 100,
  parameter p_max_wait_cycles  = 100
) (
  input  logic go,
  output logic done,
  output logic pass
);

logic                   clk;
logic                   reset;
logic [p_clk_width-1:0] clk_div;
logic [p_clk_width-1:0] clk_skew;
logic                   o_clk;
logic                   o_reset;
logic                   en;

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
ManualCheckSingleClkTB #(
  .p_chk_nbits(p_chk_nbits)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
ClkGen #(
  .p_reset_delay(p_clk_reset_delay),
  .p_clk_width(p_clk_width)
) dut ( .* );

//----------------------------------------------------------------------
// test_basic_div_no_skew
//----------------------------------------------------------------------
task automatic test_basic_div_no_skew (
  string name,
  integer clk_pd_mult  = -1,
  integer clk_div_mult = -1,
  integer rst_delay    = -1,
  integer seed         = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  integer i_clk_cntr = 0;
  integer i_clk_time = 0;
  integer o_clk_cntr = 0;
  integer o_clk_time = 0;

  if (clk_pd_mult  == -1) clk_pd_mult = 1 + ($urandom() % (p_max_clk_pd_mult));
  if (clk_div_mult == -1) clk_div_mult = $urandom() % (p_max_clk_div_mult + 1);
  if (rst_delay    == -1) rst_delay  = 2**clk_pd_mult + ($urandom() % (p_max_rst_delay - 2**clk_pd_mult + 1));

  @(posedge clk);
  tb.test_case_begin (
    name,
    2**clk_pd_mult,
    rst_delay,
    seed
  );
  clk_div = p_clk_width'(2**clk_div_mult);
  clk_skew = 0; // TODO: add skew

  fork
    while (i_clk_cntr < 10) begin
      @(posedge clk);
      if (i_clk_cntr == 0) i_clk_time = integer'($time);
      else if (i_clk_cntr == 9) i_clk_time = integer'($time) - i_clk_time;
      i_clk_cntr++;
    end
    while (o_clk_cntr < 10) begin
      @(posedge o_clk);
      if (o_clk_cntr == 0) o_clk_time = integer'($time);
      else if (o_clk_cntr == 9) o_clk_time = integer'($time) - o_clk_time;
      o_clk_cntr++;
    end
  join
  tb.test_case_check(2**clk_div_mult, p_chk_nbits'(o_clk_time/i_clk_time), $sformatf("curr_time=%0d, o_clk_time=%0d, i_clk_time=%0d", $time, o_clk_time, i_clk_time));
  #100;
endtask

//----------------------------------------------------------------------
// test_o_reset
//----------------------------------------------------------------------
task automatic test_o_reset (
  string name,
  integer clk_pd_mult  = -1,
  integer clk_div_mult = -1,
  integer rst_delay    = -1,
  integer seed         = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  integer reset_cntr;

  if (clk_pd_mult  == -1) clk_pd_mult = 1 + ($urandom() % (p_max_clk_pd_mult));
  if (clk_div_mult == -1) clk_div_mult = $urandom() % (p_max_clk_div_mult + 1);
  if (rst_delay    == -1) rst_delay  = clk_pd_mult + ($urandom() % (p_max_rst_delay - clk_pd_mult + 1));

  @(posedge clk);
  tb.test_case_begin (
    name,
    2**clk_pd_mult,
    rst_delay,
    seed
  );
  clk_div = p_clk_width'(2**clk_div_mult);
  clk_skew = 0; // TODO: add skew

  @(posedge clk); // count every posedge of clk for o_reset cycles
  reset_cntr = 1;
  while (reset_cntr < p_clk_reset_delay - 1) begin
    @(posedge clk);
    reset_cntr++;
  end
  tb.test_case_check(1, o_reset, "o_reset");
  @(posedge clk);
  #1; // pass over negedge of clk
  tb.test_case_check(0, o_reset, "o_reset");

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("");
  tb.test_bench_start($sformatf("ClkGenTest%s", suffix));

  if (tb.test_case == 1  || tb.test_case == 0) test_basic_div_no_skew($sformatf("rand%s", suffix));
  if (tb.test_case == 2  || tb.test_case == 0) test_basic_div_no_skew($sformatf("div1%s", suffix), 3, 0);
  if (tb.test_case == 3  || tb.test_case == 0) test_basic_div_no_skew($sformatf("div2%s", suffix), 3, 1);
  if (tb.test_case == 4  || tb.test_case == 0) test_o_reset($sformatf("basic_o_reset%s", suffix));

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
