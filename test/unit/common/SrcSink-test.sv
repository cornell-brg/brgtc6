`timescale 1ns/1ps

`ifndef BRGTC6_SRC_SINK_TEST
`define BRGTC6_SRC_SINK_TEST

`include "utils/auto_src_sink/SrcSinkDualClkTB.sv"

import "DPI-C" function int get_system_time_seed();

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam            p_num_duts               = 5;
  localparam integer    p_bit_widths[p_num_duts] = '{4, 8, 16, 32, 64};
  localparam integer    p_num_msgs[p_num_duts]   = '{64, 32, 16, 8, 4};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  // Generate test benches
  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      SrcSinkTest #(
        .p_bit_width(p_bit_widths[i]),
        .p_num_msgs(p_num_msgs[i])
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
module SrcSinkTest #(
  parameter p_bit_width = 8,
  parameter p_num_msgs = 8
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
SrcSinkDualClkTB #(
  .p_msg_nbits(p_bit_width),
  .p_num_msgs(p_num_msgs),
  .p_timeout_period(100000)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
assign sink_msg = src_msg;
assign sink_val = src_val;
assign src_rdy = sink_rdy;

//----------------------------------------------------------------------
// test_basic
//----------------------------------------------------------------------
task automatic test_basic(
  string  name,
  integer seed = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  for (int i = 0; i < p_num_msgs; i++) begin
    tb.test_case_write_idx(p_bit_width'($urandom() % 256), i);
  end

  tb.test_case_begin(
    name, 
    10,
    10,
    30,
    30,
    1,
    1,
    seed
  );

  tb.test_case_wait_done();
  #100;
endtask

//----------------------------------------------------------------------
// Main execution block
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_bw_%0d_nm_%0d", p_bit_width, p_num_msgs);
  tb.test_bench_start($sformatf("SrcSinkTest%s", suffix));
  
  if (tb.test_case == 1 || tb.test_case == 0) test_basic($sformatf("basic_test_1%s", suffix));
  if (tb.test_case == 2 || tb.test_case == 0) test_basic($sformatf("basic_test_2%s", suffix));

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
