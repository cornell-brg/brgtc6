`ifndef BRGTC6_ASYNC_COUNTER
`define BRGTC6_ASYNC_COUNTER

`include "asyncfifo/WritePtrBlkNoFull.sv"
`include "asyncfifo/ReadPtrBlk.sv"

//=========================================================================
// Asynchronous Counter Implementation
//=========================================================================
module AsyncCounter #(
    parameter p_num_entries = 8
)
(
    input   logic                     i_clk,
    input   logic                     o_clk,
    input   logic                     async_rst,

    output  logic                     ostream_val,
    input   logic                     ostream_rdy
);

    localparam ptr_width = $clog2(p_num_entries) + 1;

    logic empty;
    logic [ptr_width-1:0] g_write_ptr;
    logic [ptr_width-1:0] g_read_ptr;

    // verilator lint_off UNUSED
    logic [ptr_width-1:0] b_write_ptr;
    logic [ptr_width-1:0] b_read_ptr;
    // verilator lint_on UNUSED

    WritePtrBlkNoFull #(
        .p_num_entries(p_num_entries)
    ) write_ptr (
        .clk(i_clk),
        .async_rst(async_rst),
        .w_en(1'b1),
        .*
    );

    ReadPtrBlk #(
        .p_num_entries(p_num_entries)
    ) read_ptr (
        .g_write_ptr_async(g_write_ptr),
        .clk(o_clk),
        .async_rst(async_rst),
        .r_en(ostream_rdy && ostream_val),
        .*
    );

    assign ostream_val = !empty;

endmodule

`endif /* BRGTC6_ASYNC_COUNTER */
