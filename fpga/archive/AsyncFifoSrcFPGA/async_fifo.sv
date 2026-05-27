`ifndef C2C_ASYNC_FIFO
`define C2C_ASYNC_FIFO

//=========================================================================
// Asynchronous FIFO Implementation
//=========================================================================
// Asynchronous FIFO with val/rdy interface
// interface:
//
// i_clk    : input clock
// o_clk    : output clock
// reset : reset signal
// istream : input stream
// ostream : output stream

`include "mem_1r1w.sv"
`include "gray.sv"
`include "synch.sv"


module AsyncFifo #(
    parameter num_entries = 8, 
    parameter bit_width = 5
)
(
    input   logic                   i_clk,
    input   logic                   o_clk,
    input   logic                   i_reset,
    input   logic                   o_reset,

    input   logic [bit_width-1:0]   istream_msg,
    input   logic                   istream_val,
    output  logic                   istream_rdy,

    output  logic [bit_width-1:0]   ostream_msg,
    output  logic                   ostream_val,
    input   logic                   ostream_rdy
);

    localparam ptr_width = $clog2(num_entries) + 1;

    logic full, empty;
    logic [ptr_width-1:0] g_write_ptr;
    logic [ptr_width-1:0] g_read_ptr;
    logic [ptr_width-1:0] b_write_ptr;
    logic [ptr_width-1:0] b_read_ptr;
    
    Mem_1r1w #(
        .num_entries(num_entries),
        .bit_width(bit_width)
    ) mem (
        .clk(i_clk),
        .write_en(istream_val && !full),
        .write_addr(b_write_ptr[ptr_width-2:0]),
        .write_data(istream_msg),
        .read_en(ostream_rdy && !empty),
        .read_addr(b_read_ptr[ptr_width-2:0]),
        .read_data(ostream_msg)
    );

    WritePtrBlk #(
        .num_entries(num_entries)
    ) write_ptr (
        .g_read_ptr_async(g_read_ptr),
        .clk(i_clk),
        .reset(i_reset),
        .w_en(istream_val && istream_rdy),
        .*
    );

    ReadPtrBlk #(
        .num_entries(num_entries)
    ) read_ptr (
        .g_write_ptr_async(g_write_ptr),
        .clk(o_clk),
        .reset(o_reset),
        .r_en(ostream_rdy && ostream_val),
        .*
    );

    assign istream_rdy = !full;
    assign ostream_val = !empty;

endmodule


//=========================================================================
// Write Pointer Handler Block
//=========================================================================
module WritePtrBlk #(
    parameter num_entries = 8,
    parameter ptr_width = $clog2(num_entries) + 1 // Extra bit for wrap around
)
(
    input   logic                   clk,
    input   logic                   reset,

    output  logic [ptr_width-1:0]   b_write_ptr,
    output  logic [ptr_width-1:0]   g_write_ptr,

    input   logic [ptr_width-1:0]   g_read_ptr_async,
    input   logic                   w_en,
    output  logic                   full
);

    logic [ptr_width-1:0] g_read_ptr; // Synchronized read pointer

    Synch #(.bit_width(ptr_width)) synch ( // Synchronizer
        .clk(clk),
        .reset(reset),
        .q(g_read_ptr_async),
        .d(g_read_ptr)
    );

    logic [ptr_width-1:0] b_write_ptr_next;
    logic [ptr_width-1:0] g_write_ptr_next;

    assign b_write_ptr_next = b_write_ptr + {{(ptr_width-1){1'b0}},(w_en && !full)}; 
    
    BinToGray #(.bit_width(ptr_width)) bin_to_gray (
        .bin(b_write_ptr_next),
        .gray(g_write_ptr_next)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            b_write_ptr <= 0;
            g_write_ptr <= 0;
        end else begin
            b_write_ptr <= b_write_ptr_next;
            g_write_ptr <= g_write_ptr_next;
        end 
    end
    
    assign full = (g_write_ptr[ptr_width-1:ptr_width-2] == ~g_read_ptr[ptr_width-1:ptr_width-2])
                && (g_write_ptr[ptr_width-3:0] == g_read_ptr[ptr_width-3:0]);
endmodule



//=========================================================================
// Read Pointer Handler Block
//=========================================================================
module ReadPtrBlk #(
    parameter num_entries = 8,
    parameter ptr_width = $clog2(num_entries) + 1 // Extra bit for wrap around
)
(
    input   logic                   clk,
    input   logic                   reset,

    output  logic [ptr_width-1:0]   b_read_ptr,
    output  logic [ptr_width-1:0]   g_read_ptr,

    input   logic [ptr_width-1:0]   g_write_ptr_async,
    input   logic                   r_en,
    output  logic                   empty
);

    logic [ptr_width-1:0] g_write_ptr; // Synchronized write pointer

    Synch #(.bit_width(ptr_width)) synch ( // Synchronizer
        .clk(clk),
        .reset(reset),
        .q(g_write_ptr_async),
        .d(g_write_ptr)
    );

    logic [ptr_width-1:0] b_read_ptr_next;
    logic [ptr_width-1:0] g_read_ptr_next;

    assign b_read_ptr_next = b_read_ptr + {{(ptr_width-1){1'b0}},(r_en && !empty)};

    BinToGray #(.bit_width(ptr_width)) bin_to_gray (
        .bin(b_read_ptr_next),
        .gray(g_read_ptr_next)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            b_read_ptr <= 0;
            g_read_ptr <= 0;
        end else begin
            b_read_ptr <= b_read_ptr_next;
            g_read_ptr <= g_read_ptr_next;
        end 
    end

    assign empty = (g_read_ptr == g_write_ptr);
endmodule

`endif /* C2C_ASYNC_FIFO */