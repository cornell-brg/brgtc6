`timescale 1ns/1ps

`ifndef BRGTC6_SPI_DRIVER_VAL_RDY_TEST
`define BRGTC6_SPI_DRIVER_VAL_RDY_TEST

`include "spi/minion.v"
`include "utils/spi/SpiDriverValRdy.sv"
`include "utils/manual/ManualCheckSingleClkTB.sv"

`ifndef BRGTC6_TIME_SEED
`define BRGTC6_TIME_SEED
import "DPI-C" function int get_system_time_seed();
`endif

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam            p_num_duts                 = 3;
  localparam integer    p_bit_widths[p_num_duts]   = '{8, 16, 17};
  localparam integer    p_sclk_periods[p_num_duts] = '{1000, 1000, 1000};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  // Generate test benches
  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      SpiDriverValRdyTest #(
        .p_bit_width(p_bit_widths[i]),
        .p_sclk_period(p_sclk_periods[i])
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
// SpiDriverValRdyTest
//----------------------------------------------------------------------
module SpiDriverValRdyTest #(
  parameter p_bit_width       = 8,
  parameter p_sclk_period     = 20,
  parameter p_max_clk_pd_mult = 5,
  parameter p_max_rst_delay   = 100,
  parameter p_max_msg_delay   = 100,
  parameter p_max_msgs        = 100,
  parameter p_max_segs        = 5
) (
  input  logic go,
  output logic done,
  output logic pass
);

logic clk;
logic reset;

// SPI signals
logic sclk;
logic mosi;
logic miso;
logic cs;

// SPI Driver Val/Rdy
logic [p_bit_width-1:0] driver_istream_msg;
logic                   driver_istream_val;
logic                   driver_istream_rdy;

logic [p_bit_width-1:0] driver_ostream_msg;
logic                   driver_ostream_val;
logic                   driver_ostream_rdy;

// Minion Val/Rdy
logic [p_bit_width-1:0] minion_istream_msg;
logic                   minion_istream_val;
logic                   minion_istream_rdy;

logic [p_bit_width-1:0] minion_ostream_msg;
logic                   minion_ostream_val;
logic                   minion_ostream_rdy;

logic minion_parity;
logic adapter_parity;

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
ManualCheckSingleClkTB #(
  .p_chk_nbits(p_bit_width),
  .p_timeout_period(100000000)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
SpiDriverValRdy #(
  .p_bit_width(p_bit_width),
  .p_sclk_period(p_sclk_period)
) dut (
    .istream_msg(driver_istream_msg),
    .istream_val(driver_istream_val),
    .istream_rdy(driver_istream_rdy),
    .ostream_msg(driver_ostream_msg),
    .ostream_val(driver_ostream_val),
    .ostream_rdy(driver_ostream_rdy),
    .*
);

//----------------------------------------------------------------------
// SPI Minion
//----------------------------------------------------------------------
spi_Minion #(
  .BIT_WIDTH(p_bit_width),
  .N_SAMPLES(1)
) minion (
    .recv_msg(minion_istream_msg),
    .recv_val(minion_istream_val),
    .recv_rdy(minion_istream_rdy),
    .send_msg(minion_ostream_msg),
    .send_val(minion_ostream_val),
    .send_rdy(minion_ostream_rdy),
    .*
);

//----------------------------------------------------------------------
// test_one_way_msg
//----------------------------------------------------------------------
task automatic test_one_way_msg (
  string  name,
  integer clk_pd_mult = -1,
  integer rst_delay   = -1,
  integer seed        = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  if (clk_pd_mult  == -1) clk_pd_mult  = 1 + ($urandom() % (p_max_clk_pd_mult));
  if (rst_delay    == -1) rst_delay    = 2**clk_pd_mult + ($urandom() % (p_max_rst_delay - 2**clk_pd_mult + 1));

  @(posedge clk);
  tb.test_case_begin (
    name,
    2**clk_pd_mult,
    rst_delay,
    seed
  );
  minion_ostream_rdy = 1;
  minion_istream_val = 0;
  minion_istream_msg = 0;
  driver_istream_val = 0;
  driver_istream_msg = 0;
  driver_ostream_rdy = 1;

  while (driver_istream_rdy == 0) #1;
  @(negedge clk);
  driver_istream_msg = p_bit_width'($urandom());
  driver_istream_val = 1;
  @(negedge clk);
  driver_istream_val = 0;

  while (minion_ostream_val == 0) #1;
  @(negedge clk);
  tb.test_case_check(driver_istream_msg, minion_ostream_msg, "one-way msg");

  #100;
endtask

//----------------------------------------------------------------------
// test_loopback_msgs
//----------------------------------------------------------------------
task automatic test_loopback_msgs (
  string  name,
  integer clk_pd_mult = -1,
  integer rst_delay   = -1,
  integer num_msgs    = -1,
  integer seed        = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  if (clk_pd_mult  == -1) clk_pd_mult  = 1 + ($urandom() % (p_max_clk_pd_mult));
  if (rst_delay    == -1) rst_delay    = 2**clk_pd_mult + ($urandom() % (p_max_rst_delay - 2**clk_pd_mult + 1));
  if (num_msgs     == -1) num_msgs     = 1 + ($urandom() % (p_max_msgs));

  minion_ostream_rdy = 1;
  minion_istream_val = 0;
  minion_istream_msg = 0;
  driver_istream_val = 0;
  driver_istream_msg = 0;
  driver_ostream_rdy = 1;

  tb.test_case_begin (
    name,
    2**clk_pd_mult,
    rst_delay,
    seed
  );

  for (int i = 0; i < num_msgs; i++) begin
    while (driver_istream_rdy == 0) #1;
    driver_istream_msg = p_bit_width'($urandom());
    driver_istream_val = 1;
    @(posedge clk);
    @(negedge clk);
    driver_istream_val = 0;

    while (minion_ostream_val == 0) #1;
    tb.test_case_check(driver_istream_msg, minion_ostream_msg, "minion msg");

    #(1 + ($urandom() % p_max_msg_delay));

    if (minion_istream_rdy == 0) #1;
    minion_istream_msg = driver_istream_msg;
    minion_istream_val = 1;
    @(posedge clk);
    @(negedge clk);
    minion_istream_val = 0;

    while (driver_ostream_val == 0) #1;
    tb.test_case_check(driver_istream_msg, driver_ostream_msg, "loopback msg");

    #(1 + ($urandom() % p_max_msg_delay));
  end

  #100;
endtask

//----------------------------------------------------------------------
// test_minion_recvr_not_rdy
//----------------------------------------------------------------------
task automatic test_minion_recvr_not_rdy (
  string  name,
  integer clk_pd_mult = -1,
  integer rst_delay   = -1,
  integer num_msgs    = -1,
  integer num_segs    = -1,
  integer seed        = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);
  logic [p_bit_width-1:0] src_msgs[];
  src_msgs = new[num_msgs];

  if (clk_pd_mult  == -1) clk_pd_mult  = 1 + ($urandom() % (p_max_clk_pd_mult));
  if (rst_delay    == -1) rst_delay    = 2**clk_pd_mult + ($urandom() % (p_max_rst_delay - 2**clk_pd_mult + 1));
  if (num_msgs     == -1) num_msgs     = 1 + ($urandom() % (p_max_msgs));
  if (num_segs     == -1) num_segs     = 1 + ($urandom() % (p_max_segs));

  minion_ostream_rdy = 0; // receiver not ready
  minion_istream_val = 0;
  minion_istream_msg = 0;
  driver_istream_val = 0;
  driver_istream_msg = 0;
  driver_ostream_rdy = 0;

  tb.test_case_begin (
    name,
    2**clk_pd_mult,
    rst_delay,
    seed
  );

  // Initialize messages to send and receive
  for (int i = 0; i < num_msgs; i++)
    src_msgs[i] = p_bit_width'($urandom());

  fork
    for (int s = 0; s < num_segs; s++) begin
      for (int i = 0; i < num_msgs; i++) begin
        while (!driver_istream_rdy) #1;
        driver_istream_msg = src_msgs[i];
        driver_istream_val = 1;
        @(posedge clk);
        @(negedge clk);
        driver_istream_val = 0;
        #((2**clk_pd_mult)*10000);
      end
      if (s != num_segs-1) #((2**clk_pd_mult)*1000000);
    end
    for (int s = 0; s < num_segs; s++) begin
      #((2**clk_pd_mult)*1000000);
      for (int i = 0; i < num_msgs; i++) begin
        while (!minion_ostream_val) #1;
        minion_ostream_rdy = 1;
        tb.test_case_check(src_msgs[i], minion_ostream_msg, "minion msg");
        @(posedge clk);
        @(negedge clk);
        minion_ostream_rdy = 0;
        #((2**clk_pd_mult)*10000);
      end
    end
  join

  #100;
endtask

//----------------------------------------------------------------------
// test_driver_recvr_not_rdy
//----------------------------------------------------------------------
task automatic test_driver_recvr_not_rdy (
  string  name,
  integer clk_pd_mult = -1,
  integer rst_delay   = -1,
  integer num_msgs    = -1,
  integer num_segs    = -1,
  integer seed        = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);
  logic [p_bit_width-1:0] src_msgs[];
  src_msgs = new[num_msgs];

  if (clk_pd_mult  == -1) clk_pd_mult  = 1 + ($urandom() % (p_max_clk_pd_mult));
  if (rst_delay    == -1) rst_delay    = 2**clk_pd_mult + ($urandom() % (p_max_rst_delay - 2**clk_pd_mult + 1));
  if (num_msgs     == -1) num_msgs     = 1 + ($urandom() % (p_max_msgs));
  if (num_segs     == -1) num_segs     = 1 + ($urandom() % (p_max_segs));

  minion_ostream_rdy = 0;
  minion_istream_val = 0;
  minion_istream_msg = 0;
  driver_istream_val = 0;
  driver_istream_msg = 0;
  driver_ostream_rdy = 0; // receiver not ready

  tb.test_case_begin (
    name,
    2**clk_pd_mult,
    rst_delay,
    seed
  );

  // Initialize messages to send and receive
  for (int i = 0; i < num_msgs; i++)
    src_msgs[i] = p_bit_width'($urandom());

  fork
    for (int s = 0; s < num_segs; s++) begin
      for (int i = 0; i < num_msgs; i++) begin
        while (!minion_istream_rdy) #1;
        minion_istream_msg = src_msgs[i];
        minion_istream_val = 1;
        @(posedge clk);
        @(negedge clk);
        minion_istream_val = 0;
        #((2**clk_pd_mult)*10000);
      end
      if (s != num_segs-1) #((2**clk_pd_mult)*1000000);
    end
    for (int s = 0; s < num_segs; s++) begin
      #((2**clk_pd_mult)*1000000);
      for (int i = 0; i < num_msgs; i++) begin
        while (!driver_ostream_val) #1;
        driver_ostream_rdy = 1;
        tb.test_case_check(src_msgs[i], driver_ostream_msg, "driver msg");
        @(posedge clk);
        @(negedge clk);
        driver_ostream_rdy = 0;
        #((2**clk_pd_mult)*10000);
      end
    end
  join

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_bw_%0d_sp_%0d", p_bit_width, p_sclk_period);
  tb.test_bench_start($sformatf("SpiDriverValRdyTest%s", suffix));
  
  if ((tb.test_case == 0)  || (tb.test_case == 1)) test_one_way_msg($sformatf("one_way%s", suffix));
  if ((tb.test_case == 0)  || (tb.test_case == 2)) test_loopback_msgs($sformatf("loopback_2_msgs%s", suffix), -1, -1, 2);
  if ((tb.test_case == 0)  || (tb.test_case == 3)) test_loopback_msgs($sformatf("loopback_100_msgs%s", suffix), -1, -1, 100);
  if ((tb.test_case == 0)  || (tb.test_case == 4)) test_minion_recvr_not_rdy($sformatf("minion_recvr_not_rdy_100_msgs%s", suffix), -1, -1, 100, 1);
  if ((tb.test_case == 0)  || (tb.test_case == 5)) test_driver_recvr_not_rdy($sformatf("driver_recvr_not_rdy_100_msgs%s", suffix), -1, -1, 100, 1);

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
