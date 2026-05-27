`ifndef BRGTC6_LINK_V3
`define BRGTC6_LINK_V3

`define CHNL_MSG 1'b0
`define CNFG_MSG 1'b1

`include "top-full/v3/Upstream.sv"
`include "top-full/v3/Downstream.sv"
`include "config/ConfigIfc.sv"
`include "spi/minion.v"
`include "spi/router.v"
`include "spi/arbiter.v"

//=========================================================================
// Link V3
//=========================================================================
module Link #(
    parameter p_channel_width     = 8,
    parameter p_config_width      = 8,
    parameter p_max_credit        = 8,
    parameter p_clk_width         = 4,
    parameter p_addr_width        = 4,
    parameter p_resp_buffer_depth = 4,
    parameter p_input_width       = p_addr_width + p_config_width + 1
) (
    input  logic                        clk,
    input  logic                        reset,

    input  logic                        sclk,
    input  logic                        mosi,
    output logic                        miso,
    input  logic                        cs,

    output logic [p_channel_width-1:0]  up_cred_msg,
    output logic                        up_cred_val,
    output logic                        up_cred_clk,
    output logic                        up_cred_rst,
    input  logic                        up_cred_cred,

    input  logic [p_channel_width-1:0]  down_cred_msg,
    input  logic                        down_cred_val,
    input  logic                        down_cred_clk,
    input  logic                        down_cred_rst,
    output logic                        down_cred_cred
);

//=========================================================================
// SPI minion
//=========================================================================

    logic [p_input_width-1:0] spi_recv_msg;
    logic                     spi_recv_rdy;
    logic                     spi_recv_val;

    logic [p_input_width-1:0] spi_send_msg;
    logic                     spi_send_rdy;
    logic                     spi_send_val;

    logic                     minion_parity;
    logic                     adapter_parity;

    spi_Minion #(
        .BIT_WIDTH          (p_input_width),
        .N_SAMPLES          (1)
    ) minion (
        .clk                (clk),
        .reset              (reset),
        .sclk               (sclk),
        .mosi               (mosi),
        .miso               (miso),
        .cs                 (cs),
        .recv_msg           (spi_recv_msg),
        .recv_rdy           (spi_recv_rdy),
        .recv_val           (spi_recv_val),
        .send_msg           (spi_send_msg),
        .send_rdy           (spi_send_rdy),
        .send_val           (spi_send_val),
        .minion_parity      (minion_parity),
        .adapter_parity     (adapter_parity)
    );

//=========================================================================
// Router
//=========================================================================

    logic [p_input_width-1:0]   router_msg[2];
    logic                       router_val[2];
    logic                       router_rdy[2];

    logic [p_channel_width-1:0] upstream_msg;
    logic                       upstream_val;
    logic                       upstream_rdy;

    logic [p_input_width-2:0]   reqstream_msg;
    logic                       reqstream_val;
    logic                       reqstream_rdy;

    Router #(
        .nbits(p_input_width),
        .noutputs(2)
    ) router (
        .clk(clk),
        .reset(reset),
        .istream_val(spi_send_val),
        .istream_msg(spi_send_msg),
        .istream_rdy(spi_send_rdy),
        .ostream_val(router_val),
        .ostream_msg(router_msg),
        .ostream_rdy(router_rdy)
    );

    assign upstream_msg          = router_msg[`CHNL_MSG][p_channel_width-1:0];
    assign upstream_val          = router_val[`CHNL_MSG];
    assign router_rdy[`CHNL_MSG] = upstream_rdy;

    assign reqstream_msg         = router_msg[`CNFG_MSG][p_input_width-2:0];
    assign reqstream_val         = router_val[`CNFG_MSG];
    assign router_rdy[`CNFG_MSG] = reqstream_rdy;

//=========================================================================
// Arbiter
//=========================================================================

    logic [p_input_width-2:0]   arbiter_msg[2];
    logic                       arbiter_val[2];
    logic                       arbiter_rdy[2];

    logic [p_channel_width-1:0] downstream_msg;
    logic                       downstream_val;
    logic                       downstream_rdy;

    logic [p_input_width-2:0]   respstream_msg;
    logic                       respstream_val;
    logic                       respstream_rdy;

    logic [p_input_width-2:0]   padded_downstream_msg;
    assign padded_downstream_msg = 
        {{(p_addr_width + p_config_width - p_channel_width){1'b0}}, downstream_msg};


    Arbiter #(
        .nbits(p_input_width-1),
        .ninputs(2)
    ) arbiter (
        .clk(clk),
        .reset(reset),
        .istream_msg(arbiter_msg),
        .istream_val(arbiter_val),
        .istream_rdy(arbiter_rdy),
        .ostream_msg(spi_recv_msg),
        .ostream_val(spi_recv_val),
        .ostream_rdy(spi_recv_rdy)
    );

    assign arbiter_msg[`CHNL_MSG] = padded_downstream_msg;
    assign arbiter_val[`CHNL_MSG] = downstream_val;
    assign downstream_rdy         = arbiter_rdy[`CHNL_MSG];

    assign arbiter_msg[`CNFG_MSG] = respstream_msg;
    assign arbiter_val[`CNFG_MSG] = respstream_val;
    assign respstream_rdy         = arbiter_rdy[`CNFG_MSG];

//=========================================================================
// Config Interface
//=========================================================================

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
        .p_input_width       (p_input_width-1),
        .p_clk_div_width     (p_clk_width),
        .p_resp_buffer_depth (p_resp_buffer_depth),
        .p_config_width      (p_config_width),
        .p_addr_width        (p_addr_width),
        .p_channel_width     (p_channel_width)
    ) config_ifc ( .* );

//=========================================================================
// Upstream
//=========================================================================

    Upstream #(
        .p_bit_width (p_channel_width),
        .p_max_cred  (p_max_credit),
        .p_clk_width (p_clk_width)
    ) upstream (
        .clk           (clk),
        .reset         (reset | ~cfg_go),
        .bypass        (cfg_pat_bypass),
        .fixed_pattern (cfg_pattern_mode),
        .clk_div       (cfg_clk_div_factor),
        .clk_skew      (cfg_clk_div_skew),
        .istream_msg   (upstream_msg),
        .istream_val   (upstream_val),
        .istream_rdy   (upstream_rdy),
        .pattern_1     (cfg_pattern_1_up),
        .pattern_2     (cfg_pattern_2_up),
        .cred_msg      (up_cred_msg),
        .cred_val      (up_cred_val),
        .cred_clk      (up_cred_clk),
        .cred_rst      (up_cred_rst),
        .cred_cred     (up_cred_cred)
    );

//=========================================================================
// Downstream
//=========================================================================

    Downstream #(
        .p_bit_width    (p_channel_width),
        .p_buffer_depth (p_max_credit)
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

`endif /** BRGTC6_LINK_V3 */
