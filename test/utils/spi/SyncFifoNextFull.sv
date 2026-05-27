`ifndef BRGTC6_SYNC_FIFO_NEXT_FULL
`define BRGTC6_SYNC_FIFO_NEXT_FULL

`include "common/Mem1r1w.sv"

//=========================================================================
// Synchronous FIFO Implementation
//=========================================================================
// Synchronous FIFO with val/rdy interface
// interface:
//
// clk     : clock
// reset   : reset signal
// istream : input stream
// ostream : output stream

module SyncFifoNextFull #(
    parameter p_num_entries = 8, 
    parameter p_bit_width   = 8
) (
    input   logic                   clk,
    input   logic                   reset,

    input   logic [p_bit_width-1:0] istream_msg,
    input   logic                   istream_val,
    output  logic                   istream_rdy,

    output  logic [p_bit_width-1:0] ostream_msg,
    output  logic                   ostream_val,
    input   logic                   ostream_rdy,

    output  logic                   next_full
);

localparam ptr_width = $clog2(p_num_entries);
logic full, empty;

logic [ptr_width-1:0] w_ptr, r_ptr;

Mem1r1w #(
    .p_num_entries(p_num_entries),
    .p_bit_width(p_bit_width)
) mem1r1w (
    .clk(clk),
    .reset(reset),
    .write_en(istream_val && !full),
    .write_addr(w_ptr),
    .write_data(istream_msg),
    .read_en(!empty),
    .read_addr(r_ptr),
    .read_data(ostream_msg)
);

assign istream_rdy = !full;
assign ostream_val = !empty;

assign full = ((w_ptr + 1'b1) == r_ptr);
assign next_full = ((w_ptr + 2'd2) == r_ptr);
assign empty = (w_ptr == r_ptr);

always_ff @(posedge clk) begin
    if(reset) begin
        w_ptr <= 0;
        r_ptr <= 0;
    end else begin
        if(istream_val && !full) begin
            w_ptr <= w_ptr + 1;
        end
        if(ostream_rdy && !empty) begin
            r_ptr <= r_ptr + 1;
        end
    end
end

endmodule

`endif /* BRGTC6_SYNC_FIFO_NEXT_FULL */

