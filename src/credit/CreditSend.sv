`ifndef BRGTC6_CREDIT_SEND
`define BRGTC6_CREDIT_SEND

`include "credit/ClkGen.sv"
`include "common/Synchronizer.sv"

//=========================================================================
// Upstream Credit Flow Control Unit
//=========================================================================
module CreditSend #(
    parameter p_bit_width = 8,
    parameter p_max_cred  = 8,
    parameter p_clk_width = 6
) (
    input  logic                     clk,
    input  logic                     reset,

    input  logic [p_clk_width-1:0]   clk_div,
    input  logic [p_clk_width-1:0]   clk_skew,

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

logic [1:0] cred_rst_delay;
logic [$clog2(p_max_cred + 1)-1:0] used_cred_cnt;
logic [$clog2(p_max_cred + 1)-1:0] next_cred_count;
logic sync_cred;

assign next_cred_count = used_cred_cnt - (sync_cred ? 1 : 0) + (in_val && in_rdy);

Synchronizer #(
    .p_bit_width(1)
) synch (
    .clk(clk),
    .reset(reset),
    .d(cred_cred),
    .q(sync_cred)
);

always_ff @(posedge clk) begin
    if(reset) begin
        cred_msg <= 0;
        cred_val <= 0;
        used_cred_cnt <= 0;
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
end

assign in_rdy = (used_cred_cnt < p_max_cred) && clk_en && cred_rst_delay == 3;

endmodule

`endif /* BRGTC6_CREDIT_SEND */
