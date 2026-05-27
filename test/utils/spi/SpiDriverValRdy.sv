`ifndef BRGTC6_SPI_DRIVER_VAL_RDY
`define BRGTC6_SPI_DRIVER_VAL_RDY

`include "utils/spi/SpiDriver.sv"
`include "utils/spi/SyncFifoNextFull.sv"

//----------------------------------------------------------------------
// SpiDriverValRdy
//----------------------------------------------------------------------
/*verilator coverage_off*/
module SpiDriverValRdy #(
  parameter p_bit_width   = 8,
  parameter p_sclk_period = 1000, // 1 MHz typical SPI frequency
  parameter p_idle_cycles = 4
) (
  input  logic                   clk,
  input  logic                   reset,

  // Src
  input  logic                   istream_val,
  output logic                   istream_rdy,
  input  logic [p_bit_width-1:0] istream_msg,

  // Sink
  output logic                   ostream_val,
  input  logic                   ostream_rdy,
  output logic [p_bit_width-1:0] ostream_msg,

  // SPI
  output logic sclk,
  output logic mosi,
  input  logic miso,
  output logic cs
);

// Driver send
logic [p_bit_width+1:0] send_msg;
logic                   send_val;
logic                   send_rdy;

// Driver receive
logic [p_bit_width+1:0] recv_msg;
logic                   recv_val;
logic                   recv_rdy;

logic bypass_in_fifo;
logic just_sent_imsg;
logic just_sent_imsg_delay;
logic out_fifo_istream_rdy;
logic in_fifo_next_full; // unused
logic out_fifo_next_full;

//----------------------------------------------------------------------
// SPI Driver
//----------------------------------------------------------------------
SpiDriver #(
  .p_bit_width(p_bit_width+2),
  .p_sclk_period(p_sclk_period),
  .p_idle_cycles(p_idle_cycles)
) driver ( .* );

// --------------------------------------------------------------------
// Input fifo and controller
// --------------------------------------------------------------------
logic [p_bit_width-1:0] in_fifo_send_msg;
logic                   in_fifo_send_val;

logic                   bypass_val;
logic                   dut_can_send;
assign                  dut_can_send = ~out_fifo_next_full & out_fifo_istream_rdy;

assign send_msg = bypass_in_fifo ? {1'b0, dut_can_send, {p_bit_width{1'b0}}} : {1'b1, dut_can_send, in_fifo_send_msg};
assign send_val = bypass_in_fifo ? bypass_val : in_fifo_send_val;

SyncFifoNextFull #(
  .p_num_entries(4),
  .p_bit_width(p_bit_width)
) in_fifo (
  .clk(clk),
  .reset(reset),
  .istream_msg(istream_msg),
  .istream_val(istream_val),
  .istream_rdy(istream_rdy),
  .ostream_msg(in_fifo_send_msg),
  .ostream_val(in_fifo_send_val),
  .ostream_rdy(send_rdy & !bypass_in_fifo),
  .next_full(in_fifo_next_full)
);

always_ff @(posedge clk) begin
  if (reset) begin
    bypass_in_fifo <= 1'b1;
    just_sent_imsg <= 1'b0;
    just_sent_imsg_delay <= 1'b0;
  end else if (send_rdy) begin
    if (in_fifo_send_val && recv_msg[p_bit_width] && !just_sent_imsg) begin // send imsg
      bypass_in_fifo <= 1'b0;
      just_sent_imsg_delay <= 1'b1;
    end else begin // send status req (bypass in_q)
      bypass_in_fifo <= 1'b1;
      just_sent_imsg <= 1'b0;
    end
    if (just_sent_imsg_delay) begin
      just_sent_imsg <= 1'b1;
      just_sent_imsg_delay <= 1'b0;
    end
  end
end

always_comb begin
  if (reset) bypass_val = 1'b0;
  else if (send_rdy && !(in_fifo_send_val && recv_msg[p_bit_width] && !just_sent_imsg)) bypass_val = 1'b1;
  else bypass_val = 1'b0;
end

// --------------------------------------------------------------------
// Output fifo and controller
// --------------------------------------------------------------------
SyncFifoNextFull #(
  .p_num_entries(4),
  .p_bit_width(p_bit_width)
) out_fifo (
  .clk(clk),
  .reset(reset),
  .istream_msg(recv_msg[p_bit_width-1:0]),
  .istream_val(recv_val && recv_msg[p_bit_width+1]), // only accept resp msgs with valid data
  .istream_rdy(out_fifo_istream_rdy),
  .ostream_msg(ostream_msg),
  .ostream_val(ostream_val),
  .ostream_rdy(ostream_rdy),
  .next_full(out_fifo_next_full)
);

// We are always ready to receive responses from the DUT since
// the out_fifo's input ready signal is tied to the status request we send
// to the DUT, so it will not send valid responses until the fifo is ready,
// it will only send status responses if the DUT is not ready
always_comb begin
  recv_rdy = 1'b1;
end

endmodule

`endif
