`ifndef BRGTC6_PATTERN_CHK
`define BRGTC6_PATTERN_CHK

`include "pattern/LFSR.sv"

`define PATTERN_CHK_IDLE  2'b00     // Pattern Checker is IDLE
`define PATTERN_CHK_CLBT  2'b01     // Pattern Checker is Calibrating
`define PATTERN_CHK_LOCK  2'b10     // Pattern Checker is Locked
`define PATTERN_CHK_ERR   2'b11     // Pattern Checker has Error

//=========================================================================
// Pattern Checker
//=========================================================================
module PatternChk #(
    parameter bit_width = 5
) (
    input   logic                   clk,
    input   logic                   reset,
    input   logic [bit_width-1:0]   istream_msg,
    input   logic                   istream_val,
    output  logic [1:0]             state,
    output  logic [4:0]             err_count
);

    logic [bit_width-1:0] lfsr_out;

    LFSR #(
        .p_bit_width(bit_width)
    ) lfsr (
        .clk(clk),
        .next(istream_val && (istream_msg == lfsr_out)),
        .reset(reset),
        .out(lfsr_out)
    );

    logic [bit_width-1:0] counter;

    always_ff @(posedge clk) begin
        if(reset) begin
            counter <= 0;
            err_count <= 0;
            state <= `PATTERN_CHK_IDLE;
        end else begin
            if(state == `PATTERN_CHK_IDLE && istream_val) begin
                state <= `PATTERN_CHK_CLBT;
                counter <= (istream_msg == lfsr_out) ? 1'b1 : 1'b0;
            end 
            else if(state == `PATTERN_CHK_CLBT && istream_val) begin
                counter <= (istream_msg == lfsr_out) ? (counter + 1'b1) : 1'b0;
                if(counter == {bit_width{1'b1}}) begin
                    state <= `PATTERN_CHK_LOCK;
                end
            end 
            else if(state >= `PATTERN_CHK_LOCK && istream_val) begin
                if(istream_msg != lfsr_out) begin
                    err_count <= err_count + 1'b1;
                    state <= `PATTERN_CHK_ERR;
                end
            end
        end
    end

endmodule

`endif /* BRGTC6_PATTERN_CHK */
