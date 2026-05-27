`ifndef BRGTC6_TEST_BENCH_TWO_WAY_SRC_SINK_DUAL_CLK
`define BRGTC6_TEST_BENCH_TWO_WAY_SRC_SINK_DUAL_CLK

`include "utils/clock/DualClockUtils.sv"
`include "utils/auto_src_sink/TestSource.sv"
`include "utils/auto_src_sink/TestSink.sv"

//----------------------------------------------------------------------
// TwoWaySrcSinkDualClkTB
//----------------------------------------------------------------------
/*verilator coverage_off*/
module TwoWaySrcSinkDualClkTB #(
  parameter p_msg_nbits      = 8,
  parameter p_num_msgs       = 1024,
  parameter p_timeout_period = 10000
)(

  output logic                   clk_1,
  output logic                   rst_1,
  output logic                   clk_2,
  output logic                   rst_2,

  // Source side ---------------------------------------------------------------

  // Source 1
  output logic                   src_val_1,
  input  logic                   src_rdy_1,
  output logic [p_msg_nbits-1:0] src_msg_1,

  // Source 2
  output logic                   src_val_2,
  input  logic                   src_rdy_2,
  output logic [p_msg_nbits-1:0] src_msg_2,

  // Sink side -----------------------------------------------------------------

  // Sink 1
  input  logic                   sink_val_1,
  output logic                   sink_rdy_1,
  input  logic [p_msg_nbits-1:0] sink_msg_1,

  // Sink 2
  input  logic                   sink_val_2,
  output logic                   sink_rdy_2,
  input  logic [p_msg_nbits-1:0] sink_msg_2,

  // Testbench status
  output logic done,
  output logic pass
);

// For checking test case
logic case_fail_1, case_fail_2;
logic case_pass_1, case_pass_2;

// Done logic
logic src_done_1, src_done_2;
logic sink_done_1, sink_done_2;
logic test_case_done;
assign test_case_done = src_done_1 && sink_done_1 && src_done_2 && sink_done_2;

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
) clk_utils ( .* );

// Test source 1
TestSource #(
  .p_msg_nbits(p_msg_nbits),
  .p_num_msgs(p_num_msgs)
) src_1 (
  .clk(clk_1),
  .reset(rst_1),
  .val(src_val_1),
  .rdy(src_rdy_1),
  .msg(src_msg_1),
  .done(src_done_1)
);

// Test source 2
TestSource #(
  .p_msg_nbits(p_msg_nbits),
  .p_num_msgs(p_num_msgs)
) src_2 (
  .clk(clk_2),
  .reset(rst_2),
  .val(src_val_2),
  .rdy(src_rdy_2),
  .msg(src_msg_2),
  .done(src_done_2)
);

// Test sink 1
TestSink #(
  .p_msg_nbits(p_msg_nbits),
  .p_num_msgs(p_num_msgs)
) sink_1 (
  .clk(clk_1),
  .reset(rst_1),
  .val(sink_val_1),
  .rdy(sink_rdy_1),
  .msg(sink_msg_1),
  .fail(case_fail_1),
  .pass(case_pass_1),
  .done(sink_done_1)
);

// Test sink 2
TestSink #(
  .p_msg_nbits(p_msg_nbits),
  .p_num_msgs(p_num_msgs)
) sink_2 (
  .clk(clk_2),
  .reset(rst_2),
  .val(sink_val_2),
  .rdy(sink_rdy_2),
  .msg(sink_msg_2),
  .fail(case_fail_2),
  .pass(case_pass_2),
  .done(sink_done_2)
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
  integer clk_pd_1,
  integer clk_pd_2,
  integer rst_delay_1,
  integer rst_delay_2,
  bit     rst_en_1,
  bit     rst_en_2,
  integer l_seed = -1,
  bit     restart = 0
);
  seed = l_seed;
  if (!restart) results = {results, $sformatf("\n - %s @ %0dns w/ seed %0d ", test_name, $time, seed)};
  clk_utils.set_clock(
    clk_pd_1,
    clk_pd_2
  );
  clk_utils.do_reset(
    rst_delay_1,
    rst_delay_2,
    rst_en_1,
    rst_en_2
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
  src_1.last_index = 0;
  src_2.last_index = 0;
  sink_1.last_index = 0;
  sink_2.last_index = 0;
endtask

//----------------------------------------------------------------------
// test_case_write_idx
//----------------------------------------------------------------------
task test_case_write_idx ([p_msg_nbits-1:0] val, integer idx, integer src_sink_idx);
  if (src_sink_idx == 1 || src_sink_idx == 0) begin
    src_1.m[idx] = val;
    sink_1.m[idx] = val;
    if(idx >= src_1.last_index) src_1.last_index = idx + 1;
    if(idx >= sink_1.last_index) sink_1.last_index = idx + 1;
  end
  if (src_sink_idx == 2 || src_sink_idx == 0) begin
    src_2.m[idx] = val;
    sink_2.m[idx] = val;
    if(idx >= src_2.last_index) src_2.last_index = idx + 1;
    if(idx >= sink_2.last_index) sink_2.last_index = idx + 1;
  end
endtask

//----------------------------------------------------------------------
// test_case_write_src_idx
//----------------------------------------------------------------------
task test_case_write_src_idx ([p_msg_nbits-1:0] val, integer idx, integer src_sink_idx);
  if (src_sink_idx == 1 || src_sink_idx == 0) begin
    src_1.m[idx] = val;
    if(idx >= src_1.last_index) src_1.last_index = idx + 1;
  end
  if (src_sink_idx == 2 || src_sink_idx == 0) begin
    src_2.m[idx] = val;
    if(idx >= src_2.last_index) src_2.last_index = idx + 1;
  end
endtask

//----------------------------------------------------------------------
// test_case_write_sink_idx
//----------------------------------------------------------------------
task test_case_write_sink_idx ([p_msg_nbits-1:0] val, integer idx, integer src_sink_idx);
  if (src_sink_idx == 1 || src_sink_idx == 0) begin
    sink_1.m[idx] = val;
    if(idx >= sink_1.last_index) sink_1.last_index = idx + 1;
  end
  if (src_sink_idx == 2 || src_sink_idx == 0) begin
    sink_2.m[idx] = val;
    if(idx >= sink_2.last_index) sink_2.last_index = idx + 1;
  end
endtask

//----------------------------------------------------------------------
// Auto test case check
//----------------------------------------------------------------------
always @(posedge clk_1 or posedge clk_2) begin
  if (case_fail_1 || case_fail_2) failed <= 1;
end

always @(posedge clk_1) begin
  if (case_fail_1) begin
    case(verbose)
      0: results = {results, $sformatf("%sF%s",`BRGTC6_RED, `BRGTC6_RESET)};
      1: results = {results, $sformatf("\n -- %sAUTO 1 FAIL @ %0dns - Expected=%x : Actual=%x%s", `BRGTC6_RED, $time, sink_1.m[sink_1.index], sink_1.msg, `BRGTC6_RESET)};
    endcase
  end
  else if (case_pass_1) begin
    case(verbose)
      0: results = {results, $sformatf("%s.%s", `BRGTC6_GREEN, `BRGTC6_RESET)};
      1: results = {results, $sformatf("\n -- %sAUTO 1 PASS @ %0dns - Expected=Actual=%x%s", `BRGTC6_GREEN, $time, sink_1.msg, `BRGTC6_RESET)};
    endcase
  end
end

always @(posedge clk_2) begin
  if (case_fail_2) begin
    case(verbose)
      0: results = {results, $sformatf("%sF%s",`BRGTC6_RED, `BRGTC6_RESET)};
      1: results = {results, $sformatf("\n -- %sAUTO 2 FAIL @ %0dns - Expected=%x : Actual=%x%s", `BRGTC6_RED, $time, sink_2.m[sink_2.index], sink_2.msg, `BRGTC6_RESET)};
    endcase
  end
  else if (case_pass_2) begin
    case(verbose)
      0: results = {results, $sformatf("%s.%s", `BRGTC6_GREEN, `BRGTC6_RESET)};
      1: results = {results, $sformatf("\n -- %sAUTO 2 PASS @ %0dns - Expected=Actual=%x%s", `BRGTC6_GREEN, $time, sink_2.msg, `BRGTC6_RESET)};
    endcase
  end
end

//----------------------------------------------------------------------
// Manual test case check
//----------------------------------------------------------------------
task automatic test_case_check(logic[p_msg_nbits-1:0] _ref, logic[p_msg_nbits-1:0] _dut, string msg = "");
  if (_ref !== (_ref ^ _dut ^ _ref)) begin
    case(verbose)
      0: results = {results, $sformatf("%sF%s",`BRGTC6_RED, `BRGTC6_RESET)};
      1: results = {results, $sformatf("\n -- %s%s FAIL @ %0dns - Expected=%x : Actual=%x%s", `BRGTC6_RED, msg, $time, _ref, _dut, `BRGTC6_RESET)};
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
