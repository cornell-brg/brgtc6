`ifndef BRGTC6_DUAL_CLK_UTILS
`define BRGTC6_DUAL_CLK_UTILS

`timescale 1ns/1ps

`include "utils/TestUtilsDefs.sv"

//----------------------------------------------------------------------
// BRGTC6DualClockUtils
//----------------------------------------------------------------------
/*verilator coverage_off*/
module DualClockUtils #(
  parameter p_timeout_period = 10000
) (
  output logic clk_1,
  output logic rst_1,
  output logic clk_2,
  output logic rst_2,
  output logic timeout_occurred
);

//----------------------------------------------------------------------
// Initialize resets
//----------------------------------------------------------------------
initial rst_1 = 0;
initial rst_2 = 0;

//----------------------------------------------------------------------
// Clock controllers
//----------------------------------------------------------------------
integer clk_pd_1 = 10;
integer clk_pd_2 = 10;

logic clk_rst;
initial clk_rst = 0;

logic ack_1;
initial ack_1 = 0;

logic ack_2;
initial ack_2 = 0;

initial clk_1 = 1'b1;
initial clk_2 = 1'b1;

always begin
  if (!clk_rst) begin
    clk_1 <= ~clk_1;
    ack_1 <= 0;
    #((clk_pd_1*500)*1ps);
  end
  else begin
    clk_1 <= 1'b0;
    ack_1 <= 1;
    #2; // For clk_rst alignment
  end
end

always begin
  if (!clk_rst) begin
    clk_2 <= ~clk_2;
    ack_2 <= 0;
    #((clk_pd_2*500)*1ps);
  end
  else begin
    clk_2 <= 1'b0;
    ack_2 <= 1;
    #2; // For clk_rst alignment
  end
end

//----------------------------------------------------------------------
// Cycle counters + timeout checks
//----------------------------------------------------------------------
logic  timeout_1        = 0;
logic  timeout_2        = 0;
assign timeout_occurred = timeout_1 | timeout_2;

int cycles_1;
always @(posedge clk_1) begin
  if (rst_1)
    cycles_1 <= 0;
  else
    cycles_1 <= cycles_1 + 1;

  if (cycles_1 > p_timeout_period) begin
    $write($sformatf("\n\n%sTIMEOUT @ %0dns%s", `BRGTC6_RED, $time, `BRGTC6_RESET));
    timeout_1 <= 1;
  end
end

int cycles_2;
always @(posedge clk_2) begin
  if (rst_2)
    cycles_2 <= 0;
  else
    cycles_2 <= cycles_2 + 1;

  if (cycles_2 > p_timeout_period) begin
    $write($sformatf("\n\n%sTIMEOUT @ %0dns%s", `BRGTC6_RED, $time, `BRGTC6_RESET));
    timeout_2 <= 1;
  end
end

//----------------------------------------------------------------------
// Sets clocks
//----------------------------------------------------------------------
task set_clock (
  integer new_clk_pd_1,
  integer new_clk_pd_2
);

  // Wait for clocks to not be in delay statement and reset them
  // Note: clocks will wait at logic low and transition to high at the same time
  // as the resets go high, but this should mean the high reset is not captured
  // until the next cycle as long as it is delayed by at least the new clock
  // period
  clk_rst = 1;
  while(!(ack_1 && ack_2)) #1;
  clk_pd_1 = new_clk_pd_1;
  clk_pd_2 = new_clk_pd_2;
  clk_rst = 0;
endtask

//----------------------------------------------------------------------
// do_reset
//----------------------------------------------------------------------
task do_reset (
  integer rst_delay_1,
  integer rst_delay_2,
  bit     rst_en_1,
  bit     rst_en_2
);

  fork
    begin 
      if (rst_en_1) begin
        rst_1 = 1;
        #rst_delay_1;
        rst_1 = 0;
      end
    end
    begin
      if (rst_en_2) begin
        rst_2 = 1;
        #rst_delay_2;
        rst_2 = 0;
      end
    end
  join
endtask

endmodule
/*verilator coverage_on*/

`endif
