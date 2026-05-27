`ifndef C2C_MEM_1R1W_SV
`define C2C_MEM_1R1W_SV

//=========================================================================
// Mem with 1r1w
//=========================================================================

module Mem_1r1w #(
    parameter num_entries = 8,
    parameter bit_width = 5,
    parameter addr_width = $clog2(num_entries)
)
(
    input   logic                   clk,
    input   logic                   write_en,
    input   logic [addr_width-1:0]  write_addr,
    input   logic [ bit_width-1:0]  write_data,
    input   logic                   read_en,
    input   logic [addr_width-1:0]  read_addr,
    output  logic [ bit_width-1:0]  read_data
);

    logic [bit_width-1:0] mem [num_entries-1:0];

    always_ff @(posedge clk) begin
        if (write_en) begin // write data to mem
            mem[write_addr] <= write_data;
        end
    end

    assign read_data = mem[read_addr] & {bit_width{read_en}};

endmodule

`endif /* C2C_MEM_1R1W_SV */