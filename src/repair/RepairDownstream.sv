`ifndef BRGTC6_REPAIR_DOWNSTREAM
`define BRGTC6_REPAIR_DOWNSTREAM

//=========================================================================
// Credit Interface Repair Downstream
//=========================================================================
module RepairDownstream #(
  parameter p_bit_width = 8
) (
  
    // input credit interface
    input  logic [p_bit_width-1:0] in_cred_msg,
    input  logic                   in_cred_val,
    input  logic                   in_cred_clk,
    input  logic                   in_cred_rst,
    output logic                   in_cred_cred,
    input  logic                   in_cred_crc,
    input  logic                   in_cred_repair,

    // output credit interface
    output logic [p_bit_width-1:0] out_cred_msg,
    output logic                   out_cred_val,
    output logic                   out_cred_clk,
    output logic                   out_cred_rst,
    input  logic                   out_cred_cred,
    output logic                   out_cred_crc,

    // repair select
    input  logic [p_bit_width-1:0] repair_sel // 0: no repair, 1: CRC, 2: Cred, 3: Rst, 4: Clk, 5: Val, 6+: MSG
);


// concatenate all bits on input credit interface
logic [p_bit_width+4:0] in_credit_concat;
assign in_credit_concat = {in_cred_msg, in_cred_val, in_cred_clk, in_cred_rst, out_cred_cred, in_cred_crc};

// interlace repair bit into credit interface and split out into output credit interface
logic [p_bit_width+4:0] repaired_credit_concat;

always_comb begin
  if(repair_sel != {p_bit_width{1'b0}})
    repaired_credit_concat = (in_credit_concat & ~($unsigned(1) << (repair_sel-1))) | (in_cred_repair << (repair_sel-1));
  else repaired_credit_concat = in_credit_concat;
  out_cred_msg = repaired_credit_concat[p_bit_width+4:5];
  out_cred_val = repaired_credit_concat[4];
  out_cred_clk = repaired_credit_concat[3];
  out_cred_rst = repaired_credit_concat[2];
  in_cred_cred = repaired_credit_concat[1];
  out_cred_crc = repaired_credit_concat[0];
end

endmodule

`endif /* BRGTC6_REPAIR_DOWNSTREAM */
