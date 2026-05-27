`include "Hex5.sv"
`include "AsyncFifo.sv"

module clock_divider(
    input wire clk_in,
    input wire reset,
    output reg clk_out
);

parameter COUNTER_MAX = 3;
reg [2:0] counter = 0;

always @(posedge clk_in or posedge reset) begin
    if (reset) begin
        counter <= 0;
        clk_out <= 0;
    end else begin
        counter <= counter + 1;
        if (counter >= COUNTER_MAX) begin
            clk_out <= ~clk_out;
            counter <= 0;
        end
    end
end

endmodule


module AsyncFifoFPGA (
    input logic i_clk,
    input logic i_reset_n,
    input logic o_reset_n,
    input logic enque_btn,
    input logic deque_btn,
    input logic [4:0] istream_msg,
    output logic [6:0] in_seg_1,
    output logic [6:0] in_seg_2,
    output logic [6:0] out_seg_1,
    output logic [6:0] out_seg_2,
    output logic istream_rdy,
    output logic ostream_val
);

// Debounce buttons
logic [19:0] db_reg_1; 
logic sb_1;      

logic [19:0] db_reg_2;
logic sb_2;

logic i_reset, o_reset;
logic o_clk;

assign i_reset = ~i_reset_n;
assign o_reset = ~o_reset_n;

clock_divider clk_div (
    .clk_in(i_clk),
    .reset(i_reset),
    .clk_out(o_clk)
);

always @(posedge i_clk) begin
    if (i_reset) begin
        db_reg_1 <= 0;
        db_reg_2 <= 0;
    end else begin
        db_reg_1 <= {db_reg_1[18:0], enque_btn};
        db_reg_2 <= {db_reg_2[18:0], deque_btn};
    end
end

assign sb_1 = (db_reg_1 == 20'b11111111111111111111) ? 1'b1 :
                       (db_reg_1 == 20'b00000000000000000000) ? 1'b0 : sb_1;
assign sb_2 = (db_reg_2 == 20'b11111111111111111111) ? 1'b1 :
                       (db_reg_2 == 20'b00000000000000000000) ? 1'b0 : sb_2;
                              

reg last_sb_1, last_sb_2;

logic istream_val;
logic ostream_rdy;

logic [4:0] ostream_msg;
logic [4:0] cache_ostream;

Hex5 inp (
    .q(istream_msg),
    .seg_1(in_seg_1),
    .seg_2(in_seg_2)
);

Hex5 out (
    .q(cache_ostream),
    .seg_1(out_seg_1),
    .seg_2(out_seg_2)
);

AsyncFifo #(
    .num_entries(8),
    .bit_width(5)
  ) async_fifo (
    .i_clk(i_clk),
    .o_clk(o_clk),
    .i_reset(i_reset),
    .o_reset(o_reset),
    .istream_msg(istream_msg),
    .istream_val(istream_val),
    .istream_rdy(istream_rdy),
    .ostream_msg(ostream_msg),
    .ostream_val(ostream_val),
    .ostream_rdy(ostream_rdy)
);

always @(posedge i_clk) begin
    if(i_reset) begin
        last_sb_1 <= 0;
    end else begin
        last_sb_1 <= sb_1;
    end
end

always @(posedge o_clk) begin
    if(i_reset) begin
      cache_ostream <= 0;
        last_sb_2 <= 0;
    end else begin
        last_sb_2 <= sb_2;
        if (ostream_rdy && ostream_val) begin
            cache_ostream <= ostream_msg;
        end
    end
end

always_comb begin
    istream_val = sb_1 == 1'b0 && last_sb_1 == 1'b1;
    ostream_rdy = sb_2 == 1'b0 && last_sb_2 == 1'b1;
end

endmodule