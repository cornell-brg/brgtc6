`timescale 1ns/1ps

`ifndef BRGTC6_GRAY_TO_BIN_UNIT_TEST
`define BRGTC6_GRAY_TO_BIN_UNIT_TEST

`include "asyncfifo/GrayToBin.sv"
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
      GrayToBinTest #(
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
module GrayToBinTest # (
  parameter p_bit_width = 8
)(
  input  logic go,
  output logic done,
  output logic pass
);

logic clk;
logic reset;

// Source side
logic [p_bit_width-1:0] gray;

// Sink side
logic [p_bit_width-1:0] bin;

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
GrayToBin #(
  .p_bit_width(p_bit_width)
) dut ( .* );

//----------------------------------------------------------------------
// test_all_gray - confirm all binary values produce correct gray code
//----------------------------------------------------------------------
task automatic test_all_gray (
  string name
);
  logic [p_bit_width-1:0] ref_bin;
  logic [p_bit_width-1:0] logic_ref_gray;

  // Start test case
  tb.test_case_begin (
    $sformatf("%s_bw_%0d", name, p_bit_width),
    10, // arbitrary
    10  // arbitrary
  );

  // Confirm combinational output for all gray values of p_bit_width
  for (integer ref_gray = 0; ref_gray < 2**p_bit_width; ref_gray += 1) begin
    gray = p_bit_width'(ref_gray); // drive input
    logic_ref_gray = p_bit_width'(ref_gray);
    ref_bin[p_bit_width-1] = logic_ref_gray[p_bit_width-1]; // MSB is the same
    for (int i = p_bit_width-2; i >= 0; i--) begin
      ref_bin[i] = ref_bin[i+1] ^ logic_ref_gray[i]; // XOR with the next higher bit
    end
    #1;
    tb.test_case_check(ref_bin, bin); // check output
    #1;
  end

  #100;
endtask

//----------------------------------------------------------------------
// main
//----------------------------------------------------------------------
task automatic run;
  tb.test_bench_start($sformatf("GrayToBinTest_bw_%0d", p_bit_width));

  if (tb.test_case == 1  || tb.test_case == 0) test_all_gray("test_all_gray");

  tb.test_bench_end();
endtask

always @(posedge go) begin
  run();
end

endmodule
/*verilator coverage_on*/

`endif
