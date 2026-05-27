`ifndef BRGTC6_CONFIG_SHREG
`define BRGTC6_CONFIG_SHREG

//----------------------------------------------------------------------
// SkewShreg
//----------------------------------------------------------------------
/*verilator coverage_off*/
module SkewShreg #(
  int p_max_stages = 8  
) (
  input  logic        clk,
  input  logic        data_in,
  input  logic        en,
  input  logic [31:0] stage_num,
  output logic        data_out
);

logic [p_max_stages-1:0] shreg;
logic [p_max_stages-1:0] neg_sync_out;

// Async reset
always_ff @(posedge clk) begin
  if (en) shreg <= {shreg[p_max_stages-2:0], data_in};
end

always_ff @(negedge clk) begin
  if (en) neg_sync_out <= shreg;
end

assign data_out = stage_num == 0 ? data_in : logic'((neg_sync_out & (1 << (stage_num-1))) >> (stage_num-1));

endmodule
/*verilator coverage_on*/

`endif 
