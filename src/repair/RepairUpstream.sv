`ifndef BRGTC6_REPAIR_UPSTREAM
`define BRGTC6_REPAIR_UPSTREAM

//=========================================================================
// Credit Interface Repair Upstream
//=========================================================================
module RepairUpstream #(
  parameter p_bit_width = 8
) (
  
    // input credit interface
    input  logic [p_bit_width-1:0] in_cred_msg,
    input  logic                   in_cred_val,
    input  logic                   in_cred_clk,
    input  logic                   in_cred_rst,
    output logic                   in_cred_cred,
    input  logic                   in_cred_crc,

    // output credit interface
    output logic [p_bit_width-1:0] out_cred_msg,
    output logic                   out_cred_val,
    output logic                   out_cred_clk,
    output logic                   out_cred_rst,
    input  logic                   out_cred_cred,
    output logic                   out_cred_crc,
    output logic                   out_cred_repair,

    // repair select
    input  logic [p_bit_width-1:0] repair_sel // 0: no repair, 1: CRC, 2: Cred, 3: Rst, 4: Clk, 5: Val, 6+: MSG
);

// default passthrough
assign out_cred_msg = in_cred_msg;
assign out_cred_val = in_cred_val;
assign out_cred_clk = in_cred_clk;
assign out_cred_rst = in_cred_rst;
assign in_cred_cred = out_cred_cred;
assign out_cred_crc = in_cred_crc;


// generate repair bit
logic [p_bit_width+4:0] in_credit_concat;
assign in_credit_concat = {in_cred_msg, in_cred_val, in_cred_clk, in_cred_rst, out_cred_cred, in_cred_crc};
assign out_cred_repair = (repair_sel != 0 ? in_credit_concat[repair_sel-1] : 1'b0);

endmodule

`endif /* BRGTC6_REPAIR_UPSTREAM */
