`ifndef C2C_SYNCH
`define C2C_SYNCH

//=========================================================================
// Synchronizer
//=========================================================================
// Standard synchronizer module with two chained flip-flops
// 
//  !!! IMPORTANT: For bit_width > 1, the data needs to be gray coded.

module Synch #( parameter bit_width = 3 )(
    input   logic                   clk,
    input   logic                   reset,
    input   logic [bit_width-1:0]   q,
    output  logic [bit_width-1:0]   d
);

    logic [bit_width-1:0] s;

    always_ff @(posedge clk) begin
        if (reset) begin
            s <= 0;
            d <= 0;
        end else begin
            s <= q;
            d <= s;
        end
    end

endmodule

`endif /* C2C_SYNCH */