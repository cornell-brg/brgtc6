`ifndef C2C_PATTERN
`define C2C_PATTERN

`include "lfsr.sv"

`define PATTERN_CHK_IDLE  2'b00     // Pattern Checker is IDLE
`define PATTERN_CHK_CLBT  2'b01     // Pattern Checker is Calibrating
`define PATTERN_CHK_LOCK  2'b10     // Pattern CHecker is Locked
`define PATTERN_CHK_ERR   2'b11     // Pattern Checker has detected an error

module PatternGen #(
    parameter bit_width = 5
) (
    input   logic                   clk,
    input   logic                   reset,
    output  logic                   ostream_val,
    output  logic [bit_width-1:0]   ostream_msg,
    input   logic                   ostream_rdy
);

    LFSR #(
        .bit_width(bit_width)
    ) lfsr (
        .clk(clk),
        .next(ostream_val && ostream_rdy),
        .reset(reset),
        .out(ostream_msg)
    );

    assign ostream_val = 1'b1;

endmodule

module PatternChk #(
    parameter bit_width = 5
) (
    input   logic                   clk,
    input   logic                   reset,
    input   logic [bit_width-1:0]   istream_msg,
    input   logic                   istream_val,
    output  logic                   istream_rdy,
    output  logic [1:0]             state
);

    logic [bit_width-1:0] lfsr_out;

    LFSR #(
        .bit_width(bit_width)
    ) lfsr (
        .clk(clk),
        .next(istream_val && (istream_msg == lfsr_out)),
        .reset(reset),
        .out(lfsr_out)
    );

    assign istream_rdy = 1'b1;

    logic [bit_width-1:0] counter;

    always_ff @(posedge clk) begin
        if(reset) begin
            counter <= 0;
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
            else if(state == `PATTERN_CHK_LOCK && istream_val) begin
                if(istream_msg != lfsr_out) begin
                    state <= `PATTERN_CHK_ERR;
                end
            end
        end
    end

endmodule

`endif /* C2C_PATTERN */