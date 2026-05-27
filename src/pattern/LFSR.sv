`ifndef BRGTC6_LFSR
`define BRGTC6_LFSR

//=========================================================================
// LFSR
//=========================================================================
module LFSR #(
    parameter p_bit_width = 5
) 
(
    input   logic                   clk,
    input   logic                   next,
    input   logic                   reset,
    output  logic [p_bit_width-1:0] out
);

    always_ff @(posedge clk) begin
        if(reset) begin
            out <= {p_bit_width{1'b1}};
        end 
        else begin 
            if(next) begin
                out <= {out[p_bit_width-2:0], out[p_bit_width-1] ^ out[p_bit_width-2]};
            end
        end
    end
     
endmodule

`endif /* BRGTC6_LFSR */
