`timescale 1ns/1ps

`ifndef BRGTC6_BIN_TO_GRAY_UNIT_TEST
`define BRGTC6_BIN_TO_GRAY_UNIT_TEST

`include "asyncfifo/BinToGray.sv"
`include "utils/manual/ManualCheckSingleClkTB.sv"

//----------------------------------------------------------------------
// Top
//----------------------------------------------------------------------
/*verilator coverage_off*/
module Top();
  localparam            p_num_duts                = 3;
  localparam integer    p_bit_widths[p_num_duts]  = '{4, 8, 16};

  logic tb_go  [0:p_num_duts-1];
  logic tb_done[0:p_num_duts-1];
  logic tb_pass[0:p_num_duts-1];

  genvar i;
  generate
    for (i = 0; i < p_num_duts; i++) begin : gen_test
      BinToGrayTest #(
        .p_bit_width(p_bit_widths[i])
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
// BinToGrayTest
//----------------------------------------------------------------------
module BinToGrayTest # (
  parameter p_bit_width = 8
)(
  input  logic go,
  output logic done,
  output logic pass
);

logic clk;
logic reset;

// Source side
logic [p_bit_width-1:0] bin;

// Sink side
logic [p_bit_width-1:0] gray;

//----------------------------------------------------------------------
// Testbench instance
//----------------------------------------------------------------------
ManualCheckSingleClkTB #(
  .p_chk_nbits(p_bit_width),
  .p_timeout_period(1000000)
) tb ( .* );

//----------------------------------------------------------------------
// DUT instance
//----------------------------------------------------------------------
BinToGray #(
  .p_bit_width(p_bit_width)
) dut ( .* );

//----------------------------------------------------------------------
// test_all_binary - confirm all binary values produce correct gray code
//----------------------------------------------------------------------
task automatic test_all_binary (
  string name
);

  // Start test case
  tb.test_case_begin (
    name,
    10, // arbitrary
    10  // arbitrary
  );

  // Confirm combinational output for all binary values of bit_width
  for (int ref_bin = 0; ref_bin < 2**p_bit_width; ref_bin++) begin
    bin = p_bit_width'(ref_bin); // drive input
    #1;
    tb.test_case_check(p_bit_width'(ref_bin ^ (ref_bin >> 1)), p_bit_width'(gray)); // check output
    #1;
  end

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  string suffix = $sformatf("_bw_%0d", p_bit_width);
  tb.test_bench_start($sformatf("BinToGrayTest%s", suffix));
  
  if (tb.test_case == 1  || tb.test_case == 0) test_all_binary($sformatf("test_all_binary%s", suffix));

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif 
