`ifndef BRGTC6_PATTERN_CHK_BYPASS
`define BRGTC6_PATTERN_CHK_BYPASS

`include "pattern/LFSR.sv"

`define PATTERN_CHK_IDLE  2'b00     // Pattern Checker is IDLE
`define PATTERN_CHK_CLBT  2'b01     // Pattern Checker is Calibrating
`define PATTERN_CHK_LOCK  2'b10     // Pattern Checker is Locked
`define PATTERN_CHK_ERR   2'b11     // Pattern Checker has Error

//=========================================================================
// Pattern Checker
//=========================================================================
module PatternChkBypass #(
    parameter p_bit_width = 5
) (
    input   logic                   clk,
    input   logic                   reset,

    input   logic                   bypass,         // whether input is directly forwarded to output
    input   logic                   fixed_pattern,  // whether to use fixed patterns
    
    input   logic [p_bit_width-1:0] istream_msg,
    input   logic                   istream_val,
    output  logic                   istream_rdy,

    output  logic [p_bit_width-1:0] pattern_1,
    output  logic [p_bit_width-1:0] pattern_2,

    output  logic [1:0]             state,
    output  logic [4:0]             err_count,

    output  logic                   ostream_val,
    output  logic [p_bit_width-1:0] ostream_msg,
    input   logic                   ostream_rdy
);

    logic lfsr_val;
    assign lfsr_val = istream_val && !bypass && !fixed_pattern;
    logic [p_bit_width-1:0] lfsr_out;

    logic [p_bit_width-1:0] expected;
    logic fixed_pattern_idx;
    assign expected = fixed_pattern ? (fixed_pattern_idx ? pattern_2 : pattern_1) : lfsr_out;

    assign istream_rdy = reset ? 1'b0 : (bypass ? ostream_rdy : 1'b1);
    assign ostream_msg = istream_msg;
    assign ostream_val = reset ? 1'b0 : (bypass ? istream_val : 1'b0);

    LFSR #(
        .p_bit_width(p_bit_width)
    ) lfsr (
        .clk(clk),
        .next(lfsr_val && (istream_msg == lfsr_out)),
        .reset(reset),
        .out(lfsr_out)
    );

    logic [p_bit_width-1:0] counter;

    always_ff @(posedge clk) begin
        if(reset) begin
            counter <= 0;
            err_count <= 0;
            state <= `PATTERN_CHK_IDLE;
            fixed_pattern_idx <= 0;
            pattern_1 <= 0;
            pattern_2 <= 0;
        end else if (!bypass) begin
            if(fixed_pattern && istream_val) begin
                if(fixed_pattern_idx) begin
                    pattern_2 <= istream_msg;
                end else begin
                    pattern_1 <= istream_msg;
                end
                fixed_pattern_idx <= ~fixed_pattern_idx;
            end
            if(state == `PATTERN_CHK_IDLE && istream_val) begin
                state <= `PATTERN_CHK_CLBT;
                counter <= (istream_msg == expected) ? 1'b1 : 1'b0;
            end 
            else if(state == `PATTERN_CHK_CLBT && istream_val) begin
                counter <= (istream_msg == expected) ? (counter + 1'b1) : 1'b0;
                if(counter == {p_bit_width{1'b1}}) begin
                    state <= `PATTERN_CHK_LOCK;
                end
            end 
            else if(state >= `PATTERN_CHK_LOCK && istream_val) begin
                if(istream_msg != expected) begin
                    err_count <= err_count + 1'b1;
                    state <= `PATTERN_CHK_ERR;
                end
            end
        end
    end

endmodule

`endif /* BRGTC6_PATTERN_CHK_BYPASS */
