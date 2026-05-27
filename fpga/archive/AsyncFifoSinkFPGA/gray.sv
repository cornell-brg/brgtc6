`ifndef C2C_GRAY
`define C2C_GRAY

//=========================================================================
// Gray Code to Binary Converter
//=========================================================================

module GrayToBin #( parameter bit_width = 3 ) (
    input   logic [bit_width-1:0]   gray,
    output  logic [bit_width-1:0]   bin
);
    genvar i;
    generate
        for(i=0; i < bit_width; i++) begin : l_somehow_quartus_needs_a_flag
            assign bin[i] = ^(gray >> i);
        end
    endgenerate

endmodule

//=========================================================================
// Binary to Gray Code Converter
//=========================================================================

module BinToGray #( parameter bit_width = 3 ) (
    input   logic [bit_width-1:0]   bin,
    output  logic [bit_width-1:0]   gray
);
    assign gray = bin ^ (bin >> 1);
endmodule

`endif /* C2C_GRAY */