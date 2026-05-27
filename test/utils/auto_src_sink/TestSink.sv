`ifndef BRGTC6_TEST_SINK
`define BRGTC6_TEST_SINK

`include "utils/vc/vc-regs.v"
`include "utils/TestUtilsDefs.sv"

//========================================================================
// TestSink
//========================================================================
// p_sim_mode should be set to one in simulators. This will cause the
// sink to abort after the first failure with an appropriate error
// message.

/*verilator coverage_off*/
module TestSink #(
  parameter p_msg_nbits = 1,
  parameter p_num_msgs  = 1024
)(
  input  logic                   clk,
  input  logic                   reset,

  // Sink message interface
  input  logic                   val,
  output logic                   rdy,
  input  logic [p_msg_nbits-1:0] msg,

  // Indicates if input message fails or passes
  output logic                   fail,
  output logic                   pass,

  // Goes high once all sink data has been received
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

  // Memory which stores messages to verify against those received
  logic [p_msg_nbits-1:0] m[p_num_msgs*2-1:0];
  integer last_index = 0;

  // Index register pointing to next message to verify
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
  // We use a behavioral hack to easily detect when we have gone off the
  // end of the valid messages in the memory.
  // assign done = !reset_reg && ( m[index] === {p_msg_nbits{1'bx}} );
  assign done = !reset_reg && ( index >= last_index );

  // Sink message interface is ready as long as we are not done
  assign rdy = !reset_reg && !done;

  // We bump the index pointer every time we successfully receive a
  // message, otherwise the index stays the same.
  assign index_en   = val && rdy;
  assign index_next = index + 1'b1;

  // The go signal is high when a message is transferred
  logic go;
  assign go = val && rdy;

  //----------------------------------------------------------------------
  // Verification logic
  //----------------------------------------------------------------------
  always_comb begin
    if ( !reset && go ) begin
        if ( m[index] !== ( m[index] ^ msg ^ m[index] ) ) begin
          fail = 1;
          pass = 0;
        end
        else begin
          fail = 0;
          pass = 1;
        end
    end else begin
      fail = 0;
      pass = 0;
    end
  end

endmodule
/*verilator coverage_on*/

`endif
