`ifndef BRGTC6_WRITE_PTR_BLK_NO_FULL
`define BRGTC6_WRITE_PTR_BLK_NO_FULL

`include "common/Synchronizer.sv"
`include "asyncfifo/BinToGray.sv"
`include "asyncfifo/ResetSync.sv"

//=========================================================================
// Write Pointer Handler Block with Full Signal
//=========================================================================
module WritePtrBlkNoFull #(
    parameter p_num_entries = 8,
    parameter p_ptr_width = $clog2(p_num_entries) + 1 // Extra bit for wrap around
)
(
    input   logic                     clk,
    input   logic                     async_rst,

    output  logic [p_ptr_width-1:0]   b_write_ptr,
    output  logic [p_ptr_width-1:0]   g_write_ptr,
    input   logic                     w_en
);

    logic reset; // synchonized async reset

    ResetSync reset_sync (
        .clk(clk),
        .async_rst(async_rst),
        .reset(reset)
    );

    logic [p_ptr_width-1:0] b_write_ptr_next;
    logic [p_ptr_width-1:0] g_write_ptr_next;

    assign b_write_ptr_next = b_write_ptr + {{(p_ptr_width-1){1'b0}},(w_en)};

    BinToGray #(
        .p_bit_width(p_ptr_width)
    ) bin_to_gray (
        .bin(b_write_ptr_next),
        .gray(g_write_ptr_next)
    );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            b_write_ptr <= 0;
            g_write_ptr <= 0;
        end else begin
            b_write_ptr <= b_write_ptr_next;
            g_write_ptr <= g_write_ptr_next;
        end
    end
endmodule

`endif /* BRGTC6_WRITE_PTR_BLK_NO_FULL */
