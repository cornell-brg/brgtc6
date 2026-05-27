`ifndef BRGTC6_CRED_RECV
`define BRGTC6_CRED_RECV

`include "asyncfifo/AsyncFifo.sv"
`include "common/Synchronizer.sv"
`include "asyncfifo/BinToGray.sv"
`include "asyncfifo/GrayToBin.sv"

//=========================================================================
// Down Stream Credit Flow Control Unit
//=========================================================================
module CreditRecv #(
    parameter p_bit_width    = 8,
    parameter p_buffer_depth = 8
) (
    input  logic                     clk,
    input  logic                     reset,

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
    .ostream_val(out_val),
    .ostream_rdy(out_rdy)
);

logic [$clog2(p_buffer_depth + 1)-1:0] owed_cred_cnt;
logic owed_cred_ovfl;
logic owed_cred_ovfl_sync;
logic [$clog2(p_buffer_depth + 1)-1:0] sent_cred_cnt;
logic sent_cred_ovfl;

logic [$clog2(p_buffer_depth + 1)-1:0] owed_cred_gray;
logic [$clog2(p_buffer_depth + 1)-1:0] owed_cred_gray_sync;
logic [$clog2(p_buffer_depth + 1)-1:0] owed_cred_sync;

BinToGray #(
    .p_bit_width($clog2(p_buffer_depth + 1))
) owed_cred_cnt_b_to_g (
    .bin(owed_cred_cnt),
    .gray(owed_cred_gray)
);

Synchronizer #(
    .p_bit_width($clog2(p_buffer_depth + 1))
) owed_cred_synchronizer (
    .clk(cred_clk),
    .reset(cred_rst),
    .d(owed_cred_gray),
    .q(owed_cred_gray_sync)
);

Synchronizer #(
    .p_bit_width(1)
) owed_cred_ovfl_synchronizer (
    .clk(cred_clk),
    .reset(cred_rst),
    .d(owed_cred_ovfl),
    .q(owed_cred_ovfl_sync)
);

GrayToBin #(
    .p_bit_width($clog2(p_buffer_depth + 1))
) owed_cred_cnt_g_to_b (
    .gray(owed_cred_gray_sync),
    .bin(owed_cred_sync)
);

always_ff @(posedge clk) begin
    if(reset) begin
        owed_cred_cnt <= 0;
        owed_cred_ovfl <= 0;
    end else if(out_val && out_rdy) begin
        if(owed_cred_cnt <= p_buffer_depth) begin
            owed_cred_cnt <= owed_cred_cnt + 1;
        end else begin
            owed_cred_cnt <= 0;
            owed_cred_ovfl <= ~owed_cred_ovfl;
        end
    end
end

always_ff @(posedge cred_clk) begin
    if(cred_rst) begin
        sent_cred_cnt <= 0;
        sent_cred_ovfl <= 0;
        cred_cred <= 0;
    end else begin
        if(sent_cred_cnt < owed_cred_sync || owed_cred_ovfl_sync != sent_cred_ovfl) begin
            cred_cred <= 1'b1;
            if(sent_cred_cnt <= p_buffer_depth) begin
                sent_cred_cnt <= sent_cred_cnt + 1;
            end else begin
                sent_cred_cnt <= 0;
                sent_cred_ovfl <= ~sent_cred_ovfl;
            end
        end else begin
            cred_cred <= 1'b0;
        end
    end
end

endmodule

`endif /* BRGTC6_CRED_RECV */
