`timescale 1ns/1ps

`ifndef BRGTC6_SINGLE_LINK_V3_TEST
`define BRGTC6_SINGLE_LINK_V3_TEST

`include "top-full/v3/Link.sv"
`include "utils/auto_src_sink/SrcSinkSingleClkTB.sv"
`include "utils/spi/SpiDriverValRdy.sv"
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
  localparam integer    p_channel_widths[p_num_duts]     = '{`BRGTC6_CHANNEL_WIDTH, 5, 4};
  localparam integer    p_max_credits[p_num_duts]        = '{`BRGTC6_MAX_CREDIT, 32, 16};
  localparam integer    p_resp_buffer_depths[p_num_duts] = '{`BRGTC6_RESP_BUFFER_DEPTH, 2, 8};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  // Generate test benches
  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      SingleLinkV3Test #(
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
// SingleLinkV3Test
//----------------------------------------------------------------------
module SingleLinkV3Test #(
  parameter p_addr_width        = `BRGTC6_ADDR_WIDTH, // don't change (fixed by design)
  parameter p_channel_width     = `BRGTC6_CHANNEL_WIDTH, // must be <= config width
  parameter p_config_width      = `BRGTC6_CONFIG_WIDTH, // don't change (fixed by design)
  parameter p_input_width       = p_addr_width + p_config_width + 1,
  parameter p_max_clk_pd        = 100, // ns
  parameter p_min_clk_pd        = 6, // ns
  parameter p_max_clk_div_mult  = 4,
  parameter p_clk_width         = `BRGTC6_CLK_WIDTH, // must be <= config width
  parameter p_max_credit        = `BRGTC6_MAX_CREDIT, // must be = resp buffer depth
  parameter p_max_msgs          = 100,
  parameter p_max_rst_delay     = 100,
  parameter p_resp_buffer_depth = `BRGTC6_RESP_BUFFER_DEPTH,  // must be = max credit
  parameter p_sclk_period       = 1000
) (
  input  logic go,
  output logic done,
  output logic pass
);

logic clk;
logic reset;

// TB -> SPI Driver Val/Rdy
logic                       tb_driver_val;
logic                       tb_driver_rdy;
logic [p_input_width-1:0]   tb_driver_msg;

// SPI Driver -> TB Val/Rdy
logic                       driver_tb_val;
logic                       driver_tb_rdy;
logic [p_input_width-1:0]   driver_tb_msg;

// SPI Driver <-> Link SPI
logic sclk, mosi, miso, cs;

// Link -> Credit Skewer Credit
logic                       link_skewer_clk;
logic                       link_skewer_rst;
logic                       link_skewer_val;
logic [p_channel_width-1:0] link_skewer_msg;
logic                       link_skewer_cred;

// Credit Skewer -> Link Credit
logic                       skewer_link_clk;
logic                       skewer_link_rst;
logic                       skewer_link_val;
logic [p_channel_width-1:0] skewer_link_msg;
logic                       skewer_link_cred;

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
SrcSinkSingleClkTB #(
  .p_msg_nbits      (p_input_width),
  .p_num_msgs       (p_max_msgs),
  .p_timeout_period (100000000)
) tb (
  .src_val  (tb_driver_val),
  .src_rdy  (tb_driver_rdy),
  .src_msg  (tb_driver_msg),
  .sink_val (driver_tb_val),
  .sink_rdy (driver_tb_rdy),
  .sink_msg (driver_tb_msg),
  .*
);

//----------------------------------------------------------------------
// SPI driver w/ Val/Rdy
//----------------------------------------------------------------------
SpiDriverValRdy #(
  .p_bit_width(p_input_width),
  .p_sclk_period(p_sclk_period)
) driver_val_rdy (
  .istream_val(tb_driver_val),
  .istream_rdy(tb_driver_rdy),
  .istream_msg(tb_driver_msg),
  .ostream_val(driver_tb_val),
  .ostream_rdy(driver_tb_rdy),
  .ostream_msg(driver_tb_msg),
  .*
);

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
Link #(
  .p_channel_width     (p_channel_width),
  .p_config_width      (p_config_width),
  .p_max_credit        (p_max_credit),
  .p_clk_width         (p_clk_width),
  .p_addr_width        (p_addr_width),
  .p_resp_buffer_depth (p_resp_buffer_depth),
  .p_input_width       (p_input_width)
) link (
  .up_cred_msg    (link_skewer_msg),
  .up_cred_val    (link_skewer_val),
  .up_cred_clk    (link_skewer_clk),
  .up_cred_rst    (link_skewer_rst),
  .up_cred_cred   (link_skewer_cred),
  .down_cred_msg  (skewer_link_msg),
  .down_cred_val  (skewer_link_val),
  .down_cred_clk  (skewer_link_clk),
  .down_cred_rst  (skewer_link_rst),
  .down_cred_cred (skewer_link_cred),
  .*
);

//----------------------------------------------------------------------
// Credit interface skewer
//----------------------------------------------------------------------
logic [31:0] msg_skews[p_channel_width];
logic [31:0] val_skew, clk_skew, rst_skew, cred_skew;

CredSkewer #(
  .p_msg_nbits (p_channel_width),
  .p_max_skew  (1100)
) cred_skewer (
  .en(1'b1),
  .up_cred_msg    (link_skewer_msg),
  .up_cred_val    (link_skewer_val),
  .up_cred_clk    (link_skewer_clk),
  .up_cred_rst    (link_skewer_rst),
  .up_cred_cred   (link_skewer_cred),
  .down_cred_msg  (skewer_link_msg),
  .down_cred_val  (skewer_link_val),
  .down_cred_clk  (skewer_link_clk),
  .down_cred_rst  (skewer_link_rst),
  .down_cred_cred (skewer_link_cred),
  .*
);

//----------------------------------------------------------------------
// test_standard_pattern
//----------------------------------------------------------------------
task automatic test_standard_pattern (
  string  name,
  integer clk_pd        = -1,
  integer clk_div_mult  = -1,
  integer rst_delay     = -1,
  integer inj_skew      = -1,
  integer skew_set      = -1, // must be < 2**clk_div_mult,
  integer pattern       = -1, // 0 = LFSR, 1 = fixed pattern
  bit     inj_skew_mode = 0, // 0 = random, 1 = alternate between 0 and max
  integer seed          = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);
  integer src_sink_idx = 0;
  bit     skew_zero;

  if (clk_pd       == -1) clk_pd       = p_min_clk_pd + ($urandom() % (p_max_clk_pd - 1)); // always produce even value
  if (clk_div_mult == -1) clk_div_mult = $urandom() % (p_max_clk_div_mult + 1);
  if (rst_delay    == -1) rst_delay    = clk_pd + ($urandom() % (p_max_rst_delay - clk_pd + 1));
  if (skew_set     == -1) skew_set     = 0;
  if (pattern      == -1) pattern      = $urandom() % 2;

  // Initialize skews (inj_skew != -1 means it is the upper limit for possible skews)
  skew_zero = 1'b1;
  for (int i = 0; i < p_channel_width; i++) begin
    msg_skews[i] = inj_skew_mode ? (skew_zero ? 0 : inj_skew) : (inj_skew == -1 ? $urandom() % (clk_pd/2 - 1) : $urandom() % (inj_skew + 1)); // can tolerate < half clk cycle of skew without deskewing
    skew_zero = ~skew_zero;
  end
  val_skew  = inj_skew_mode ? inj_skew : (inj_skew == -1 ? $urandom() % (clk_pd/2 - 1) : $urandom() % (inj_skew + 1));
  clk_skew  = 0;
  rst_skew  = inj_skew_mode ? inj_skew : (inj_skew == -1 ? $urandom() % (clk_pd/2 - 1) : $urandom() % (inj_skew + 1));
  cred_skew = inj_skew_mode ? 0 : (inj_skew == -1 ? $urandom() % (clk_pd/2 - 1) : $urandom() % (inj_skew + 1));

  tb.reset_auto_src_sink();

  tb.test_case_begin(
    name,
    clk_pd,
    rst_delay,
    seed
  );

  tb.test_case_write_idx({logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_FACTOR, p_config_width'(2**clk_div_mult)}, src_sink_idx++); // Set clock divider
  tb.test_case_write_idx({logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_SKEW, p_config_width'(skew_set)}, src_sink_idx++); // Set clock skew
  tb.test_case_write_idx({logic'(`CNFG_MSG), `CFG_ADDR_PATTERN_MODE, p_config_width'(pattern)}, src_sink_idx++); // Set pattern mode based on test input
  tb.test_case_write_idx({logic'(`CNFG_MSG), `CFG_ADDR_PAT_BYPASS, p_config_width'(0)}, src_sink_idx++); // Not bypassing pattern - no upstream/downstream messages
  tb.test_case_write_idx({logic'(`CNFG_MSG), `CFG_ADDR_GO, p_config_width'(1)}, src_sink_idx++); // Go (upstream and downstream exit reset)
  tb.test_case_write_sink_idx({logic'(`CNFG_MSG), `CFG_ADDR_PATTERN_STATE, p_config_width'(2)}, src_sink_idx); // Eventual return value for pattern state reg read

  #(clk_pd*(2**clk_div_mult)*10000); // Need to wait for at least time required for LFSR to calibrate

  tb.test_case_write_src_idx({logic'(`CNFG_MSG), `CFG_ADDR_PATTERN_STATE, p_config_width'(0)}, src_sink_idx++); // Send pattern state read req to config
  #1;

  tb.test_case_wait_done();
  tb.test_case_check(p_input_width'(src_sink_idx), p_input_width'(tb.src.last_index), "src sent all");
  tb.test_case_check(p_input_width'(src_sink_idx), p_input_width'(tb.sink.last_index), "sink recv all");
endtask

//----------------------------------------------------------------------
// test_standard_msg
//----------------------------------------------------------------------
task automatic test_standard_msg (
  string  name,
  integer clk_pd        = -1,
  integer clk_div_mult  = -1,
  integer rst_delay     = -1,
  integer inj_skew      = -1,
  integer skew_set      = -1, // must be < 2**clk_div_mult,
  integer num_msgs      = -1,
  bit     inj_skew_mode = 0, // 0 = random, 1 = alternate between 0 and max
  integer seed          = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);
  integer message;
  integer src_sink_idx = 0;
  bit     skew_zero;

  if (clk_pd       == -1) clk_pd       = p_min_clk_pd + ($urandom() % (p_max_clk_pd - 1)); // always produce even value
  if (clk_div_mult == -1) clk_div_mult = $urandom() % (p_max_clk_div_mult + 1);
  if (rst_delay    == -1) rst_delay    = clk_pd + ($urandom() % (p_max_rst_delay - clk_pd + 1));
  if (skew_set     == -1) skew_set     = 0;
  if (num_msgs     == -1) num_msgs     = 1 + $urandom() % (p_max_msgs);

  // Initialize skews (inj_skew != -1 means it is the upper limit for possible skews)
  skew_zero = 1'b1;
  for (int i = 0; i < p_channel_width; i++) begin
    msg_skews[i] = inj_skew_mode ? (skew_zero ? 0 : inj_skew) : (inj_skew == -1 ? $urandom() % (clk_pd/2 - 1) : $urandom() % (inj_skew + 1)); // can tolerate < half clk cycle of skew without deskewing
    skew_zero = ~skew_zero;
  end
  val_skew  = inj_skew_mode ? inj_skew : (inj_skew == -1 ? $urandom() % (clk_pd/2 - 1) : $urandom() % (inj_skew + 1));
  clk_skew  = 0;
  rst_skew  = inj_skew_mode ? inj_skew : (inj_skew == -1 ? $urandom() % (clk_pd/2 - 1) : $urandom() % (inj_skew + 1));
  cred_skew = inj_skew_mode ? 0 : (inj_skew == -1 ? $urandom() % (clk_pd/2 - 1) : $urandom() % (inj_skew + 1));

  tb.reset_auto_src_sink();
  tb.test_case_write_idx({logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_FACTOR, p_config_width'(2**clk_div_mult)}, src_sink_idx++); // Set clock divider
  tb.test_case_write_idx({logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_SKEW, p_config_width'(skew_set)}, src_sink_idx++); // Set clock skew
  tb.test_case_write_idx({logic'(`CNFG_MSG), `CFG_ADDR_PAT_BYPASS, p_config_width'(1)}, src_sink_idx++); // Bypassing pattern
  tb.test_case_write_idx({logic'(`CNFG_MSG), `CFG_ADDR_GO, p_config_width'(1)}, src_sink_idx++); // Go (upstream and downstream exit reset)
  
  for (int i = 0; i < num_msgs; i++) begin
    message = $urandom() % (2**p_channel_width);
    tb.test_case_write_idx({logic'(`CHNL_MSG), p_config_width'(message)}, src_sink_idx++); // Send message
  end

  tb.test_case_begin(
    name,
    clk_pd,
    rst_delay,
    seed
  );

  tb.test_case_wait_done();
  tb.test_case_check(p_input_width'(src_sink_idx), p_input_width'(tb.src.last_index), "src sent all");
  tb.test_case_check(p_input_width'(src_sink_idx), p_input_width'(tb.sink.last_index), "sink recv all");
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_cw_%0d_mc_%0d_rbd_%0d", p_channel_width, p_max_credit, p_resp_buffer_depth);
  tb.test_bench_start($sformatf("SingleLinkV3Test%s", suffix));

  // Deskewing tests w/ LFSR pattern -------------------------------------------

  // Idea (for a given injected skew) - start at div_factor = 1 (2**0), set_skew = 0, if doesn't work:
  // -> then increase div_factor to 2, set_skew = 0, if doesn't work:
  // -> then try set_skew = 1, if doesn't work:
  // -> then increase div_factor to 4, set_skew = 0, if doesn't work: ... (set_skew = 1, 2, 3 ...)
  if ((tb.test_case == 0)  || (tb.test_case == 1)) 
    test_standard_pattern(
      .name ($sformatf("lfsr_100_mhz_all_skew_0%s", suffix)),
      .clk_pd(10),
      .clk_div_mult(0),
      .rst_delay(-1),
      .inj_skew(0),
      .skew_set(0),
      .pattern(0)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 2)) 
    test_standard_pattern(
      .name ($sformatf("lfsr_100_mhz_under_deskew_thresh_rand_skew%s", suffix)),
      .clk_pd(10),
      .clk_div_mult(0),
      .rst_delay(-1),
      .inj_skew(4),
      .skew_set(0),
      .pattern(0)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 3)) 
    test_standard_pattern(
      .name ($sformatf("lfsr_100_mhz_under_deskew_thresh_alt_skew%s", suffix)),
      .clk_pd(10),
      .clk_div_mult(0),
      .rst_delay(-1),
      .inj_skew(4),
      .skew_set(0),
      .pattern(0),
      .inj_skew_mode(1)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 4)) 
    test_standard_pattern(
      .name ($sformatf("lfsr_100_mhz_at_deskew_thresh%s", suffix)),
      .clk_pd(10),
      .clk_div_mult(1),
      .rst_delay(-1),
      .inj_skew(10),
      .skew_set(0),
      .pattern(0)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 5)) 
    test_standard_pattern(
      .name ($sformatf("lfsr_100_mhz_5x_over_deskew_thresh_rand_skew%s", suffix)),
      .clk_pd(10),
      .clk_div_mult(3),
      .rst_delay(-1),
      .inj_skew(50),
      .skew_set(5),
      .pattern(0)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 6)) 
    test_standard_pattern(
      .name ($sformatf("lfsr_100_mhz_5x_over_deskew_thresh_alt_skew%s", suffix)),
      .clk_pd(10),
      .clk_div_mult(3),
      .rst_delay(-1),
      .inj_skew(50),
      .skew_set(5),
      .pattern(0),
      .inj_skew_mode(1)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 7)) 
    test_standard_pattern(
      .name ($sformatf("lfsr_highest_freq_under_deskew_thresh%s", suffix)),
      .clk_pd(p_min_clk_pd),
      .clk_div_mult(0),
      .rst_delay(-1),
      .inj_skew(-1),
      .skew_set(0),
      .pattern(0)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 8)) 
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
  if ((tb.test_case == 0)  || (tb.test_case == 9)) 
    test_standard_pattern(
      .name ($sformatf("fixed_rand_freq_under_deskew_thresh%s", suffix)),
      .clk_pd(-1),
      .clk_div_mult(0),
      .rst_delay(-1),
      .inj_skew(-1),
      .skew_set(0),
      .pattern(1)
    );

  // Pattern Bypass (custom messages) tests ------------------------------------
  if ((tb.test_case == 0)  || (tb.test_case == 10)) 
    test_standard_msg(
      .name ($sformatf("single_msg_rand_freq_under_deskew_thresh%s", suffix)),
      .clk_pd(-1),
      .clk_div_mult(0),
      .rst_delay(-1),
      .inj_skew(-1),
      .skew_set(0),
      .num_msgs(1)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 12)) 
    test_standard_msg(
      .name ($sformatf("rand_msgs_rand_freq_under_deskew_thresh%s", suffix)),
      .clk_pd(-1),
      .clk_div_mult(0),
      .rst_delay(-1),
      .inj_skew(-1),
      .skew_set(0),
      .num_msgs(-1)
    );
  // Long tests (recommended to only use VCS for these) --------------------------
  if ($test$plusargs("long") || tb.test_case >= 12) begin
    if ((tb.test_case == 0)  || (tb.test_case == 12)) 
      test_standard_pattern(
        .name ($sformatf("lfsr_100_mhz_100x_over_deskew_thresh_rand_skew%s", suffix)),
        .clk_pd(10),
        .clk_div_mult(8),
        .rst_delay(-1),
        .inj_skew(1000),
        .skew_set(0),
        .pattern(0)
      );
    if ((tb.test_case == 0)  || (tb.test_case == 13)) 
      test_standard_pattern(
        .name ($sformatf("lfsr_100_mhz_100x_over_deskew_thresh_alt_skew%s", suffix)),
        .clk_pd(10),
        .clk_div_mult(8),
        .rst_delay(-1),
        .inj_skew(1000),
        .skew_set(0),
        .pattern(0),
        .inj_skew_mode(1)
      );
  end

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
