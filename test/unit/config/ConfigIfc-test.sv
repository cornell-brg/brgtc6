`timescale 1ns/1ps

`ifndef BRGTC6_ASYNC_CFG_IFC_TEST
`define BRGTC6_ASYNC_CFG_IFC_TEST

`include "utils/manual/ManualCheckSingleClkTB.sv"
`include "utils/TestUtilsDefs.sv"
`include "config/ConfigIfc.sv"

import "DPI-C" function int get_system_time_seed();

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam            p_num_duts                       = 5;
  localparam integer    p_resp_buffer_depths[p_num_duts] = '{4, 8, 16, 32, 64};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  // Generate test benches
  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      ConfigIfcTest #(
        .p_resp_buffer_depth(p_resp_buffer_depths[i])
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
// ConfigIfcTest
//----------------------------------------------------------------------
module ConfigIfcTest #(
  parameter p_addr_width = 4,
  parameter p_config_width = 8,
  parameter p_clk_div_width = 4,
  parameter p_resp_buffer_depth = 4,
  parameter p_bit_width = p_addr_width + p_config_width,
  parameter p_max_msg_delay = 10
) (
  input  logic go,
  output logic done,
  output logic pass
);

logic                   clk;
logic                   reset;

logic [p_bit_width-1:0] reqstream_msg;
logic                   reqstream_val;
logic                   reqstream_rdy;
logic [p_bit_width-1:0] respstream_msg;
logic                   respstream_val;
logic                   respstream_rdy;

// verilator lint_off UNUSED
// verilator lint_off UNDRIVEN
logic cfg_loopback;

logic cfg_pat_bypass;
logic cfg_pattern_mode;
logic [p_config_width-1:0] cfg_pattern_1_up, cfg_pattern_1_down;
logic [p_config_width-1:0] cfg_pattern_2_up, cfg_pattern_2_down;

logic [1:0] cfg_pattern_state;
logic [4:0] cfg_pat_err_count;

logic cfg_go;
logic [p_clk_div_width-1:0] cfg_clk_div_factor;
logic [p_clk_div_width-1:0] cfg_clk_div_skew;

logic cfg_crc_error;

logic [p_config_width-1:0] cfg_up_rpr_offset;
logic [p_config_width-1:0] cfg_dn_rpr_offset;
// verilator lint_on UNUSED
// verilator lint_on UNDRIVEN

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
ManualCheckSingleClkTB #(
  .p_chk_nbits(p_bit_width)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
ConfigIfc #(
  .p_channel_width(p_config_width),
  .p_clk_div_width(p_clk_div_width),
  .p_resp_buffer_depth(p_resp_buffer_depth),
  .p_config_width(p_config_width),
  .p_addr_width(p_addr_width),
  .p_input_width(p_bit_width)
) dut ( .* );

//----------------------------------------------------------------------
// test_basic_pattern
//----------------------------------------------------------------------
task automatic test_basic_pattern (
  string  name,
  integer seed = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);
  integer rand_num = $urandom();
  integer sent_msg = 0;

  // Synchronous reset
  @(posedge clk);
  tb.test_case_begin (
    name,
    10,
    30,
    seed
  );

  respstream_rdy = 1;

  // Check reset is default pattern
  tb.test_case_check(p_config_width'(`CFG_DEF_PATTERN_1), p_config_width'(cfg_pattern_1_up), "cfg_def_pattern_1");
  tb.test_case_check(p_config_width'(`CFG_DEF_PATTERN_2), p_config_width'(cfg_pattern_2_up), "cfg_def_pattern_2");

  // Send pattern 1 message
  reqstream_msg = {`CFG_ADDR_PATTERN_1_UP, {p_config_width{1'b1}}};
  while (sent_msg == 0) begin
    reqstream_val = 1;
    @(posedge clk);
    if (reqstream_rdy == 1) begin
      sent_msg = 1;
      #1; // hold time
    end
    reqstream_val = 0;
    #(1 + ($urandom() % (p_max_msg_delay)));
  end

  // Wait for response - check resp_msg is correct as well as pattern
  while (respstream_val == 0) #1;
  tb.test_case_check({`CFG_ADDR_PATTERN_1_UP, {p_config_width{1'b1}}}, respstream_msg, "respstream_msg");
  tb.test_case_check(p_bit_width'({1'b0, {p_config_width{1'b1}}}), p_bit_width'(cfg_pattern_1_up), "cfg_pattern_1_up");

  // Send pattern 2 message
  sent_msg = 0;
  reqstream_msg = {`CFG_ADDR_PATTERN_2_UP, p_config_width'(rand_num)};
  while (sent_msg == 0) begin
    reqstream_val = 1;
    @(posedge clk);
    if (reqstream_rdy == 1) begin
      sent_msg = 1;
      #1; // hold time
    end
    reqstream_val = 0;
    #(1 + ($urandom() % (p_max_msg_delay)));
  end

  // Wait for response - check resp_msg is correct as well as pattern
  while (respstream_val == 0) #1;
  tb.test_case_check({`CFG_ADDR_PATTERN_2_UP, p_config_width'(rand_num)}, respstream_msg, "respstream_msg");
  tb.test_case_check(p_bit_width'({1'b0, p_config_width'(rand_num)}), p_bit_width'(cfg_pattern_2_up), "cfg_pattern_2_up");

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_bd_%0d", p_resp_buffer_depth);
  tb.test_bench_start($sformatf("ConfigIfcTest%s", suffix));
  
  if (tb.test_case == 1  || tb.test_case == 0) test_basic_pattern($sformatf("basic_pattern_all_1s%s", suffix));

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif /* BRGTC6_ASYNC_CFG_IFC_TEST */
