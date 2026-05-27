`ifndef BRGTC6_TEST_BENCH_SRC_SINK_DUAL_CLK
`define BRGTC6_TEST_BENCH_SRC_SINK_DUAL_CLK

`include "utils/clock/DualClockUtils.sv"
`include "utils/auto_src_sink/TestSource.sv"
`include "utils/auto_src_sink/TestSink.sv"

//----------------------------------------------------------------------
// SrcSinkDualClkTB
//----------------------------------------------------------------------
/*verilator coverage_off*/
module SrcSinkDualClkTB #(
  parameter p_msg_nbits      = 8,
  parameter p_num_msgs       = 1024,
  parameter p_timeout_period = 10000
)(

  // Source side
  output logic                   src_clk,
  output logic                   src_rst,
  output logic                   src_val,
  input  logic                   src_rdy,
  output logic [p_msg_nbits-1:0] src_msg,

  // Sink side
  output logic                   sink_clk,
  output logic                   sink_rst,
  input  logic                   sink_val,
  output logic                   sink_rdy,
  input  logic [p_msg_nbits-1:0] sink_msg,

  // Testbench status
  output logic done,
  output logic pass
);

// For checking test case
logic case_fail;
logic case_pass;

// Done logic
logic src_done;
logic sink_done;
logic test_case_done;
assign test_case_done = src_done && sink_done;

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

// Test source
TestSource #(
  .p_msg_nbits(p_msg_nbits),
  .p_num_msgs(p_num_msgs)
) src (
  .clk(src_clk),
  .reset(src_rst),
  .val(src_val),
  .rdy(src_rdy),
  .msg(src_msg),
  .done(src_done)
);

// Test sink
TestSink #(
  .p_msg_nbits(p_msg_nbits),
  .p_num_msgs(p_num_msgs)
) sink (
  .clk(sink_clk),
  .reset(sink_rst),
  .val(sink_val),
  .rdy(sink_rdy),
  .msg(sink_msg),
  .fail(case_fail),
  .pass(case_pass),
  .done(sink_done)
);

//----------------------------------------------------------------------
// Check for clock timeout
//----------------------------------------------------------------------
logic timeout_occurred;
always @(posedge timeout_occurred) begin
  $write($sformatf("\n%s%s\n", results, `BRGTC6_RESET));
  $write($sformatf("\n%s------ %s FAILED ------%s\n", `BRGTC6_RED, tb_name, `BRGTC6_RESET));
  pass = 0;
  done = 1;
end

//----------------------------------------------------------------------
// test_bench_start
//----------------------------------------------------------------------
task test_bench_start(string l_name);
  tb_name = l_name;
  $write($sformatf("\nStarting %s", tb_name));
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
  integer l_seed = -1,
  bit     restart = 0
);
  seed = l_seed;
  if (!restart) results = {results, $sformatf("\n - %s @ %0dns ", test_name, $time)};
  clk_utils.set_clock(
    src_clk_period,
    sink_clk_period
  );
  clk_utils.do_reset(
    src_rst_delay,
    sink_rst_delay,
    src_rst_en,
    sink_rst_en
  );
endtask

//----------------------------------------------------------------------
// test_bench_end
//----------------------------------------------------------------------
task test_bench_end;
  if (failed) begin
    $write($sformatf("\n%s%s\n", results, `BRGTC6_RESET));
    $write($sformatf("\n%s------ %s FAILED ------%s\n", `BRGTC6_RED, tb_name, `BRGTC6_RESET));
    pass = 0;
  end
  else begin
    $write($sformatf("\n%s%s\n", results, `BRGTC6_RESET));
    $write($sformatf("\n%s------ %s PASSED ------%s\n", `BRGTC6_GREEN, tb_name, `BRGTC6_RESET));
    pass = 1;
  end
  done = 1;
endtask

//----------------------------------------------------------------------
// test_case_wait_done
//----------------------------------------------------------------------
task test_case_wait_done;
  while(!test_case_done) #1;
endtask

//----------------------------------------------------------------------
// reset_auto_source_sink
//----------------------------------------------------------------------
task reset_auto_src_sink;
  src.last_index = 0;
  sink.last_index = 0;
endtask

//----------------------------------------------------------------------
// test_case_write_idx
//----------------------------------------------------------------------
task test_case_write_idx ([p_msg_nbits-1:0] val, integer idx);
  src.m[idx] = val;
  sink.m[idx] = val;
  if(idx >= src.last_index) src.last_index = idx + 1;
  if(idx >= sink.last_index) sink.last_index = idx + 1;
endtask

//----------------------------------------------------------------------
// test_case_write_src_idx
//----------------------------------------------------------------------
task test_case_write_src_idx ([p_msg_nbits-1:0] val, integer idx);
  src.m[idx] = val;
  if(idx >= src.last_index) src.last_index = idx + 1;
endtask

//----------------------------------------------------------------------
// test_case_write_sink_idx
//----------------------------------------------------------------------
task test_case_write_sink_idx ([p_msg_nbits-1:0] val, integer idx);
  sink.m[idx] = val;
  if(idx >= sink.last_index) sink.last_index = idx + 1;
endtask

//----------------------------------------------------------------------
// Auto test case check
//----------------------------------------------------------------------
always @(posedge sink_clk) begin
  if (case_fail) begin
    case(verbose)
      0: results = {results, $sformatf("%sF(Seed=%0d)%s",`BRGTC6_RED, seed, `BRGTC6_RESET)};
      1: results = {results, $sformatf("\n -- %sAUTO FAIL @ %0dns - Expected=%x : Actual=%x | Seed=%0d%s", `BRGTC6_RED, $time, sink.m[sink.index], sink.msg, seed, `BRGTC6_RESET)};
    endcase
    failed <= 1;
  end
  else if (case_pass) begin
    case(verbose)
      0: results = {results, $sformatf("%s.%s", `BRGTC6_GREEN, `BRGTC6_RESET)};
      1: results = {results, $sformatf("\n -- %sAUTO PASS @ %0dns - Expected=Actual=%x%s", `BRGTC6_GREEN, $time, sink.msg, `BRGTC6_RESET)};
    endcase
  end
end

//----------------------------------------------------------------------
// Manual test case check
//----------------------------------------------------------------------
task automatic test_case_check(logic[p_msg_nbits-1:0] _ref, logic[p_msg_nbits-1:0] _dut, string msg = "");
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
