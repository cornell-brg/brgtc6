`timescale 1ns/1ps

`ifndef BRGTC6_SPI_DRIVER_TEST
`define BRGTC6_SPI_DRIVER_TEST

`include "utils/spi/SpiDriver.sv"
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
  localparam integer    p_sclk_periods[p_num_duts] = '{40, 20, 10};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  // Generate test benches
  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      SpiDriverTest #(
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
// SpiDriverTest - performs a loopback (miso = mosi)
//----------------------------------------------------------------------
module SpiDriverTest #(
  parameter p_bit_width       = 8,
  parameter p_sclk_period     = 20,
  parameter p_max_clk_pd_mult = 5,
  parameter p_max_rst_delay   = 100,
  parameter p_max_msg_delay   = 100,
  parameter p_max_msgs        = 100
) (
  input  logic go,
  output logic done,
  output logic pass
);

logic clk;
logic reset;

logic sclk;
logic mosi;
logic miso;
logic cs;

logic [p_bit_width-1:0] send_msg;
logic                   send_val;
logic                   send_rdy;

logic [p_bit_width-1:0] recv_msg;
logic                   recv_val;
logic                   recv_rdy;

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
ManualCheckSingleClkTB #(
  .p_chk_nbits(p_bit_width),
  .p_timeout_period(100000)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
SpiDriver #(
  .p_bit_width(p_bit_width),
  .p_sclk_period(p_sclk_period)
) dut ( .* );

// Loopback
assign miso = mosi;

//----------------------------------------------------------------------
// test_basic
//----------------------------------------------------------------------
task automatic test_basic (
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

  @(posedge clk);
  tb.test_case_begin (
    name,
    2**clk_pd_mult,
    rst_delay,
    seed
  );
  recv_rdy = 1;
  send_val = 0;

  for (int i = 0; i < num_msgs; i++) begin
    while (send_rdy == 0) #1;
    @(negedge clk);
    send_msg = p_bit_width'($urandom());
    send_val = 1;
    @(negedge clk);
    send_val = 0;

    while (recv_val == 0) #1;
    @(negedge clk);
    tb.test_case_check(send_msg, recv_msg, "SPI Loopback");

    #(1 + ($urandom() % p_max_msg_delay));
  end

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_bw_%0d_sp_%0d", p_bit_width, p_sclk_period);
  tb.test_bench_start($sformatf("SpiDriverTest%s", suffix));
  
  if ((tb.test_case == 0)  || (tb.test_case == 1)) test_basic($sformatf("test_1_msg%s", suffix), 5, -1, 1);
  if ((tb.test_case == 0)  || (tb.test_case == 2)) test_basic($sformatf("test_10_msgs%s", suffix), 5, -1, 10);
  if ((tb.test_case == 0)  || (tb.test_case == 3)) test_basic($sformatf("test_slow_core_clk%s", suffix), 5, -1, 10);
  if ((tb.test_case == 0)  || (tb.test_case == 4)) test_basic($sformatf("test_fast_core_clk%s", suffix), 2, -1, 10);
  if ((tb.test_case == 0)  || (tb.test_case == 5)) test_basic($sformatf("test_rand%s", suffix));

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
