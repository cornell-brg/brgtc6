`ifndef BRGTC6_CLK_GEN
`define BRGTC6_CLK_GEN

//=========================================================================
// Clock Generator
//=========================================================================
module ClkGen #(
    parameter p_reset_delay = 10,
    parameter p_clk_width = 2
) (
    input  logic clk,
    input  logic reset,

    input  logic [p_clk_width-1:0] clk_div,
    input  logic [p_clk_width-1:0] clk_skew,

    output logic o_clk,
    output logic o_reset,
    output logic en
);

    logic o_clk_div;
    logic [p_clk_width-1:0] cnt;
    logic [$clog2(p_reset_delay)-1:0] delay_cnt;
    logic next_clk;
    logic [p_clk_width-1:0] skew_count;
    logic [p_clk_width-1:0] next_skew_count;

    assign next_skew_count = (o_clk_div && ~next_clk) ? 0 : ((skew_count < clk_div) ? skew_count + 1 : 0);

    assign next_clk = (cnt < (clk_div / 2)) ? 1'b1 : 1'b0;
    assign en = clk_div == 1'd1 ? 1'b1 : (next_skew_count == clk_skew);
    assign o_clk = clk_div == 1'd1 ? ~clk : o_clk_div;

    always_ff @(posedge clk) begin
        if(reset) begin
            o_clk_div <= 0;
            o_reset <= 1;
            cnt <= 0;
            delay_cnt <= 0;
            skew_count <= 1;
        end else begin
            if(cnt >= clk_div - 1) cnt <= 0;
            else cnt <= cnt + 1;

            o_clk_div <= next_clk;

            skew_count <= next_skew_count;
            
            if(delay_cnt >= $unsigned(p_reset_delay - 1)) o_reset <= 0;
            else delay_cnt <= delay_cnt + 1;
        end
    end

endmodule


`endif /* BRGTC6_CLK_GEN */

