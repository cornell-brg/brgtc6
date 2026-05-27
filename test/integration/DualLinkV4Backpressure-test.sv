`timescale 1ns/1ps

`ifndef BRGTC6_DUAL_LINK_V4_BACKPRESSURE_TEST
`define BRGTC6_DUAL_LINK_V4_BACKPRESSURE_TEST

`ifdef FFGL_BA
  `define CHNL_MSG 1'b0
  `define CNFG_MSG 1'b1
  `include "config/config_addr_mapV4.sv"
`else
  `include "top-full/v4/Link.sv"
`endif

`include "utils/manual/ManualCheckDualClkTB.sv"
`include "utils/spi/SpiDriverValRdy.sv"
`include "utils/cred_skewer/CredSkewerErrorerV4.sv"
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

  `ifdef FFGL_BA
    localparam            p_num_duts                       = 1;
    localparam integer    p_channel_widths[p_num_duts]     = '{`BRGTC6_CHANNEL_WIDTH};
    localparam integer    p_max_credits[p_num_duts]        = '{`BRGTC6_MAX_CREDIT};
    localparam integer    p_resp_buffer_depths[p_num_duts] = '{`BRGTC6_RESP_BUFFER_DEPTH};
    string                saif_filename;
  `else
    localparam            p_num_duts                       = 3;
    localparam integer    p_channel_widths[p_num_duts]     = '{`BRGTC6_CHANNEL_WIDTH, 5, 4};
    localparam integer    p_max_credits[p_num_duts]        = '{`BRGTC6_MAX_CREDIT, 32, 16};
    localparam integer    p_resp_buffer_depths[p_num_duts] = '{`BRGTC6_RESP_BUFFER_DEPTH, 2, 8};
  `endif

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  // Generate test benches
  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      DualLinkV4BackpressureTest #(
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
    `ifdef FFGL_BA
      if (saif_filename != "") begin
        $set_toggle_region(Top.gen_test[0].test.link_1);
        $toggle_start();
      end
    `endif
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
  `ifdef FFGL_BA
    if (saif_filename != "") begin
      if (!$value$plusargs("dump-saif=%s", saif_filename)) saif_filename = "";
      $toggle_stop();
      $toggle_report(saif_filename, 1e-9, Top.gen_test[0].test.link_1);
    end
  `endif
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
// DualLinkV4BackpressureTest
//----------------------------------------------------------------------
module DualLinkV4BackpressureTest #(
  parameter p_addr_width        = `BRGTC6_ADDR_WIDTH, // don't change (fixed by design)
  parameter p_channel_width     = `BRGTC6_CHANNEL_WIDTH, // must be <= config width
  parameter p_config_width      = `BRGTC6_CONFIG_WIDTH, // don't change (fixed by design)
  parameter p_input_width       = p_addr_width + p_config_width + 1,
  parameter p_max_clk_pd        = 50, // ns
  parameter p_min_clk_pd        = 6, // ns
  parameter p_max_clk_div_mult  = 4,
  parameter p_clk_width         = `BRGTC6_CLK_WIDTH, // must be <= config width
  parameter p_max_credit        = `BRGTC6_MAX_CREDIT, // must be = resp buffer depth
  parameter p_max_msgs          = 100,
  parameter p_max_segs          = 5,
  parameter p_max_msg_delay     = 10000,
  parameter p_max_rst_delay     = 500,
  parameter p_resp_buffer_depth = `BRGTC6_RESP_BUFFER_DEPTH, // must be = max credit
  parameter p_sclk_period       = 1200,
  parameter p_max_addr_val      = 18
) (
  input  logic go,
  output logic done,
  output logic pass
);

logic clk_1, clk_2;
logic rst_1, rst_2;

// Chip 1 -> Chip 2 ------------------------------------------------------------

// TB -> SPI Driver Val/Rdy
logic [p_input_width+1:0]   tb_driver_msg_1;
logic                       tb_driver_val_1;
logic                       tb_driver_rdy_1;

// SPI Driver -> TB Val/Rdy
logic [p_input_width+1:0]   driver_tb_msg_1;
logic                       driver_tb_val_1;
logic                       driver_tb_rdy_1;

// SPI Driver <-> Link SPI
logic sclk_1, mosi_1, miso_1, cs_1;

// Link -> Credit Skewer Credit
logic [p_channel_width-1:0] link_skewer_msg_1_2;
logic                       link_skewer_clk_1_2;
logic                       link_skewer_rst_1_2;
logic                       link_skewer_val_1_2;
logic                       link_skewer_cred_1_2;
logic                       link_skewer_crc_1_2;
logic                       link_skewer_repair_1_2;

// Credit Skewer -> Link Credit
logic [p_channel_width-1:0] skewer_link_msg_1_2;
logic                       skewer_link_clk_1_2;
logic                       skewer_link_rst_1_2;
logic                       skewer_link_val_1_2;
logic                       skewer_link_cred_1_2;
logic                       skewer_link_crc_1_2;
logic                       skewer_link_repair_1_2;

// Chip 2 -> Chip 1 ------------------------------------------------------------

// TB -> SPI Driver Val/Rdy
logic [p_input_width-1:0]   tb_driver_msg_2;
logic                       tb_driver_val_2;
logic                       tb_driver_rdy_2;

// SPI Driver -> TB Val/Rdy
logic [p_input_width-1:0]   driver_tb_msg_2;
logic                       driver_tb_val_2;
logic                       driver_tb_rdy_2;

// SPI Driver <-> Link SPI
logic sclk_2, mosi_2, miso_2, cs_2;

// Link -> Credit Skewer Credit
logic [p_channel_width-1:0] link_skewer_msg_2_1;
logic                       link_skewer_clk_2_1;
logic                       link_skewer_rst_2_1;
logic                       link_skewer_val_2_1;
logic                       link_skewer_cred_2_1;
logic                       link_skewer_crc_2_1;
logic                       link_skewer_repair_2_1;

// Credit Skewer -> Link Credit
logic [p_channel_width-1:0] skewer_link_msg_2_1;
logic                       skewer_link_clk_2_1;
logic                       skewer_link_rst_2_1;
logic                       skewer_link_val_2_1;
logic                       skewer_link_cred_2_1;
logic                       skewer_link_crc_2_1;
logic                       skewer_link_repair_2_1;

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
ManualCheckDualClkTB #(
  .p_chk_nbits (p_input_width),
  .p_timeout_period(100000000)
) tb (
  .src_clk(clk_1),
  .sink_clk(clk_2),
  .src_rst(rst_1),
  .sink_rst(rst_2),
  .*
);

//----------------------------------------------------------------------
// SPI drivers w/ Val/Rdy
//----------------------------------------------------------------------
SpiDriverValRdy #(
  .p_bit_width   (p_input_width),
  .p_sclk_period (p_sclk_period)
) driver_val_rdy_1 (
  .clk         (clk_1),
  .reset       (rst_1),
  .istream_val (tb_driver_val_1),
  .istream_rdy (tb_driver_rdy_1),
  .istream_msg (tb_driver_msg_1),
  .ostream_val (driver_tb_val_1),
  .ostream_rdy (driver_tb_rdy_1),
  .ostream_msg (driver_tb_msg_1),
  .sclk        (sclk_1),
  .mosi        (mosi_1),
  .miso        (miso_1),
  .cs          (cs_1),
  .*
);

SpiDriverValRdy #(
  .p_bit_width   (p_input_width),
  .p_sclk_period (p_sclk_period)
) driver_val_rdy_2 (
  .clk         (clk_2),
  .reset       (rst_2),
  .istream_val (tb_driver_val_2),
  .istream_rdy (tb_driver_rdy_2),
  .istream_msg (tb_driver_msg_2),
  .ostream_val (driver_tb_val_2),
  .ostream_rdy (driver_tb_rdy_2),
  .ostream_msg (driver_tb_msg_2),
  .sclk        (sclk_2),
  .mosi        (mosi_2),
  .miso        (miso_2),
  .cs          (cs_2),
  .*
);

//----------------------------------------------------------------------
// DUT instances
//----------------------------------------------------------------------
`ifdef FFGL_BA
  logic clk_1_debug, clk_2_debug;

  BRGTC6 link_1 (
    .clk_pad              (clk_1),
    .clk_debug_pad        (clk_1_debug),
    .reset_pad            (rst_1),
    .sclk_pad             (sclk_1),
    .mosi_pad             (mosi_1),
    .miso_pad             (miso_1),
    .cs_pad               (cs_1),
    .up_cred_msg_pad      (link_skewer_msg_1_2),
    .up_cred_val_pad      (link_skewer_val_1_2),
    .up_cred_clk_pad      (link_skewer_clk_1_2),
    .up_cred_rst_pad      (link_skewer_rst_1_2),
    .up_cred_cred_pad     (link_skewer_cred_1_2),
    .up_cred_crc_pad      (link_skewer_crc_1_2),
    .up_cred_repair_pad   (link_skewer_repair_1_2),
    .down_cred_msg_pad    (skewer_link_msg_2_1),
    .down_cred_val_pad    (skewer_link_val_2_1),
    .down_cred_clk_pad    (skewer_link_clk_2_1),
    .down_cred_rst_pad    (skewer_link_rst_2_1),
    .down_cred_cred_pad   (skewer_link_cred_2_1),
    .down_cred_crc_pad    (skewer_link_crc_2_1),
    .down_cred_repair_pad (skewer_link_repair_2_1)
  );

  BRGTC6 link_2 (
    .clk_pad              (clk_2),
    .clk_debug_pad        (clk_2_debug),
    .reset_pad            (rst_2),
    .sclk_pad             (sclk_2),
    .mosi_pad             (mosi_2),
    .miso_pad             (miso_2),
    .cs_pad               (cs_2),
    .up_cred_msg_pad      (link_skewer_msg_2_1),
    .up_cred_val_pad      (link_skewer_val_2_1),
    .up_cred_clk_pad      (link_skewer_clk_2_1),
    .up_cred_rst_pad      (link_skewer_rst_2_1),
    .up_cred_cred_pad     (link_skewer_cred_2_1),
    .up_cred_crc_pad      (link_skewer_crc_2_1),
    .up_cred_repair_pad   (link_skewer_repair_2_1),
    .down_cred_msg_pad    (skewer_link_msg_1_2),
    .down_cred_val_pad    (skewer_link_val_1_2),
    .down_cred_clk_pad    (skewer_link_clk_1_2),
    .down_cred_rst_pad    (skewer_link_rst_1_2),
    .down_cred_cred_pad   (skewer_link_cred_1_2),
    .down_cred_crc_pad    (skewer_link_crc_1_2),
    .down_cred_repair_pad (skewer_link_repair_1_2)
  );
`else
  Link #(
    .p_channel_width     (p_channel_width),
    .p_config_width      (p_config_width),
    .p_max_credit        (p_max_credit),
    .p_clk_width         (p_clk_width),
    .p_addr_width        (p_addr_width),
    .p_resp_buffer_depth (p_resp_buffer_depth),
    .p_input_width       (p_input_width)
  ) link_1 (
    .clk                 (clk_1),
    .reset               (rst_1),
    .up_cred_msg         (link_skewer_msg_1_2),
    .up_cred_val         (link_skewer_val_1_2),
    .up_cred_clk         (link_skewer_clk_1_2),
    .up_cred_rst         (link_skewer_rst_1_2),
    .up_cred_cred        (link_skewer_cred_1_2),
    .up_cred_crc         (link_skewer_crc_1_2),
    .up_cred_repair      (link_skewer_repair_1_2),
    .down_cred_msg       (skewer_link_msg_2_1),
    .down_cred_val       (skewer_link_val_2_1),
    .down_cred_clk       (skewer_link_clk_2_1),
    .down_cred_rst       (skewer_link_rst_2_1),
    .down_cred_cred      (skewer_link_cred_2_1),
    .down_cred_crc       (skewer_link_crc_2_1),
    .down_cred_repair    (skewer_link_repair_2_1),
    .sclk                (sclk_1),
    .mosi                (mosi_1),
    .miso                (miso_1),
    .cs                  (cs_1),
    .*
  );

  Link #(
    .p_channel_width     (p_channel_width),
    .p_config_width      (p_config_width),
    .p_max_credit        (p_max_credit),
    .p_clk_width         (p_clk_width),
    .p_addr_width        (p_addr_width),
    .p_resp_buffer_depth (p_resp_buffer_depth),
    .p_input_width       (p_input_width)
  ) link_2 (
    .clk                 (clk_2),
    .reset               (rst_2),
    .up_cred_msg         (link_skewer_msg_2_1),
    .up_cred_val         (link_skewer_val_2_1),
    .up_cred_clk         (link_skewer_clk_2_1),
    .up_cred_rst         (link_skewer_rst_2_1),
    .up_cred_cred        (link_skewer_cred_2_1),
    .up_cred_crc         (link_skewer_crc_2_1),
    .up_cred_repair      (link_skewer_repair_2_1),
    .down_cred_msg       (skewer_link_msg_1_2),
    .down_cred_val       (skewer_link_val_1_2),
    .down_cred_clk       (skewer_link_clk_1_2),
    .down_cred_rst       (skewer_link_rst_1_2),
    .down_cred_cred      (skewer_link_cred_1_2),
    .down_cred_crc       (skewer_link_crc_1_2),
    .down_cred_repair    (skewer_link_repair_1_2),
    .sclk                (sclk_2),
    .mosi                (mosi_2),
    .miso                (miso_2),
    .cs                  (cs_2),
    .*
  );
`endif

//----------------------------------------------------------------------
// Credit interface skewers
//----------------------------------------------------------------------
logic [31:0] msg_skews_1_2[p_channel_width];
logic [31:0] val_skew_1_2, clk_skew_1_2, rst_skew_1_2, cred_skew_1_2, crc_skew_1_2, repair_skew_1_2;
logic [p_channel_width+4:0] error_en_1_2;

CredSkewerErrorerV4 #(
  .p_msg_nbits (p_channel_width),
  .p_max_skew  (1100)
) cred_skewer_1_2 (
  .en(1'b1),
  .up_cred_msg    (link_skewer_msg_1_2),
  .up_cred_val    (link_skewer_val_1_2),
  .up_cred_clk    (link_skewer_clk_1_2),
  .up_cred_rst    (link_skewer_rst_1_2),
  .up_cred_cred   (link_skewer_cred_1_2),
  .up_cred_crc    (link_skewer_crc_1_2),
  .up_cred_repair (link_skewer_repair_1_2),
  .down_cred_msg  (skewer_link_msg_1_2),
  .down_cred_val  (skewer_link_val_1_2),
  .down_cred_clk  (skewer_link_clk_1_2),
  .down_cred_rst  (skewer_link_rst_1_2),
  .down_cred_cred (skewer_link_cred_1_2),
  .down_cred_crc  (skewer_link_crc_1_2),
  .down_cred_repair (skewer_link_repair_1_2),
  .msg_skews      (msg_skews_1_2),
  .val_skew       (val_skew_1_2),
  .clk_skew       (clk_skew_1_2),
  .rst_skew       (rst_skew_1_2),
  .cred_skew      (cred_skew_1_2),
  .crc_skew       (crc_skew_1_2),
  .repair_skew    (repair_skew_1_2),
  .error_en       (error_en_1_2),
  .*
);

logic [31:0] msg_skews_2_1[p_channel_width];
logic [31:0] val_skew_2_1, clk_skew_2_1, rst_skew_2_1, cred_skew_2_1, crc_skew_2_1, repair_skew_2_1;
logic [p_channel_width+4:0] error_en_2_1;

CredSkewerErrorerV4 #(
  .p_msg_nbits (p_channel_width),
  .p_max_skew  (1100)
) cred_skewer_2_1 (
  .en(1'b1),
  .up_cred_msg    (link_skewer_msg_2_1),
  .up_cred_val    (link_skewer_val_2_1),
  .up_cred_clk    (link_skewer_clk_2_1),
  .up_cred_rst    (link_skewer_rst_2_1),
  .up_cred_cred   (link_skewer_cred_2_1),
  .up_cred_crc    (link_skewer_crc_2_1),
  .up_cred_repair (link_skewer_repair_2_1),
  .down_cred_msg  (skewer_link_msg_2_1),
  .down_cred_val  (skewer_link_val_2_1),
  .down_cred_clk  (skewer_link_clk_2_1),
  .down_cred_rst  (skewer_link_rst_2_1),
  .down_cred_cred (skewer_link_cred_2_1),
  .down_cred_crc  (skewer_link_crc_2_1),
  .down_cred_repair (skewer_link_repair_2_1),
  .msg_skews      (msg_skews_2_1),
  .val_skew       (val_skew_2_1),
  .clk_skew       (clk_skew_2_1),
  .rst_skew       (rst_skew_2_1),
  .cred_skew      (cred_skew_2_1),
  .crc_skew       (crc_skew_2_1),
  .repair_skew    (repair_skew_2_1),
  .error_en       (error_en_2_1),
  .*
);

//----------------------------------------------------------------------
// test_send_all_wait_receive_all_one_way
//----------------------------------------------------------------------
task automatic test_send_all_wait_receive_all_one_way (
  string  name,
  integer clk_pd_1       = -1,
  integer clk_pd_2       = -1,
  integer clk_div_mult_1 = -1,
  integer clk_div_mult_2 = -1,
  integer rst_delay_1    = -1,
  integer rst_delay_2    = -1,
  integer inj_skew_1_2   = -1,
  integer inj_skew_2_1   = -1,
  integer skew_set_1     = -1, // must be < 2**clk_div_mult,
  integer skew_set_2     = -1, // must be < 2**clk_div_mult,
  integer num_msgs       = -1,
  bit     eq_rand        = 0, // 1 = equalize random freqs
  bit     inj_skew_mode  = 0, // 0 = random, 1 = alternate between 0 and max
  integer seed           = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);
  integer max_clk_pd, max_clk_div_mult;
  integer message;
  integer src_sink_idx_1 = 0;
  integer src_sink_idx_2 = 0;
  bit     skew_zero;
  logic [p_input_width-1:0] src_msgs[];
  logic [p_input_width-1:0] config_msgs_1[];
  logic [p_input_width-1:0] config_msgs_2[];
  src_msgs = new[num_msgs];
  config_msgs_1 = new[4];
  config_msgs_2 = new[4];

  if (clk_pd_1       == -1) clk_pd_1       = p_min_clk_pd + ($urandom() % (p_max_clk_pd - 1)); // always produce even value
  if (clk_pd_2       == -1) clk_pd_2       = eq_rand ? clk_pd_1 : (p_min_clk_pd + ($urandom() % (p_max_clk_pd - 1))); // always produce even value
  if (clk_div_mult_1 == -1) clk_div_mult_1 = $urandom() % (p_max_clk_div_mult + 1);
  if (clk_div_mult_2 == -1) clk_div_mult_2 = eq_rand ? clk_div_mult_1 : ($urandom() % (p_max_clk_div_mult + 1));
  if (rst_delay_1    == -1) rst_delay_1    = 2*clk_pd_1 + ($urandom() % (p_max_rst_delay - 2*clk_pd_1 + 1)); // guarantee at least 2 clk cycles of delay
  if (rst_delay_2    == -1) rst_delay_2    = 2*clk_pd_2 + ($urandom() % (p_max_rst_delay - 2*clk_pd_2 + 1)); // guarantee at least 2 clk cycles of delay
  if (skew_set_1     == -1) skew_set_1     = 0;
  if (skew_set_2     == -1) skew_set_2     = 0;
  if (num_msgs       == -1) num_msgs       = 1 + $urandom() % (p_max_msgs);
  error_en_1_2 = (p_channel_width+5)'(0);
  error_en_2_1 = (p_channel_width+5)'(0);

  max_clk_pd = clk_pd_1 > clk_pd_2 ? clk_pd_1 : clk_pd_2;
  max_clk_div_mult = clk_div_mult_1 > clk_div_mult_2 ? clk_div_mult_1 : clk_div_mult_2;

  // Initialize skews (inj_skew != -1 means it is the upper limit for possible skews)
  skew_zero = 1'b1;
  for (int i = 0; i < p_channel_width; i++) begin
    msg_skews_1_2[i] = inj_skew_mode ? (skew_zero ? 0 : inj_skew_1_2) : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1)); // can tolerate < half clk cycle of skew without deskewing
    msg_skews_2_1[i] = inj_skew_mode ? (skew_zero ? 0 : inj_skew_2_1) : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1)); // can tolerate < half clk cycle of skew without deskewing
    skew_zero = ~skew_zero;
  end
  val_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  val_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  clk_skew_1_2    = 0;
  clk_skew_2_1    = 0;
  rst_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  rst_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  cred_skew_1_2   = inj_skew_mode ? 0 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  cred_skew_2_1   = inj_skew_mode ? 0 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  crc_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  crc_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  repair_skew_1_2 = inj_skew_mode ? 0 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  repair_skew_2_1 = inj_skew_mode ? 0 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));

  tb_driver_val_1 = 1'b0;
  tb_driver_msg_1 = {p_input_width{1'b0}};
  tb_driver_val_2 = 1'b0;
  tb_driver_msg_2 = {p_input_width{1'b0}};
  driver_tb_rdy_1 = 1'b0;
  driver_tb_rdy_2 = 1'b0;

  tb.test_case_begin(
    name,
    clk_pd_1,
    clk_pd_2,
    rst_delay_1,
    rst_delay_2,
    1,
    1,
    seed
  );

  // Configure links
  config_msgs_1[0] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_FACTOR, p_config_width'(2**clk_div_mult_1)};
  config_msgs_2[0] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_FACTOR, p_config_width'(2**clk_div_mult_2)};
  config_msgs_1[1] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_SKEW, p_config_width'(skew_set_1)};
  config_msgs_2[1] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_SKEW, p_config_width'(skew_set_2)};
  config_msgs_1[2] = {logic'(`CNFG_MSG), `CFG_ADDR_PAT_BYPASS, p_config_width'(1)};
  config_msgs_2[2] = {logic'(`CNFG_MSG), `CFG_ADDR_PAT_BYPASS, p_config_width'(1)};
  config_msgs_1[3] = {logic'(`CNFG_MSG), `CFG_ADDR_GO, p_config_width'(1)};
  config_msgs_2[3] = {logic'(`CNFG_MSG), `CFG_ADDR_GO, p_config_width'(1)};
  
  fork
    for (int i = 0; i < 4; i++) begin
      while(!tb_driver_rdy_1) #1;
      tb_driver_msg_1 = config_msgs_1[i];
      tb_driver_val_1 = 1'b1;
      @(posedge clk_1);
      @(negedge clk_1);
      tb_driver_val_1 = 1'b0;

      while (!driver_tb_val_1) #1;
      driver_tb_rdy_1 = 1'b1;
      tb.test_case_check(config_msgs_1[i], driver_tb_msg_1, $sformatf("config_msg_1[%0d]", i));
      @(posedge clk_1);
      @(negedge clk_1);
      driver_tb_rdy_1 = 1'b0;
    end
    for (int i = 0; i < 4; i++) begin
      while(!tb_driver_rdy_2) #1;
      tb_driver_msg_2 = config_msgs_2[i];
      tb_driver_val_2 = 1'b1;
      @(posedge clk_2);
      @(negedge clk_2);
      tb_driver_val_2 = 1'b0;

      while (!driver_tb_val_2) #1;
      driver_tb_rdy_2 = 1'b1;
      tb.test_case_check(config_msgs_2[i], driver_tb_msg_2, $sformatf("config_msg_2[%0d]", i));
      @(posedge clk_2);
      @(negedge clk_2);
      driver_tb_rdy_2 = 1'b0;
    end
  join

  // Initialize messages to send and receive
  for (int i = 0; i < num_msgs; i++)
    src_msgs[i] = {logic'(`CHNL_MSG), p_config_width'($urandom() % (2**p_channel_width))};

  // Send all on chip 1
  for (int i = 0; i < num_msgs; i++) begin
    while(!tb_driver_rdy_1) #1;
    tb_driver_msg_1 = src_msgs[i];
    tb_driver_val_1 = 1'b1;
    @(posedge clk_1);
    @(negedge clk_1);
    tb_driver_val_1 = 1'b0;
    #(max_clk_pd*(2**max_clk_div_mult)*10000);
  end

  #(max_clk_pd*(2**max_clk_div_mult)*1000000);

  // Receive all on chip 2
  for (int i = 0; i < num_msgs; i++) begin
    while (!driver_tb_val_2) #1;
    driver_tb_rdy_2 = 1'b1;
    tb.test_case_check(src_msgs[i], driver_tb_msg_2, $sformatf("recvd msg %0d", i));
    @(posedge clk_2);
    @(negedge clk_2);
    driver_tb_rdy_2 = 1'b0;
    #(max_clk_pd*(2**max_clk_div_mult)*10000);
  end

endtask

//----------------------------------------------------------------------
// test_send_all_wait_receive_all_two_way
//----------------------------------------------------------------------
task automatic test_send_all_wait_receive_all_two_way (
  string  name,
  integer clk_pd_1       = -1,
  integer clk_pd_2       = -1,
  integer clk_div_mult_1 = -1,
  integer clk_div_mult_2 = -1,
  integer rst_delay_1    = -1,
  integer rst_delay_2    = -1,
  integer inj_skew_1_2   = -1,
  integer inj_skew_2_1   = -1,
  integer skew_set_1     = -1, // must be < 2**clk_div_mult,
  integer skew_set_2     = -1, // must be < 2**clk_div_mult,
  integer num_msgs       = -1,
  bit     eq_rand        = 0, // 1 = equalize random freqs
  bit     inj_skew_mode  = 0, // 0 = random, 1 = alternate between 0 and max
  integer seed           = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);
  integer max_clk_pd, max_clk_div_mult;
  integer message;
  integer src_sink_idx_1 = 0;
  integer src_sink_idx_2 = 0;
  bit     skew_zero;
  logic [p_input_width-1:0] src_msgs_1_2[];
  logic [p_input_width-1:0] src_msgs_2_1[];
  logic [p_input_width-1:0] config_msgs_1[];
  logic [p_input_width-1:0] config_msgs_2[];
  src_msgs_1_2 = new[num_msgs];
  src_msgs_2_1 = new[num_msgs];
  config_msgs_1 = new[4];
  config_msgs_2 = new[4];

  if (clk_pd_1       == -1) clk_pd_1       = p_min_clk_pd + ($urandom() % (p_max_clk_pd - 1)); // always produce even value
  if (clk_pd_2       == -1) clk_pd_2       = eq_rand ? clk_pd_1 : (p_min_clk_pd + ($urandom() % (p_max_clk_pd - 1))); // always produce even value
  if (clk_div_mult_1 == -1) clk_div_mult_1 = $urandom() % (p_max_clk_div_mult + 1);
  if (clk_div_mult_2 == -1) clk_div_mult_2 = eq_rand ? clk_div_mult_1 : ($urandom() % (p_max_clk_div_mult + 1));
  if (rst_delay_1    == -1) rst_delay_1    = 2*clk_pd_1 + ($urandom() % (p_max_rst_delay - 2*clk_pd_1 + 1)); // guarantee at least 2 clk cycles of delay
  if (rst_delay_2    == -1) rst_delay_2    = 2*clk_pd_2 + ($urandom() % (p_max_rst_delay - 2*clk_pd_2 + 1)); // guarantee at least 2 clk cycles of delay
  if (skew_set_1     == -1) skew_set_1     = 0;
  if (skew_set_2     == -1) skew_set_2     = 0;
  if (num_msgs       == -1) num_msgs       = 1 + $urandom() % (p_max_msgs);
  error_en_1_2 = (p_channel_width+5)'(0);
  error_en_2_1 = (p_channel_width+5)'(0);

  max_clk_pd = clk_pd_1 > clk_pd_2 ? clk_pd_1 : clk_pd_2;
  max_clk_div_mult = clk_div_mult_1 > clk_div_mult_2 ? clk_div_mult_1 : clk_div_mult_2;

  // Initialize skews (inj_skew != -1 means it is the upper limit for possible skews)
  skew_zero = 1'b1;
  for (int i = 0; i < p_channel_width; i++) begin
    msg_skews_1_2[i] = inj_skew_mode ? (skew_zero ? 0 : inj_skew_1_2) : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1)); // can tolerate < half clk cycle of skew without deskewing
    msg_skews_2_1[i] = inj_skew_mode ? (skew_zero ? 0 : inj_skew_2_1) : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1)); // can tolerate < half clk cycle of skew without deskewing
    skew_zero = ~skew_zero;
  end
  val_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  val_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  clk_skew_1_2    = 0;
  clk_skew_2_1    = 0;
  rst_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  rst_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  cred_skew_1_2   = inj_skew_mode ? 0 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  cred_skew_2_1   = inj_skew_mode ? 0 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  crc_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  crc_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  repair_skew_1_2 = inj_skew_mode ? 0 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  repair_skew_2_1 = inj_skew_mode ? 0 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));

  tb_driver_val_1 = 1'b0;
  tb_driver_msg_1 = {p_input_width{1'b0}};
  tb_driver_val_2 = 1'b0;
  tb_driver_msg_2 = {p_input_width{1'b0}};
  driver_tb_rdy_1 = 1'b0;
  driver_tb_rdy_2 = 1'b0;

  tb.test_case_begin(
    name,
    clk_pd_1,
    clk_pd_2,
    rst_delay_1,
    rst_delay_2,
    1,
    1,
    seed
  );

  // Configure links
  config_msgs_1[0] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_FACTOR, p_config_width'(2**clk_div_mult_1)};
  config_msgs_2[0] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_FACTOR, p_config_width'(2**clk_div_mult_2)};
  config_msgs_1[1] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_SKEW, p_config_width'(skew_set_1)};
  config_msgs_2[1] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_SKEW, p_config_width'(skew_set_2)};
  config_msgs_1[2] = {logic'(`CNFG_MSG), `CFG_ADDR_PAT_BYPASS, p_config_width'(1)};
  config_msgs_2[2] = {logic'(`CNFG_MSG), `CFG_ADDR_PAT_BYPASS, p_config_width'(1)};
  config_msgs_1[3] = {logic'(`CNFG_MSG), `CFG_ADDR_GO, p_config_width'(1)};
  config_msgs_2[3] = {logic'(`CNFG_MSG), `CFG_ADDR_GO, p_config_width'(1)};
  
  fork
    for (int i = 0; i < 4; i++) begin
      while(!tb_driver_rdy_1) #1;
      tb_driver_msg_1 = config_msgs_1[i];
      tb_driver_val_1 = 1'b1;
      @(posedge clk_1);
      @(negedge clk_1);
      tb_driver_val_1 = 1'b0;

      while (!driver_tb_val_1) #1;
      driver_tb_rdy_1 = 1'b1;
      tb.test_case_check(config_msgs_1[i], driver_tb_msg_1, $sformatf("config_msg_1[%0d]", i));
      @(posedge clk_1);
      @(negedge clk_1);
      driver_tb_rdy_1 = 1'b0;
    end
    for (int i = 0; i < 4; i++) begin
      while(!tb_driver_rdy_2) #1;
      tb_driver_msg_2 = config_msgs_2[i];
      tb_driver_val_2 = 1'b1;
      @(posedge clk_2);
      @(negedge clk_2);
      tb_driver_val_2 = 1'b0;

      while (!driver_tb_val_2) #1;
      driver_tb_rdy_2 = 1'b1;
      tb.test_case_check(config_msgs_2[i], driver_tb_msg_2, $sformatf("config_msg_2[%0d]", i));
      @(posedge clk_2);
      @(negedge clk_2);
      driver_tb_rdy_2 = 1'b0;
    end
  join

  // Initialize messages to send and receive
  for (int i = 0; i < num_msgs; i++) begin
    src_msgs_1_2[i] = {logic'(`CHNL_MSG), p_config_width'($urandom() % (2**p_channel_width))};
    src_msgs_2_1[i] = {logic'(`CHNL_MSG), p_config_width'($urandom() % (2**p_channel_width))};
  end

  fork
    begin

      // Send all on chip 1
      for (int i = 0; i < num_msgs; i++) begin
        while(!tb_driver_rdy_1) #1;
        tb_driver_msg_1 = src_msgs_1_2[i];
        tb_driver_val_1 = 1'b1;
        @(posedge clk_1);
        @(negedge clk_1);
        tb_driver_val_1 = 1'b0;
        #(max_clk_pd*(2**max_clk_div_mult)*10000);
      end

      #(max_clk_pd*(2**max_clk_div_mult)*1000000);

      // Receive all on chip 2
      for (int i = 0; i < num_msgs; i++) begin
        while (!driver_tb_val_2) #1;
        driver_tb_rdy_2 = 1'b1;
        tb.test_case_check(src_msgs_1_2[i], driver_tb_msg_2, $sformatf("recvd msg %0d on 2", i));
        @(posedge clk_2);
        @(negedge clk_2);
        driver_tb_rdy_2 = 1'b0;
        #(max_clk_pd*(2**max_clk_div_mult)*10000);
      end

    end
    begin

      // Send all on chip 2
      for (int i = 0; i < num_msgs; i++) begin
        while(!tb_driver_rdy_2) #1;
        tb_driver_msg_2 = src_msgs_2_1[i];
        tb_driver_val_2 = 1'b1;
        @(posedge clk_2);
        @(negedge clk_2);
        tb_driver_val_2 = 1'b0;
        #(max_clk_pd*(2**max_clk_div_mult)*10000);
      end

      #(max_clk_pd*(2**max_clk_div_mult)*100000);

      // Receive all on chip 1
      for (int i = 0; i < num_msgs; i++) begin
        while (!driver_tb_val_1) #1;
        driver_tb_rdy_1 = 1'b1;
        tb.test_case_check(src_msgs_2_1[i], driver_tb_msg_1, $sformatf("recvd msg %0d on 1", i));
        @(posedge clk_1);
        @(negedge clk_1);
        driver_tb_rdy_1 = 1'b0;
        #(max_clk_pd*(2**max_clk_div_mult)*10000);
      end

    end
  join

endtask

//----------------------------------------------------------------------
// test_interlaced_one_way
//----------------------------------------------------------------------
task automatic test_interlaced_one_way (
  string  name,
  integer clk_pd_1       = -1,
  integer clk_pd_2       = -1,
  integer clk_div_mult_1 = -1,
  integer clk_div_mult_2 = -1,
  integer rst_delay_1    = -1,
  integer rst_delay_2    = -1,
  integer inj_skew_1_2   = -1,
  integer inj_skew_2_1   = -1,
  integer skew_set_1     = -1, // must be < 2**clk_div_mult,
  integer skew_set_2     = -1, // must be < 2**clk_div_mult,
  integer num_msgs       = -1,
  integer num_segs       = -1,
  bit     eq_rand        = 0, // 1 = equalize random freqs
  bit     inj_skew_mode  = 0, // 0 = random, 1 = alternate between 0 and max
  integer seed           = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);
  integer max_clk_pd, max_clk_div_mult;
  integer message;
  integer src_sink_idx_1 = 0;
  integer src_sink_idx_2 = 0;
  bit     skew_zero;
  logic [p_input_width-1:0] src_msgs[];
  logic [p_input_width-1:0] config_msgs_1[];
  logic [p_input_width-1:0] config_msgs_2[];
  src_msgs = new[num_msgs];
  config_msgs_1 = new[4];
  config_msgs_2 = new[4];

  if (clk_pd_1       == -1) clk_pd_1       = p_min_clk_pd + ($urandom() % (p_max_clk_pd - 1)); // always produce even value
  if (clk_pd_2       == -1) clk_pd_2       = eq_rand ? clk_pd_1 : (p_min_clk_pd + ($urandom() % (p_max_clk_pd - 1))); // always produce even value
  if (clk_div_mult_1 == -1) clk_div_mult_1 = $urandom() % (p_max_clk_div_mult + 1);
  if (clk_div_mult_2 == -1) clk_div_mult_2 = eq_rand ? clk_div_mult_1 : ($urandom() % (p_max_clk_div_mult + 1));
  if (rst_delay_1    == -1) rst_delay_1    = 2*clk_pd_1 + ($urandom() % (p_max_rst_delay - 2*clk_pd_1 + 1)); // guarantee at least 2 clk cycles of delay
  if (rst_delay_2    == -1) rst_delay_2    = 2*clk_pd_2 + ($urandom() % (p_max_rst_delay - 2*clk_pd_2 + 1)); // guarantee at least 2 clk cycles of delay
  if (skew_set_1     == -1) skew_set_1     = 0;
  if (skew_set_2     == -1) skew_set_2     = 0;
  if (num_msgs       == -1) num_msgs       = 1 + $urandom() % (p_max_msgs);
  if (num_segs       == -1) num_segs       = 1 + $urandom() % (p_max_segs);
  error_en_1_2 = (p_channel_width+5)'(0);
  error_en_2_1 = (p_channel_width+5)'(0);

  max_clk_pd = clk_pd_1 > clk_pd_2 ? clk_pd_1 : clk_pd_2;
  max_clk_div_mult = clk_div_mult_1 > clk_div_mult_2 ? clk_div_mult_1 : clk_div_mult_2;

  // Initialize skews (inj_skew != -1 means it is the upper limit for possible skews)
  skew_zero = 1'b1;
  for (int i = 0; i < p_channel_width; i++) begin
    msg_skews_1_2[i] = inj_skew_mode ? (skew_zero ? 0 : inj_skew_1_2) : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1)); // can tolerate < half clk cycle of skew without deskewing
    msg_skews_2_1[i] = inj_skew_mode ? (skew_zero ? 0 : inj_skew_2_1) : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1)); // can tolerate < half clk cycle of skew without deskewing
    skew_zero = ~skew_zero;
  end
  val_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  val_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  clk_skew_1_2    = 0;
  clk_skew_2_1    = 0;
  rst_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  rst_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  cred_skew_1_2   = inj_skew_mode ? 0 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  cred_skew_2_1   = inj_skew_mode ? 0 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  crc_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  crc_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  repair_skew_1_2 = inj_skew_mode ? 0 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  repair_skew_2_1 = inj_skew_mode ? 0 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));

  tb_driver_val_1 = 1'b0;
  tb_driver_msg_1 = {p_input_width{1'b0}};
  tb_driver_val_2 = 1'b0;
  tb_driver_msg_2 = {p_input_width{1'b0}};
  driver_tb_rdy_1 = 1'b0;
  driver_tb_rdy_2 = 1'b0;

  tb.test_case_begin(
    name,
    clk_pd_1,
    clk_pd_2,
    rst_delay_1,
    rst_delay_2,
    1,
    1,
    seed
  );

  // Configure links
  config_msgs_1[0] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_FACTOR, p_config_width'(2**clk_div_mult_1)};
  config_msgs_2[0] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_FACTOR, p_config_width'(2**clk_div_mult_2)};
  config_msgs_1[1] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_SKEW, p_config_width'(skew_set_1)};
  config_msgs_2[1] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_SKEW, p_config_width'(skew_set_2)};
  config_msgs_1[2] = {logic'(`CNFG_MSG), `CFG_ADDR_PAT_BYPASS, p_config_width'(1)};
  config_msgs_2[2] = {logic'(`CNFG_MSG), `CFG_ADDR_PAT_BYPASS, p_config_width'(1)};
  config_msgs_1[3] = {logic'(`CNFG_MSG), `CFG_ADDR_GO, p_config_width'(1)};
  config_msgs_2[3] = {logic'(`CNFG_MSG), `CFG_ADDR_GO, p_config_width'(1)};
  
  fork
    for (int i = 0; i < 4; i++) begin
      while(!tb_driver_rdy_1) #1;
      tb_driver_msg_1 = config_msgs_1[i];
      tb_driver_val_1 = 1'b1;
      @(posedge clk_1);
      @(negedge clk_1);
      tb_driver_val_1 = 1'b0;

      while (!driver_tb_val_1) #1;
      driver_tb_rdy_1 = 1'b1;
      tb.test_case_check(config_msgs_1[i], driver_tb_msg_1, $sformatf("config_msg_1[%0d]", i));
      @(posedge clk_1);
      @(negedge clk_1);
      driver_tb_rdy_1 = 1'b0;
    end
    for (int i = 0; i < 4; i++) begin
      while(!tb_driver_rdy_2) #1;
      tb_driver_msg_2 = config_msgs_2[i];
      tb_driver_val_2 = 1'b1;
      @(posedge clk_2);
      @(negedge clk_2);
      tb_driver_val_2 = 1'b0;

      while (!driver_tb_val_2) #1;
      driver_tb_rdy_2 = 1'b1;
      tb.test_case_check(config_msgs_2[i], driver_tb_msg_2, $sformatf("config_msg_2[%0d]", i));
      @(posedge clk_2);
      @(negedge clk_2);
      driver_tb_rdy_2 = 1'b0;
    end
  join

  // Initialize messages to send and receive
  for (int i = 0; i < num_msgs; i++)
    src_msgs[i] = {logic'(`CHNL_MSG), p_config_width'($urandom() % (2**p_channel_width))};

  // Send and receive messages at offset times in segments
  fork
    for(int s = 0; s < num_segs; s++) begin
      for (int i = 0; i < num_msgs; i++) begin 
        while(!tb_driver_rdy_1) #1;
        tb_driver_msg_1 = src_msgs[i];
        tb_driver_val_1 = 1'b1;
        @(posedge clk_1);
        @(negedge clk_1);
        tb_driver_val_1 = 1'b0;
        #(max_clk_pd*(2**max_clk_div_mult)*10000);
      end
      if (s != num_segs-1) #(max_clk_pd*(2**max_clk_div_mult)*1000000);
    end
    for(int s = 0; s < num_segs; s++) begin
      #(max_clk_pd*(2**max_clk_div_mult)*1000000);
      for (int i = 0; i < num_msgs; i++) begin
        while (!driver_tb_val_2) #1;
        driver_tb_rdy_2 = 1'b1;
        tb.test_case_check(src_msgs[i], driver_tb_msg_2, $sformatf("recvd msg %0d for seg %0d", i, s));
        @(posedge clk_2);
        @(negedge clk_2);
        driver_tb_rdy_2 = 1'b0;
        #(max_clk_pd*(2**max_clk_div_mult)*10000);
      end
    end
  join

endtask

//----------------------------------------------------------------------
// test_interlaced_two_way
//----------------------------------------------------------------------
task automatic test_interlaced_two_way (
  string  name,
  integer clk_pd_1       = -1,
  integer clk_pd_2       = -1,
  integer clk_div_mult_1 = -1,
  integer clk_div_mult_2 = -1,
  integer rst_delay_1    = -1,
  integer rst_delay_2    = -1,
  integer inj_skew_1_2   = -1,
  integer inj_skew_2_1   = -1,
  integer skew_set_1     = -1, // must be < 2**clk_div_mult,
  integer skew_set_2     = -1, // must be < 2**clk_div_mult,
  integer num_msgs       = -1,
  integer num_segs       = -1,
  bit     eq_rand        = 0, // 1 = equalize random freqs
  bit     inj_skew_mode  = 0, // 0 = random, 1 = alternate between 0 and max
  integer seed           = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);
  integer max_clk_pd, max_clk_div_mult;
  integer message;
  integer src_sink_idx_1 = 0;
  integer src_sink_idx_2 = 0;
  bit     skew_zero;
  logic [p_input_width-1:0] src_msgs_1_2[];
  logic [p_input_width-1:0] src_msgs_2_1[];
  logic [p_input_width-1:0] config_msgs_1[];
  logic [p_input_width-1:0] config_msgs_2[];
  src_msgs_1_2 = new[num_msgs];
  src_msgs_2_1 = new[num_msgs];
  config_msgs_1 = new[4];
  config_msgs_2 = new[4];

  if (clk_pd_1       == -1) clk_pd_1       = p_min_clk_pd + ($urandom() % (p_max_clk_pd - 1)); // always produce even value
  if (clk_pd_2       == -1) clk_pd_2       = eq_rand ? clk_pd_1 : (p_min_clk_pd + ($urandom() % (p_max_clk_pd - 1))); // always produce even value
  if (clk_div_mult_1 == -1) clk_div_mult_1 = $urandom() % (p_max_clk_div_mult + 1);
  if (clk_div_mult_2 == -1) clk_div_mult_2 = eq_rand ? clk_div_mult_1 : ($urandom() % (p_max_clk_div_mult + 1));
  if (rst_delay_1    == -1) rst_delay_1    = 2*clk_pd_1 + ($urandom() % (p_max_rst_delay - 2*clk_pd_1 + 1)); // guarantee at least 2 clk cycles of delay
  if (rst_delay_2    == -1) rst_delay_2    = 2*clk_pd_2 + ($urandom() % (p_max_rst_delay - 2*clk_pd_2 + 1)); // guarantee at least 2 clk cycles of delay
  if (skew_set_1     == -1) skew_set_1     = 0;
  if (skew_set_2     == -1) skew_set_2     = 0;
  if (num_msgs       == -1) num_msgs       = 1 + $urandom() % (p_max_msgs);
  if (num_segs       == -1) num_segs       = 1 + $urandom() % (p_max_segs);
  error_en_1_2 = (p_channel_width+5)'(0);
  error_en_2_1 = (p_channel_width+5)'(0);

  max_clk_pd = clk_pd_1 > clk_pd_2 ? clk_pd_1 : clk_pd_2;
  max_clk_div_mult = clk_div_mult_1 > clk_div_mult_2 ? clk_div_mult_1 : clk_div_mult_2;

  // Initialize skews (inj_skew != -1 means it is the upper limit for possible skews)
  skew_zero = 1'b1;
  for (int i = 0; i < p_channel_width; i++) begin
    msg_skews_1_2[i] = inj_skew_mode ? (skew_zero ? 0 : inj_skew_1_2) : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1)); // can tolerate < half clk cycle of skew without deskewing
    msg_skews_2_1[i] = inj_skew_mode ? (skew_zero ? 0 : inj_skew_2_1) : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1)); // can tolerate < half clk cycle of skew without deskewing
    skew_zero = ~skew_zero;
  end
  val_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  val_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  clk_skew_1_2    = 0;
  clk_skew_2_1    = 0;
  rst_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  rst_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  cred_skew_1_2   = inj_skew_mode ? 0 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  cred_skew_2_1   = inj_skew_mode ? 0 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  crc_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  crc_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  repair_skew_1_2 = inj_skew_mode ? 0 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  repair_skew_2_1 = inj_skew_mode ? 0 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));

  tb_driver_val_1 = 1'b0;
  tb_driver_msg_1 = {p_input_width{1'b0}};
  tb_driver_val_2 = 1'b0;
  tb_driver_msg_2 = {p_input_width{1'b0}};
  driver_tb_rdy_1 = 1'b0;
  driver_tb_rdy_2 = 1'b0;

  tb.test_case_begin(
    name,
    clk_pd_1,
    clk_pd_2,
    rst_delay_1,
    rst_delay_2,
    1,
    1,
    seed
  );

  // Configure links
  config_msgs_1[0] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_FACTOR, p_config_width'(2**clk_div_mult_1)};
  config_msgs_2[0] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_FACTOR, p_config_width'(2**clk_div_mult_2)};
  config_msgs_1[1] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_SKEW, p_config_width'(skew_set_1)};
  config_msgs_2[1] = {logic'(`CNFG_MSG), `CFG_ADDR_CLK_DIV_SKEW, p_config_width'(skew_set_2)};
  config_msgs_1[2] = {logic'(`CNFG_MSG), `CFG_ADDR_PAT_BYPASS, p_config_width'(1)};
  config_msgs_2[2] = {logic'(`CNFG_MSG), `CFG_ADDR_PAT_BYPASS, p_config_width'(1)};
  config_msgs_1[3] = {logic'(`CNFG_MSG), `CFG_ADDR_GO, p_config_width'(1)};
  config_msgs_2[3] = {logic'(`CNFG_MSG), `CFG_ADDR_GO, p_config_width'(1)};
  
  fork
    begin
    for (int i = 0; i < 4; i++) begin
      while(!tb_driver_rdy_1) #1;
      tb_driver_msg_1 = config_msgs_1[i];
      tb_driver_val_1 = 1'b1;
      @(posedge clk_1);
      @(negedge clk_1);
      tb_driver_val_1 = 1'b0;

      while (!driver_tb_val_1) #1;
      driver_tb_rdy_1 = 1'b1;
      tb.test_case_check(config_msgs_1[i], driver_tb_msg_1, $sformatf("config_msg_1[%0d]", i));
      @(posedge clk_1);
      @(negedge clk_1);
      driver_tb_rdy_1 = 1'b0;
    end
    end
    begin
    for (int i = 0; i < 4; i++) begin
      while(!tb_driver_rdy_2) #1;
      tb_driver_msg_2 = config_msgs_2[i];
      tb_driver_val_2 = 1'b1;
      @(posedge clk_2);
      @(negedge clk_2);
      tb_driver_val_2 = 1'b0;

      while (!driver_tb_val_2) #1;
      driver_tb_rdy_2 = 1'b1;
      tb.test_case_check(config_msgs_2[i], driver_tb_msg_2, $sformatf("config_msg_2[%0d]", i));
      @(posedge clk_2);
      @(negedge clk_2);
      driver_tb_rdy_2 = 1'b0;
    end
    end
  join

  // Initialize messages to send and receive
  for (int i = 0; i < num_msgs; i++) begin
    src_msgs_1_2[i] = {logic'(`CHNL_MSG), p_config_width'($urandom() % (2**p_channel_width))};
    src_msgs_2_1[i] = {logic'(`CHNL_MSG), p_config_width'($urandom() % (2**p_channel_width))};
  end

  // Send and receive messages at offset times in segments
  fork

    // Send on chip 1
    for(int s = 0; s < num_segs; s++) begin
      for (int i = 0; i < num_msgs; i++) begin 
        while(!tb_driver_rdy_1) #1;
        tb_driver_msg_1 = src_msgs_1_2[i];
        tb_driver_val_1 = 1'b1;
        @(posedge clk_1);
        @(negedge clk_1);
        tb_driver_val_1 = 1'b0;
        #(max_clk_pd*(2**max_clk_div_mult)*10000);
      end
      if (s != num_segs-1) #(max_clk_pd*(2**max_clk_div_mult)*1000000); // is this is the last segment don't wait because no point
    end

    // Receive on chip 2
    for(int s = 0; s < num_segs; s++) begin
      #(max_clk_pd*(2**max_clk_div_mult)*1000000);
      for (int i = 0; i < num_msgs; i++) begin
        while (!driver_tb_val_2) #1;
        driver_tb_rdy_2 = 1'b1;
        tb.test_case_check(src_msgs_1_2[i], driver_tb_msg_2, $sformatf("recvd msg %0d for seg %0d on 2", i, s));
        @(posedge clk_2);
        @(negedge clk_2);
        driver_tb_rdy_2 = 1'b0;
        #(max_clk_pd*(2**max_clk_div_mult)*10000);
      end
    end

    // Send on chip 2
    for(int s = 0; s < num_segs; s++) begin
      for (int i = 0; i < num_msgs; i++) begin 
        while(!tb_driver_rdy_2) #1;
        tb_driver_msg_2 = src_msgs_2_1[i];
        tb_driver_val_2 = 1'b1;
        @(posedge clk_2);
        @(negedge clk_2);
        tb_driver_val_2 = 1'b0;
        #(max_clk_pd*(2**max_clk_div_mult)*10000);
      end
      if (s != num_segs-1) #(max_clk_pd*(2**max_clk_div_mult)*1000000);
    end

    // Receive on chip 1
    for(int s = 0; s < num_segs; s++) begin
      #(max_clk_pd*(2**max_clk_div_mult)*1000000);
      for (int i = 0; i < num_msgs; i++) begin
        while (!driver_tb_val_1) #1;
        driver_tb_rdy_1 = 1'b1;
        tb.test_case_check(src_msgs_2_1[i], driver_tb_msg_1, $sformatf("recvd msg %0d for seg %0d on 1", i, s));
        @(posedge clk_1);
        @(negedge clk_1);
        driver_tb_rdy_1 = 1'b0;
        #(max_clk_pd*(2**max_clk_div_mult)*10000);
      end
    end

  join

endtask

//----------------------------------------------------------------------
// test_config_backpressure
//----------------------------------------------------------------------
task automatic test_config_backpressure (
  string  name,
  integer clk_pd_1       = -1,
  integer clk_pd_2       = -1,
  integer clk_div_mult_1 = -1,
  integer clk_div_mult_2 = -1,
  integer rst_delay_1    = -1,
  integer rst_delay_2    = -1,
  integer inj_skew_1_2   = -1,
  integer inj_skew_2_1   = -1,
  integer skew_set_1     = -1, // must be < 2**clk_div_mult,
  integer skew_set_2     = -1, // must be < 2**clk_div_mult,
  integer num_msgs       = -1,
  integer num_segs       = -1,
  bit     eq_rand        = 0, // 1 = equalize random freqs
  bit     inj_skew_mode  = 0, // 0 = random, 1 = alternate between 0 and max
  integer seed           = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);
  integer max_clk_pd, max_clk_div_mult;
  integer message;
  integer src_sink_idx_1 = 0;
  integer src_sink_idx_2 = 0;
  bit     skew_zero;
  logic [p_input_width-1:0] config_msgs[];
  config_msgs = new[num_msgs];

  if (clk_pd_1       == -1) clk_pd_1       = p_min_clk_pd + ($urandom() % (p_max_clk_pd - 1)); // always produce even value
  if (clk_pd_2       == -1) clk_pd_2       = eq_rand ? clk_pd_1 : (p_min_clk_pd + ($urandom() % (p_max_clk_pd - 1))); // always produce even value
  if (clk_div_mult_1 == -1) clk_div_mult_1 = $urandom() % (p_max_clk_div_mult + 1);
  if (clk_div_mult_2 == -1) clk_div_mult_2 = eq_rand ? clk_div_mult_1 : ($urandom() % (p_max_clk_div_mult + 1));
  if (rst_delay_1    == -1) rst_delay_1    = 2*clk_pd_1 + ($urandom() % (p_max_rst_delay - 2*clk_pd_1 + 1)); // guarantee at least 2 clk cycles of delay
  if (rst_delay_2    == -1) rst_delay_2    = 2*clk_pd_2 + ($urandom() % (p_max_rst_delay - 2*clk_pd_2 + 1)); // guarantee at least 2 clk cycles of delay
  if (skew_set_1     == -1) skew_set_1     = 0;
  if (skew_set_2     == -1) skew_set_2     = 0;
  if (num_msgs       == -1) num_msgs       = 1 + $urandom() % (p_max_msgs);
  if (num_segs       == -1) num_segs       = 1 + $urandom() % (p_max_segs);
  error_en_1_2 = (p_channel_width+5)'(0);
  error_en_2_1 = (p_channel_width+5)'(0);

  max_clk_pd = clk_pd_1 > clk_pd_2 ? clk_pd_1 : clk_pd_2;
  max_clk_div_mult = clk_div_mult_1 > clk_div_mult_2 ? clk_div_mult_1 : clk_div_mult_2;

  // Initialize skews (inj_skew != -1 means it is the upper limit for possible skews)
  skew_zero = 1'b1;
  for (int i = 0; i < p_channel_width; i++) begin
    msg_skews_1_2[i] = inj_skew_mode ? (skew_zero ? 0 : inj_skew_1_2) : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1)); // can tolerate < half clk cycle of skew without deskewing
    msg_skews_2_1[i] = inj_skew_mode ? (skew_zero ? 0 : inj_skew_2_1) : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1)); // can tolerate < half clk cycle of skew without deskewing
    skew_zero = ~skew_zero;
  end
  val_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  val_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  clk_skew_1_2    = 0;
  clk_skew_2_1    = 0;
  rst_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  rst_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  cred_skew_1_2   = inj_skew_mode ? 0 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  cred_skew_2_1   = inj_skew_mode ? 0 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  crc_skew_1_2    = inj_skew_mode ? inj_skew_1_2 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  crc_skew_2_1    = inj_skew_mode ? inj_skew_2_1 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));
  repair_skew_1_2 = inj_skew_mode ? 0 : (inj_skew_1_2 == -1 ? $urandom() % (clk_pd_1/2 - 1) : $urandom() % (inj_skew_1_2 + 1));
  repair_skew_2_1 = inj_skew_mode ? 0 : (inj_skew_2_1 == -1 ? $urandom() % (clk_pd_2/2 - 1) : $urandom() % (inj_skew_2_1 + 1));

  tb_driver_val_1 = 1'b0;
  tb_driver_msg_1 = {p_input_width{1'b0}};
  tb_driver_val_2 = 1'b0;
  tb_driver_msg_2 = {p_input_width{1'b0}};
  driver_tb_rdy_1 = 1'b0;
  driver_tb_rdy_2 = 1'b0;

  tb.test_case_begin(
    name,
    clk_pd_1,
    clk_pd_2,
    rst_delay_1,
    rst_delay_2,
    1,
    1,
    seed
  );

  // Configure links
  for (int i = 0; i < num_msgs; i++)
    config_msgs[i] = {logic'(`CNFG_MSG), p_addr_width'($urandom() % (p_max_addr_val)), p_config_width'($urandom())};

  // Send and receive messages at offset times in segments
  fork
    for(int s = 0; s < num_segs; s++) begin
      for (int i = 0; i < num_msgs; i++) begin
        while(!tb_driver_rdy_1) #1;
        tb_driver_msg_1 = config_msgs[i];
        tb_driver_val_1 = 1'b1;
        @(posedge clk_1);
        @(negedge clk_1);
        tb_driver_val_1 = 1'b0;
        #(max_clk_pd*(2**max_clk_div_mult)*10000);
      end
      if (s != num_segs-1) #(max_clk_pd*(2**max_clk_div_mult)*1000000);
    end
    for(int s = 0; s < num_segs; s++) begin
      #(max_clk_pd*(2**max_clk_div_mult)*1000000);
      for (int i = 0; i < num_msgs; i++) begin
        while (!driver_tb_val_1) #1;
        driver_tb_rdy_1 = 1'b1;
        tb.test_case_check( // check only routing bit and address
          config_msgs[i][p_input_width-1:p_input_width-1-p_addr_width],
          driver_tb_msg_1[p_input_width-1:p_input_width-1-p_addr_width],
          $sformatf("recvd msg %0d for seg %0d", i, s)
        );
        @(posedge clk_1);
        @(negedge clk_1);
        driver_tb_rdy_1 = 1'b0;
        #(max_clk_pd*(2**max_clk_div_mult)*10000);
      end
    end
  join

endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_cw_%0d_mc_%0d_rbd_%0d", p_channel_width, p_max_credit, p_resp_buffer_depth);
  tb.test_bench_start($sformatf("DualLinkV4BackpressureTest%s", suffix));

// DO NOT LET THESE RUN ON VERILATOR REGRESSION TESTS IT WILL PROBABLY TAKE MORE
// TIME THAN THERE IS IN THE UNIVERSE - NEEDS EXPLICIT +long PLUSARG IN VCS ONLY
if ($test$plusargs("long")) begin
  if ((tb.test_case == 0)  || (tb.test_case == 1)) 
    test_send_all_wait_receive_all_one_way(
      .name ($sformatf("one_way_max_credit_msgs_uneq_rand_freq_under_deskew_thresh%s", suffix)),
      .clk_pd_1(-1),
      .clk_pd_2(-1),
      .clk_div_mult_1(0),
      .clk_div_mult_2(0),
      .rst_delay_1(-1),
      .rst_delay_2(-1),
      .inj_skew_1_2(-1),
      .inj_skew_2_1(-1),
      .skew_set_1(0),
      .skew_set_2(0),
      .num_msgs(p_max_credit)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 2)) 
    test_interlaced_one_way(
      .name ($sformatf("one_way_thousand_msgs_uneq_rand_freq_under_deskew_thresh%s", suffix)),
      .clk_pd_1(-1),
      .clk_pd_2(-1),
      .clk_div_mult_1(0),
      .clk_div_mult_2(0),
      .rst_delay_1(-1),
      .rst_delay_2(-1),
      .inj_skew_1_2(-1),
      .inj_skew_2_1(-1),
      .skew_set_1(0),
      .skew_set_2(0),
      .num_msgs(1000),
      .num_segs(1)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 3)) 
    test_interlaced_one_way(
      .name ($sformatf("one_way_hundred_msgs_three_segs_uneq_rand_freq_under_deskew_thresh%s", suffix)),
      .clk_pd_1(-1),
      .clk_pd_2(-1),
      .clk_div_mult_1(0),
      .clk_div_mult_2(0),
      .rst_delay_1(-1),
      .rst_delay_2(-1),
      .inj_skew_1_2(-1),
      .inj_skew_2_1(-1),
      .skew_set_1(0),
      .skew_set_2(0),
      .num_msgs(100),
      .num_segs(3)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 4)) 
    test_send_all_wait_receive_all_two_way(
      .name ($sformatf("two_way_max_credit_msgs_uneq_rand_freq_under_deskew_thresh%s", suffix)),
      .clk_pd_1(-1),
      .clk_pd_2(-1),
      .clk_div_mult_1(0),
      .clk_div_mult_2(0),
      .rst_delay_1(-1),
      .rst_delay_2(-1),
      .inj_skew_1_2(-1),
      .inj_skew_2_1(-1),
      .skew_set_1(0),
      .skew_set_2(0),
      .num_msgs(p_max_credit)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 5)) 
    test_interlaced_two_way(
      .name ($sformatf("two_way_thousand_msgs_uneq_rand_freq_under_deskew_thresh%s", suffix)),
      .clk_pd_1(-1),
      .clk_pd_2(-1),
      .clk_div_mult_1(0),
      .clk_div_mult_2(0),
      .rst_delay_1(-1),
      .rst_delay_2(-1),
      .inj_skew_1_2(-1),
      .inj_skew_2_1(-1),
      .skew_set_1(0),
      .skew_set_2(0),
      .num_msgs(1000),
      .num_segs(1)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 6)) 
    test_interlaced_two_way(
      .name ($sformatf("two_way_hundred_msgs_three_segs_uneq_rand_freq_under_deskew_thresh%s", suffix)),
      .clk_pd_1(-1),
      .clk_pd_2(-1),
      .clk_div_mult_1(0),
      .clk_div_mult_2(0),
      .rst_delay_1(-1),
      .rst_delay_2(-1),
      .inj_skew_1_2(-1),
      .inj_skew_2_1(-1),
      .skew_set_1(0),
      .skew_set_2(0),
      .num_msgs(100),
      .num_segs(3)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 7)) 
    test_config_backpressure(
      .name ($sformatf("config_thousand_msgs_uneq_rand_freq_under_deskew_thresh%s", suffix)),
      .clk_pd_1(-1),
      .clk_pd_2(-1),
      .clk_div_mult_1(0),
      .clk_div_mult_2(0),
      .rst_delay_1(-1),
      .rst_delay_2(-1),
      .inj_skew_1_2(-1),
      .inj_skew_2_1(-1),
      .skew_set_1(0),
      .skew_set_2(0),
      .num_msgs(1000),
      .num_segs(1)
    );
  if ((tb.test_case == 0)  || (tb.test_case == 8)) 
    test_config_backpressure(
      .name ($sformatf("config_hundred_msgs_three_segs_uneq_rand_freq_under_deskew_thresh%s", suffix)),
      .clk_pd_1(-1),
      .clk_pd_2(-1),
      .clk_div_mult_1(0),
      .clk_div_mult_2(0),
      .rst_delay_1(-1),
      .rst_delay_2(-1),
      .inj_skew_1_2(-1),
      .inj_skew_2_1(-1),
      .skew_set_1(0),
      .skew_set_2(0),
      .num_msgs(100),
      .num_segs(3)
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
