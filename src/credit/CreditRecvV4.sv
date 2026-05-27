`ifndef BRGTC6_CRED_RECV_V4
`define BRGTC6_CRED_RECV_V4

`include "asyncfifo/AsyncFifo.sv"

//=========================================================================
// Down Stream Credit Flow Control Unit
//=========================================================================
module CreditRecvV4 #(
    parameter p_bit_width    = 8,
    parameter p_buffer_depth = 8
) (
    input  logic                     clk,
    input  logic                     reset,

    // Config debug outputs
    output logic [2:0]               tick_cnt,

    // Input val/rdy interface
    output logic [p_bit_width-1:0]   out_msg,
    output logic                     out_val,
    input  logic                     out_rdy,

    // Output credit interface
    input  logic [p_bit_width-1:0]   cred_msg,
    input  logic                     cred_val,
    input  logic                     cred_clk,
    input  logic                     cred_rst,
    output logic                     cred_cred
);

logic fifo_out_val, fifo_out_rdy;

AsyncFifo #(
    .p_num_entries(p_buffer_depth),
    .p_bit_width(p_bit_width)
) fifo (
    .i_clk(cred_clk),
    .async_rst(cred_rst),
    .o_clk(clk),
    .istream_msg(cred_msg),
    .istream_val(cred_val),
    // verilator lint_off PINCONNECTEMPTY
    .istream_rdy(),
    // verilator lint_on PINCONNECTEMPTY
    .ostream_msg(out_msg),
    .ostream_val(fifo_out_val),
    .ostream_rdy(fifo_out_rdy)
);

assign fifo_out_rdy = out_rdy && (tick_cnt == 3'd4);
assign out_val = fifo_out_val && (tick_cnt == 3'd4);

always_ff @(posedge clk) begin
    if(reset) begin
        cred_cred <= 1'b1;
        tick_cnt <= 3'b0;
    end else if (tick_cnt < 4) begin
        tick_cnt <= tick_cnt + 1;
        cred_cred <= ~cred_cred;
    end else if(out_val && out_rdy) begin
        cred_cred <= ~cred_cred;
    end
end

endmodule

`endif /* BRGTC6_CRED_RECV_V4 */
