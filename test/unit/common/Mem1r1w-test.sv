`timescale 1ns/1ps

`ifndef BRGTC6_MEM1R1W_UNIT_TEST
`define BRGTC6_MEM1R1W_UNIT_TEST

`include "common/Mem1r1w.sv"
`include "utils/manual/ManualCheckSingleClkTB.sv"

import "DPI-C" function int get_system_time_seed();

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam            p_num_duts                = 5;
  localparam integer    p_bit_widths[p_num_duts]  = '{4, 8, 16, 32, 64};
  localparam integer    p_num_entries[p_num_duts] = '{64, 32, 16, 8, 4}; 

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      Mem1r1wTest #(
        .p_bit_width(p_bit_widths[i]),
        .p_num_entries(p_num_entries[i])
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
        if (tb_done[idx] == 0) begin
          all_done = 0;
        end
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
// Mem1r1wTest
//----------------------------------------------------------------------
module Mem1r1wTest # (
  parameter p_bit_width        = 8,
  parameter p_num_entries      = 8,
  parameter p_addr_width       = $clog2(p_num_entries),
  parameter p_max_clock_period = 100,
  parameter p_max_rst_delay    = 100,
  parameter p_max_wait_cycles  = 100
)(
  input  logic go,
  output logic done,
  output logic pass
);

logic                    clk;
logic                    reset;
logic                    write_en;
logic [p_addr_width-1:0] write_addr;
logic [ p_bit_width-1:0] write_data;
logic                    read_en;
logic [p_addr_width-1:0] read_addr;
logic [ p_bit_width-1:0] read_data;

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
ManualCheckSingleClkTB #(
  .p_chk_nbits(p_bit_width)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
Mem1r1w #(
  .p_num_entries(p_num_entries),
  .p_bit_width(p_bit_width)
) dut ( .* );

//----------------------------------------------------------------------
// test_standard
//----------------------------------------------------------------------
task automatic test_standard (
  string  name,
  integer clk_period = -1,
  integer rst_delay  = -1,
  integer seed       = 32'(get_system_time_seed() + $time)
);
  integer dummy_rand = $urandom(seed);

  if (clk_period == -1) clk_period = 2 + ($urandom() % (p_max_clock_period - 1));
  if (rst_delay  == -1) rst_delay  = 1 + ($urandom() % (p_max_rst_delay));

  // Initialize test case
  tb.test_case_begin (
    name,
    clk_period,
    rst_delay,
    seed
  );
  
  #(1 + ($urandom() % (p_max_wait_cycles)));

  // write (synchronous)
  @(negedge clk);
  write_addr = {p_addr_width{1'b1}};
  write_data = {p_bit_width{1'b1}};
  write_en = 1;
  @(negedge clk);
  write_en = 0;
  #1;
  tb.test_case_check({p_bit_width{1'b1}}, dut.mem[{p_addr_width{1'b1}}], "mem");
  
  #(1 + ($urandom() % (p_max_wait_cycles)));

  // read (asynchronous)
  read_addr = {p_addr_width{1'b1}};
  read_en = 1;
  #1;
  tb.test_case_check({p_bit_width{1'b1}}, dut.mem[{p_addr_width{1'b1}}], "mem"); // mem should still be written
  tb.test_case_check({p_bit_width{1'b1}}, read_data, "read_data");

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_bw_%0d_ne_%0d", p_bit_width, p_num_entries);
  tb.test_bench_start($sformatf("Mem1r1wTest%s", suffix));
  
  // One element
  if (tb.test_case == 1  || tb.test_case == 0) test_standard($sformatf("write_and_read_single_addr%s", suffix));

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
