`ifndef BRGTC6_LINK_V2
`define BRGTC6_LINK_V2

`include "top-full/v2/Upstream.sv"
`include "top-full/v2/Downstream.sv"
`include "config/ConfigIfc.sv"

//=========================================================================
// Link V2
//=========================================================================
module Link #(
    parameter p_channel_width     = 8,
    parameter p_config_width      = 8,
    parameter p_max_credit        = 8,
    parameter p_clk_width         = 4,
    parameter p_addr_width        = 4,
    parameter p_resp_buffer_depth = 4,
    parameter p_input_width       = p_addr_width + p_config_width
) (
    input  logic                        clk,
    input  logic                        reset,

    input  logic [p_channel_width-1:0]  upstream_msg,
    input  logic                        upstream_val,
    output logic                        upstream_rdy,

    output logic [p_channel_width-1:0]  downstream_msg,
    output logic                        downstream_val,
    input  logic                        downstream_rdy,

    output logic [p_channel_width-1:0]  up_cred_msg,
    output logic                        up_cred_val,
    output logic                        up_cred_clk,
    output logic                        up_cred_rst,
    input  logic                        up_cred_cred,

    input  logic [p_channel_width-1:0]  down_cred_msg,
    input  logic                        down_cred_val,
    input  logic                        down_cred_clk,
    input  logic                        down_cred_rst,
    output logic                        down_cred_cred,

    input  logic [p_input_width-1:0]    reqstream_msg,
    input  logic                        reqstream_val,
    output logic                        reqstream_rdy,

    output logic [p_input_width-1:0]    respstream_msg,
    output logic                        respstream_val,
    input  logic                        respstream_rdy
);

    logic                       cfg_loopback;
    logic                       cfg_pat_bypass;
    logic                       cfg_pattern_mode;
    logic [p_channel_width-1:0] cfg_pattern_1_up;
    logic [p_channel_width-1:0] cfg_pattern_2_up;
    logic [p_channel_width-1:0] cfg_pattern_1_down;
    logic [p_channel_width-1:0] cfg_pattern_2_down;
    logic [1:0]                 cfg_pattern_state;
    logic [4:0]                 cfg_pat_err_count;
    logic                       cfg_go;
    logic [p_clk_width-1:0]     cfg_clk_div_factor;
    logic [p_clk_width-1:0]     cfg_clk_div_skew;
    logic                       cfg_crc_error;
    logic [p_channel_width-1:0] cfg_up_rpr_offset;
    logic [p_channel_width-1:0] cfg_dn_rpr_offset;

    assign cfg_crc_error = 1'b0;

    ConfigIfc #(
        .p_input_width        (p_input_width),
        .p_clk_div_width      (p_clk_width),
        .p_resp_buffer_depth  (p_resp_buffer_depth),
        .p_config_width       (p_config_width),
        .p_addr_width         (p_addr_width),
        .p_channel_width      (p_channel_width)
    ) config_ifc ( .* );

    Upstream #(
        .p_bit_width        (p_channel_width),
        .p_max_cred         (p_max_credit),
        .p_clk_width        (p_clk_width)
    ) upstream (
        .clk                (clk),
        .reset              (reset | ~cfg_go),
        .bypass             (cfg_pat_bypass),
        .fixed_pattern      (cfg_pattern_mode),
        .clk_div            (cfg_clk_div_factor),
        .clk_skew           (cfg_clk_div_skew),
        .istream_msg        (upstream_msg),
        .istream_val        (upstream_val),
        .istream_rdy        (upstream_rdy),
        .pattern_1          (cfg_pattern_1_up),
        .pattern_2          (cfg_pattern_2_up),
        .cred_msg           (up_cred_msg),
        .cred_val           (up_cred_val),
        .cred_clk           (up_cred_clk),
        .cred_rst           (up_cred_rst),
        .cred_cred          (up_cred_cred)
    );

    Downstream #(
        .p_bit_width        (p_channel_width),
        .p_buffer_depth     (p_max_credit)
    ) downstream (
        .clk                (clk),
        .reset              (reset | ~cfg_go),
        .bypass             (cfg_pat_bypass),
        .fixed_pattern      (cfg_pattern_mode),
        .ostream_msg        (downstream_msg),
        .ostream_val        (downstream_val),
        .ostream_rdy        (downstream_rdy),
        .pattern_1          (cfg_pattern_1_down),
        .pattern_2          (cfg_pattern_2_down),
        .state              (cfg_pattern_state),
        .err_count          (cfg_pat_err_count),
        .cred_msg           (down_cred_msg),
        .cred_val           (down_cred_val),
        .cred_clk           (down_cred_clk),
        .cred_rst           (down_cred_rst),
        .cred_cred          (down_cred_cred)
    );

endmodule

`endif /** BRGTC6_LINK_V2 */
