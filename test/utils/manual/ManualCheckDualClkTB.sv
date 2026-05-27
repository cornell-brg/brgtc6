`ifndef BRGTC6_TEST_BENCH_MANUAL_CHECK_DUAL_CLK
`define BRGTC6_TEST_BENCH_MANUAL_CHECK_DUAL_CLK

`include "utils/clock/DualClockUtils.sv"

//----------------------------------------------------------------------
// ManualCheckDualClkTB
//----------------------------------------------------------------------
/*verilator coverage_off*/
module ManualCheckDualClkTB #(
  parameter p_chk_nbits      = 8,
  parameter p_timeout_period = 10000
)(

  // Source side
  output logic src_clk,
  output logic src_rst,

  // Sink side
  output logic sink_clk,
  output logic sink_rst,
  
  // Testbench status
  output logic done,
  output logic pass
);

// Name
string tb_name;

// Fail logic
logic failed = 0;

// Verbosity
integer verbose;

// Seed
integer seed;

// Results
string results;

// Clock utils
DualClockUtils #(
  .p_timeout_period(p_timeout_period)
) clk_utils (
  .clk_1(src_clk),
  .rst_1(src_rst),
  .clk_2(sink_clk),
  .rst_2(sink_rst),
  .*
);

//----------------------------------------------------------------------
// Check for clock timeout
//----------------------------------------------------------------------
logic timeout_occurred;
always @(posedge timeout_occurred) begin
  $write($sformatf("\n%s%s\n", results, `BRGTC6_RESET));
  $write($sformatf("\n%s------ %s FAILED ------%s\n", `BRGTC6_RED, tb_name, `BRGTC6_RESET));
  done = 1;
end

//----------------------------------------------------------------------
// test_bench_start
//----------------------------------------------------------------------
task test_bench_start(string l_name);
  tb_name = l_name;
  $display("Starting %s", tb_name);
endtask

//----------------------------------------------------------------------
// test_bench_end
//----------------------------------------------------------------------
task test_bench_end;
  if (failed) begin
    $write($sformatf("\n%s%s\n", results, `BRGTC6_RESET));
    $write($sformatf("\n%s------ %s FAILED ------%s\n", `BRGTC6_RED, tb_name, `BRGTC6_RESET));
  end
  else begin
    $write($sformatf("\n%s%s\n", results, `BRGTC6_RESET));
    $write($sformatf("\n%s------ %s PASSED ------%s\n", `BRGTC6_GREEN, tb_name, `BRGTC6_RESET));
    pass = 1;
  end
  done = 1;
endtask

//----------------------------------------------------------------------
// test_case_begin
//----------------------------------------------------------------------
task test_case_begin (
  string  test_name,
  integer src_clk_period,
  integer sink_clk_period,
  integer src_rst_delay,
  integer sink_rst_delay,
  bit     src_rst_en,
  bit     sink_rst_en,
  integer l_seed = -1
);
  results = {results, $sformatf("\n - %s @ %0dns ", test_name, $time)};
  clk_utils.set_clock (
    src_clk_period,
    sink_clk_period
  );
  clk_utils.do_reset (
    src_rst_delay,
    sink_rst_delay,
    src_rst_en,
    sink_rst_en
  );
  seed = l_seed;
endtask

//----------------------------------------------------------------------
// do_reset
//----------------------------------------------------------------------
task do_reset (
  integer src_rst_delay,
  integer sink_rst_delay,
  bit     src_rst_en      = 1,
  bit     sink_rst_en     = 1
);
  clk_utils.do_reset (
    src_rst_delay,
    sink_rst_delay,
    src_rst_en,
    sink_rst_en
  );
endtask

//----------------------------------------------------------------------
// Test case check
//----------------------------------------------------------------------
task automatic test_case_check(logic[p_chk_nbits-1:0] _ref, logic[p_chk_nbits-1:0] _dut, string msg = "");
  if (_ref !== (_ref ^ _dut ^ _ref)) begin
    case(verbose)
      0: results = {results, $sformatf("%sF(Seed=%0d)%s",`BRGTC6_RED, seed, `BRGTC6_RESET)};
      1: results = {results, $sformatf("\n -- %s%s FAIL @ %0dns - Expected=%x : Actual=%x | Seed=%0d%s", `BRGTC6_RED, msg, $time, _ref, _dut, seed, `BRGTC6_RESET)};
    endcase
    failed = 1;
  end
  else begin
    case(verbose)
      0: results = {results, $sformatf("%s.%s", `BRGTC6_GREEN, `BRGTC6_RESET)};
      1: results = {results, $sformatf("\n -- %s%s PASS @ %0dns - Expected=Actual=%x%s", `BRGTC6_GREEN, msg, $time, _dut, `BRGTC6_RESET)};
    endcase
  end
endtask

//----------------------------------------------------------------------
// Plusarg evaluation
//----------------------------------------------------------------------
string vcd_filename;
integer test_case = 0;
initial begin
  done = 0;
  pass = 0;
  if (!$value$plusargs("test-case=%d", test_case)) test_case = 0;
  if ($value$plusargs("dump-vcd=%s", vcd_filename)) begin
    $dumpfile(vcd_filename);
    $dumpvars(0, Top);
  end
  if ($test$plusargs("verbose")) verbose = 1;
  else verbose = 0;
end

endmodule
/*verilator coverage_on*/

`endif
