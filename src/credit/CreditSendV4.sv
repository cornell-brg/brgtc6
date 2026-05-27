`ifndef BRGTC6_CREDIT_SEND_V4
`define BRGTC6_CREDIT_SEND_V4

`include "credit/ClkGen.sv"
`include "common/Synchronizer.sv"
`include "asyncfifo/AsyncCounter.sv"

//=========================================================================
// Upstream Credit Flow Control Unit
//=========================================================================
module CreditSendV4 #(
    parameter p_bit_width  = 8,
    parameter p_max_credit = 8,
    parameter p_clk_width  = 6
) (
    input  logic                     clk,
    input  logic                     reset,

    // Config data and debug outputs
    input  logic [p_clk_width-1:0]   clk_div,
    input  logic [p_clk_width-1:0]   clk_skew,
    output logic [$clog2(p_max_credit+1)-1:0] dbg_next_cred_cnt,
    output logic [1:0]               cred_rst_delay,

    // Input val/rdy interface
    input  logic [p_bit_width-1:0]   in_msg,
    input  logic                     in_val,
    output logic                     in_rdy,

    // Output credit interface
    output logic [p_bit_width-1:0]   cred_msg,
    output logic                     cred_val,
    output logic                     cred_clk,
    output logic                     cred_rst,
    input  logic                     cred_cred
);

logic clk_en;
logic o_reset;

ClkGen #(
    .p_clk_width(p_clk_width)
) clkgen (
    .clk(clk),
    .reset(reset),
    .clk_div(clk_div),
    .clk_skew(clk_skew),
    .o_clk(cred_clk),
    .o_reset(o_reset),
    .en(clk_en)
);

assign cred_rst = reset | o_reset;

logic [$clog2(p_max_credit + 1)-1:0] used_cred_cnt;
logic [$clog2(p_max_credit + 1)-1:0] next_cred_count;
logic returned_credit;

AsyncCounter #(
    .p_num_entries(p_max_credit + 1)
) counter (
    .i_clk(cred_cred),
    .o_clk(cred_clk),
    .async_rst(cred_rst),
    .ostream_val(returned_credit),
    .ostream_rdy(1'b1)
);

assign next_cred_count = $unsigned(used_cred_cnt) - $unsigned(returned_credit ? 2 : 0) + $unsigned(in_val && in_rdy);

always_ff @(posedge clk) begin
    if(reset) begin
        cred_msg <= 0;
        cred_val <= 0;
        used_cred_cnt <= 0;
        dbg_next_cred_cnt <= 0;
        cred_rst_delay <= 0;
    end else begin
        if (clk_en) begin
            if(cred_rst_delay < 3 && !cred_rst) begin
                cred_rst_delay <= cred_rst_delay + 1;
            end
            used_cred_cnt <= next_cred_count;
            if(in_rdy) begin
                cred_msg <= in_msg;
                cred_val <= in_val;
            end else begin
                cred_msg <= 0;
                cred_val <= 0;
            end
        end
    end
    dbg_next_cred_cnt <= next_cred_count;
end

assign in_rdy = (used_cred_cnt < p_max_credit) && clk_en && cred_rst_delay == 3;

endmodule

`endif /* BRGTC6_CREDIT_SEND_V4 */
