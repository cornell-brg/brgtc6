`timescale 1ns/1ps

`ifndef BRGTC6_SINGLE_LINK_V1_TEST
`define BRGTC6_SINGLE_LINK_V1_TEST

`include "top-full/v1/Upstream.sv"
`include "top-full/v1/Downstream.sv"
`include "utils/auto_src_sink/SrcSinkDualClkTB.sv"
`include "utils/TestUtilsDefs.sv"

`ifndef BRGTC6_TIME_SEED
`define BRGTC6_TIME_SEED
import "DPI-C" function int get_system_time_seed();
`endif

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam            p_num_duts                  = 3;
  localparam integer    p_bit_widths[p_num_duts]    = '{4, 5, 8};
  localparam integer    p_max_credits[p_num_duts]   = '{8, 16, 32};
  localparam integer    p_buffer_depths[p_num_duts] = '{4, 16, 64};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  // Generate test benches
  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      SingleLinkV1Test #(
        .p_bit_width(p_bit_widths[i]),
        .p_max_credit(p_max_credits[i]),
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
// SingleLinkV1Test
//----------------------------------------------------------------------
module SingleLinkV1Test #(
  parameter p_bit_width       = 5,
  parameter p_buffer_depth    = 8,
  parameter p_max_credit      = 8,
  parameter p_clk_width       = 4,
  parameter p_max_clk_pd_mult = 5,
  parameter p_max_rst_delay   = 50,
  parameter p_num_msgs        = 20
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
  .p_num_msgs(p_num_msgs)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------

logic [p_bit_width-1:0] cred_msg;
logic cred_val, cred_clk, cred_rst, cred_cred;

Upstream #(
  .bit_width(p_bit_width),
  .max_cred(p_max_credit),
  .clk_width(p_clk_width)
) upstream (
  .clk(src_clk),
  .reset(src_rst),
  .istream_msg(src_msg),
  .istream_val(src_val),
  .istream_rdy(src_rdy),
  .cred_msg(cred_msg),
  .cred_val(cred_val),
  .cred_clk(cred_clk),
  .cred_rst(cred_rst),
  .cred_cred(cred_cred)
);

Downstream #(
  .bit_width(p_bit_width),
  .buffer_depth(p_buffer_depth)
) downstream (
  .clk(sink_clk),
  .reset(sink_rst),
  .ostream_msg(sink_msg),
  .ostream_val(sink_val),
  .ostream_rdy(sink_rdy),
  .cred_msg(cred_msg),
  .cred_val(cred_val),
  .cred_clk(cred_clk),
  .cred_rst(cred_rst),
  .cred_cred(cred_cred)
);


//----------------------------------------------------------------------
// test_basic
//----------------------------------------------------------------------
task automatic test_basic (
  string  name,
  integer src_clk_pd_mult  = -1,
  integer sink_clk_pd_mult = -1,
  integer src_rst_delay    = -1,
  integer sink_rst_delay   = -1,
  integer seed             = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  if (src_clk_pd_mult  == -1) src_clk_pd_mult  = 1 + ($urandom() % (p_max_clk_pd_mult));
  if (sink_clk_pd_mult == -1) sink_clk_pd_mult = 1 + ($urandom() % (p_max_clk_pd_mult));
  if (src_rst_delay    == -1) src_rst_delay    = 2**src_clk_pd_mult + ($urandom() % (p_max_rst_delay - 2**src_clk_pd_mult + 1));
  if (sink_rst_delay   == -1) sink_rst_delay   = 2**sink_clk_pd_mult + ($urandom() % (p_max_rst_delay - 2**sink_clk_pd_mult + 1));

  for (int i = 0; i < p_num_msgs; i++) begin
    tb.test_case_write_idx(p_bit_width'($urandom()), i);
  end

  tb.test_case_begin(
    name,
    2**src_clk_pd_mult,
    2**sink_clk_pd_mult,
    src_rst_delay,
    sink_rst_delay,
    1,
    1,
    seed
  );

  tb.test_case_wait_done();
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_bw_%0d_mc_%0d", p_bit_width, p_max_credit);
  tb.test_bench_start($sformatf("SingleLinkV1Test%s", suffix));
  
  if ((tb.test_case == 0) || (tb.test_case == 1)) test_basic($sformatf("basic_1%s", suffix));

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
