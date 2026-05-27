`ifndef BRGTC6_TEST_SOURCE
`define BRGTC6_TEST_SOURCE

`include "utils/vc/vc-regs.v"
`include "utils/vc/vc-assert.v"
`include "utils/vc/vc-trace.v"

//========================================================================
// TestSource
//========================================================================
/*verilator coverage_off*/
module TestSource #(
  parameter p_msg_nbits = 1,
  parameter p_num_msgs  = 1024
)(
  input  logic                   clk,
  input  logic                   reset,

  // Source message interface
  output logic                   val,
  input  logic                   rdy,
  output logic [p_msg_nbits-1:0] msg,

  // Goes high once all source msgs has been issued
  output logic                   done
);

  //----------------------------------------------------------------------
  // Local parameters
  //----------------------------------------------------------------------

  // Size of a physical address for the memory in bits
  localparam c_index_nbits = $clog2(p_num_msgs) == 0 ? 2 : $clog2(p_num_msgs) + 1;

  //----------------------------------------------------------------------
  // State
  //----------------------------------------------------------------------

  // Memory which stores messages to send
  logic [p_msg_nbits-1:0] m[p_num_msgs*2-1:0];
  integer last_index = 0;

  // Index register pointing to next message to send
  logic                     index_en;
  logic [c_index_nbits-1:0] index_next;
  logic [c_index_nbits-1:0] index;

  vc_EnResetReg#(c_index_nbits,{c_index_nbits{1'b0}}) index_reg
  (
    .clk   (clk),
    .reset (reset),
    .en    (index_en),
    .d     (index_next),
    .q     (index)
  );

  // Register reset
  logic reset_reg;
  always @( posedge clk )
    reset_reg <= reset;

  //----------------------------------------------------------------------
  // Combinational logic
  //----------------------------------------------------------------------

  assign done = !reset_reg && ( index >= last_index );

  // Set the source message appropriately (cannot do combinationally bc
  // veri...ator doesn't like it lol - so we get this hacky thing)
  always @(clk, index, index_en, last_index) msg <= m[index];

  // Source message interface is valid as long as we are not done
  assign val = !reset_reg && !done;

  // The go signal is high when a message is transferred
  logic go;
  assign go = val && rdy;

  // We bump the index pointer every time we successfully send a message,
  // otherwise the index stays the same.
  assign index_en   = go;
  assign index_next = index + 1'b1 == 0 ? index : index + 1'b1;

endmodule
/*verilator coverage_on*/

`endif
