`timescale 1ns/1ps

`ifndef BRGTC6_SINGLE_LINK_V2_TEST
`define BRGTC6_SINGLE_LINK_V2_TEST

`include "top-full/v2/Link.sv"
`include "utils/auto_src_sink/SrcSinkSingleClkTB.sv"
`include "utils/cred_skewer/CredSkewer.sv"
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
  localparam            p_num_duts                       = 3;
  localparam integer    p_channel_widths[p_num_duts]     = '{4, 5, 8};
  localparam integer    p_max_credits[p_num_duts]        = '{8, 16, 32};
  localparam integer    p_resp_buffer_depths[p_num_duts] = '{4, 16, 64};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  // Generate test benches
  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      SingleLinkV2Test #(
        .p_channel_width(p_channel_widths[i]),
        .p_max_credit(p_max_credits[i]),
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
// SingleLinkV2Test
//----------------------------------------------------------------------
module SingleLinkV2Test #(
  parameter p_addr_width        = 4, // don't change (fixed by design)
  parameter p_channel_width     = 5, // must be <= config width
  parameter p_config_width      = 8, // don't change (fixed by design)
  parameter p_input_width       = p_addr_width + p_config_width,
  parameter p_max_clk_pd        = 100, // ns
  parameter p_max_clk_div_mult  = 4,
  parameter p_clk_width         = 5, // must be <= config width
  parameter p_max_credit        = 8,
  parameter p_max_msgs          = 100,
  parameter p_max_rst_delay     = 500,
  parameter p_resp_buffer_depth = 4
) ( 
  input  logic go,
  output logic done,
  output logic pass
);

logic                     clk;
logic                     reset;

// Source side (to config interface)
logic                     src_val;
logic                     src_rdy;
logic [p_input_width-1:0] src_msg;

// Sink side (to config interface)
logic                     sink_val;
logic                     sink_rdy;
logic [p_input_width-1:0] sink_msg;

logic up_cred_clk, up_cred_rst, up_cred_val, up_cred_cred;
logic down_cred_clk, down_cred_rst, down_cred_val, down_cred_cred;
logic [p_channel_width-1:0] up_cred_msg;
logic [p_channel_width-1:0] down_cred_msg;

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
SrcSinkSingleClkTB #(
  .p_msg_nbits(p_input_width),
  .p_num_msgs(p_max_msgs),
  .p_timeout_period(1000000)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
Link #(
  .p_channel_width(p_channel_width),
  .p_max_credit(p_max_credit),
  .p_clk_width(p_clk_width),
  .p_config_width(p_config_width),
  .p_addr_width(p_addr_width),
  .p_resp_buffer_depth(p_resp_buffer_depth)
) link (
  .upstream_msg({p_channel_width{1'b0}}),
  .upstream_val(1'b0),
  // verilator lint_off PINCONNECTEMPTY
  .upstream_rdy(),
  .downstream_msg(),
  .downstream_val(),
  // verilator lint_on PINCONNECTEMPTY
  .downstream_rdy(1'b0),
  .reqstream_msg(src_msg),
  .reqstream_val(src_val),
  .reqstream_rdy(src_rdy),
  .respstream_msg(sink_msg),
  .respstream_val(sink_val),
  .respstream_rdy(sink_rdy),
  .*
);

//----------------------------------------------------------------------
// Credit interface skewer
//----------------------------------------------------------------------
logic [31:0] msg_skews[p_channel_width];
logic [31:0] val_skew, clk_skew, rst_skew, cred_skew;

CredSkewer #(
  .p_msg_nbits (p_channel_width),
  .p_max_skew  (2*p_max_clk_pd)
) cred_skewer ( 
  .en(1'b1),
  .*
);

//----------------------------------------------------------------------
// test_standard_pattern
//----------------------------------------------------------------------
task automatic test_standard_pattern (
  string  name,
  integer clk_pd       = -1,
  integer clk_div_mult = -1,
  integer rst_delay    = -1,
  integer inj_skew     = -1,
  integer skew_set     = -1, // must be < 2**clk_div_mult,
  integer pattern      = -1, // 0 = LFSR, 1 = fixed pattern
  integer seed         = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  if (clk_pd       == -1) clk_pd       = 2 + ($urandom() % (p_max_clk_pd - 1));
  if (clk_div_mult == -1) clk_div_mult = $urandom() % (p_max_clk_div_mult + 1);
  if (rst_delay    == -1) rst_delay    = clk_pd + ($urandom() % (p_max_rst_delay - clk_pd + 1));
  if (skew_set     == -1) skew_set     = 0;
  if (pattern      == -1) pattern      = $urandom() % 2;

  // Initialize skews (inj_skew != -1 means it is the upper limit for possible skews)
  for (int i = 0; i < p_channel_width; i++)
    msg_skews[i] = inj_skew == -1 ? $urandom() % (clk_pd/2) : $urandom() % (inj_skew + 1); // can tolerate < half clk cycle of skew without deskewing
  val_skew = inj_skew == -1 ? $urandom() % (clk_pd/2) : $urandom() % (inj_skew + 1);
  clk_skew = 0;
  rst_skew = inj_skew == -1 ? $urandom() % (clk_pd/2) : $urandom() % (inj_skew + 1);
  cred_skew = inj_skew == -1 ? $urandom() % (clk_pd/2) : $urandom() % (inj_skew + 1);

  tb.reset_auto_src_sink();
  
  tb.test_case_begin(
    name,
    clk_pd,
    rst_delay,
    seed
  );

  tb.test_case_write_idx({`CFG_ADDR_CLK_DIV_FACTOR, p_config_width'(2**clk_div_mult)}, 0); // Set clock divider
  tb.test_case_write_idx({`CFG_ADDR_CLK_DIV_SKEW, p_config_width'(skew_set)}, 1); // Set clock skew
  tb.test_case_write_idx({`CFG_ADDR_PATTERN_MODE, p_config_width'(pattern)}, 2); // Set pattern mode based on test input
  tb.test_case_write_idx({`CFG_ADDR_PAT_BYPASS, p_config_width'(0)}, 3); // Not bypassing pattern - no upstream/downstream messages
  tb.test_case_write_idx({`CFG_ADDR_GO, p_config_width'(1)}, 4); // Go (upstream and downstream exit reset)
  tb.test_case_write_sink_idx({`CFG_ADDR_PATTERN_STATE, p_config_width'(2)}, 5); // Eventual return value for pattern state reg read

  #(clk_pd*(2**clk_div_mult)*10000); // Need to wait for at least time required for LFSR to calibrate

  tb.test_case_write_src_idx({`CFG_ADDR_PATTERN_STATE, p_config_width'(0)}, 5); // Send pattern state read req to config
  #1;

  tb.test_case_wait_done();
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_cw_%0d_mc_%0d", p_channel_width, p_max_credit);
  tb.test_bench_start($sformatf("SingleLinkV2Test%s", suffix));
  
  // Deskewing tests w/ LFSR pattern -------------------------------------------

  // Idea (for a given injected skew) - start at div_factor = 1 (2**0), set_skew = 0, if doesn't work:
  // -> then increase div_factor to 2, set_skew = 0, if doesn't work:
  // -> then try set_skew = 1, if doesn't work:
  // -> then increase div_factor to 4, set_skew = 0, if doesn't work: ... (set_skew = 1, 2, 3 ...)
  if ((tb.test_case == 0)  || (tb.test_case == 1)) 
    test_standard_pattern(
      .name ($sformatf("lfsr_50_mhz_all_skew_0%s", suffix)),
      .clk_pd(20),
      .clk_div_mult(0),
      .rst_delay(-1),
      .inj_skew(0),
      .skew_set(0),
      .pattern(0)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 2)) 
    test_standard_pattern(
      .name ($sformatf("lfsr_50_mhz_under_deskew_thresh%s", suffix)),
      .clk_pd(20),
      .clk_div_mult(0),
      .rst_delay(-1),
      .inj_skew(9),
      .skew_set(0),
      .pattern(0)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 3)) 
    test_standard_pattern(
      .name ($sformatf("lfsr_50_mhz_over_deskew_thresh%s", suffix)),
      .clk_pd(20),
      .clk_div_mult(1),
      .rst_delay(-1),
      .inj_skew(20),
      .skew_set(0),
      .pattern(0)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 4)) 
    test_standard_pattern(
      .name ($sformatf("lfsr_50_mhz_very_over_deskew_thresh%s", suffix)),
      .clk_pd(20),
      .clk_div_mult(3),
      .rst_delay(-1),
      .inj_skew(100),
      .skew_set(5),
      .pattern(0)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 5)) 
    test_standard_pattern(
      .name ($sformatf("lfsr_rand_freq_under_deskew_thresh%s", suffix)),
      .clk_pd(-1),
      .clk_div_mult(0),
      .rst_delay(-1),
      .inj_skew(-1),
      .skew_set(0),
      .pattern(0)
    );

  // Fixed Pattern tests -------------------------------------------------------
  if ((tb.test_case == 0)  || (tb.test_case == 6)) 
    test_standard_pattern(
      .name ($sformatf("fixed_rand_freq_under_deskew_thresh%s", suffix)),
      .clk_pd(-1),
      .clk_div_mult(0),
      .rst_delay(-1),
      .inj_skew(-1),
      .skew_set(0),
      .pattern(1)
    );

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
