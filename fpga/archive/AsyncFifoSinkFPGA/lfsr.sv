`ifndef C2C_LFSR
`define C2C_LFSR

module LFSR #(
    parameter bit_width = 5
) 
(
    input   logic                   clk,
    input   logic                   next,
    input   logic                   reset,
    output  logic [bit_width-1:0]   out
);

    always_ff @(posedge clk) begin
        if(reset) begin
            out <= {bit_width{1'b1}};
        end 
        else begin 
            if(next) begin
                out <= {out[bit_width-2:0], out[bit_width-1] ^ out[bit_width-2]};
            end
        end
    end
    
endmodule

`endif /* C2C_LFSR */