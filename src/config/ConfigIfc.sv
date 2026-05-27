`ifndef BRGTC6_CONFIG_IFC
`define BRGTC6_CONFIG_IFC

`include "config/config_addr_map.sv"
`include "common/SyncFifo.sv"

//=========================================================================
// Configuration Interface
//=========================================================================
module ConfigIfc #(
    parameter int p_channel_width = 8,
    parameter int p_clk_div_width = 4,
    parameter int p_resp_buffer_depth = 4,
    parameter int p_config_width = 8, // must be >= p_channel_width
    parameter int p_addr_width = 4,
    parameter int p_input_width = p_addr_width + p_config_width
) (
    input  logic clk,
    input  logic reset,

    input  logic [p_input_width-1:0]   reqstream_msg,
    input  logic                       reqstream_val,
    output logic                       reqstream_rdy,

    output logic [p_input_width-1:0]   respstream_msg,
    output logic                       respstream_val,
    input  logic                       respstream_rdy,

    output logic                       cfg_loopback,

    output logic                       cfg_pat_bypass,
    output logic                       cfg_pattern_mode,
    output logic [p_channel_width-1:0] cfg_pattern_1_up,
    output logic [p_channel_width-1:0] cfg_pattern_2_up,
    input  logic [p_channel_width-1:0] cfg_pattern_1_down,
    input  logic [p_channel_width-1:0] cfg_pattern_2_down,

    input  logic [1:0]                 cfg_pattern_state,
    input  logic [4:0]                 cfg_pat_err_count,

    output logic                       cfg_go,
    output logic [p_clk_div_width-1:0] cfg_clk_div_factor,
    output logic [p_clk_div_width-1:0] cfg_clk_div_skew,

    input  logic                       cfg_crc_error,

    output logic [p_channel_width-1:0] cfg_up_rpr_offset,
    output logic [p_channel_width-1:0] cfg_dn_rpr_offset
);

    logic [  p_addr_width-1:0] cfg_addr;

    logic [  p_addr_width-1:0] cfg_addr_reg;
    logic                      cfg_val_reg;

    logic [p_config_width-1:0] cfg_value;
    logic [p_config_width-1:0] cfg_regs [2**p_addr_width-1:0];

    logic [p_input_width-1:0]  enque_msg;
    logic                      enque_val;
    logic                      enque_rdy;

    assign cfg_addr  = reqstream_msg[p_input_width-1:p_config_width];
    assign cfg_value = reqstream_msg[p_config_width-1:0];

    // Queue for configuration responses
    SyncFifo #(
        .p_num_entries(p_resp_buffer_depth),
        .p_bit_width(p_input_width)
    ) cfg_fifo (
        .clk(clk),
        .reset(reset),
        .istream_msg(enque_msg),
        .istream_val(enque_val),
        .istream_rdy(enque_rdy),
        .ostream_msg(respstream_msg),
        .ostream_val(respstream_val),
        .ostream_rdy(respstream_rdy)
    );

    always_ff @(posedge clk) begin
        if(reset) begin
            // Initialize configuration registers to default values
            cfg_regs[int'(`CFG_ADDR_LOOPBACK)]        <= p_config_width'(`CFG_DEF_LOOPBACK);
            cfg_regs[int'(`CFG_ADDR_PAT_BYPASS)]      <= p_config_width'(`CFG_DEF_PAT_BYPASS);
            cfg_regs[int'(`CFG_ADDR_PATTERN_MODE)]    <= p_config_width'(`CFG_DEF_PATTERN_MODE);
            cfg_regs[int'(`CFG_ADDR_PATTERN_1_UP)]    <= p_config_width'(`CFG_DEF_PATTERN_1);
            cfg_regs[int'(`CFG_ADDR_PATTERN_2_UP)]    <= p_config_width'(`CFG_DEF_PATTERN_2);
            cfg_regs[int'(`CFG_ADDR_PATTERN_1_DOWN)]  <= p_config_width'(`CFG_DEF_PATTERN_EMPTY);
            cfg_regs[int'(`CFG_ADDR_PATTERN_2_DOWN)]  <= p_config_width'(`CFG_DEF_PATTERN_EMPTY);
            cfg_regs[int'(`CFG_ADDR_PATTERN_STATE)]   <= p_config_width'(`CFG_DEF_PATTERN_STATE);
            cfg_regs[int'(`CFG_ADDR_PAT_ERR_COUNT)]   <= p_config_width'(`CFG_DEF_PAT_ERR_COUNT);
            cfg_regs[int'(`CFG_ADDR_GO)]              <= p_config_width'(`CFG_DEF_GO);
            cfg_regs[int'(`CFG_ADDR_CLK_DIV_FACTOR)]  <= p_config_width'(`CFG_DEF_CLK_DIV_FACTOR);
            cfg_regs[int'(`CFG_ADDR_CLK_DIV_SKEW)]    <= p_config_width'(`CFG_DEF_CLK_DIV_SKEW);
            cfg_regs[int'(`CFG_ADDR_CRC_ERROR)]       <= p_config_width'(`CFG_DEF_CRC_ERROR);
            cfg_regs[int'(`CFG_ADDR_UP_RPR_OFFSET)]   <= p_config_width'(`CFG_DEF_UP_RPR_OFFSET);
            cfg_regs[int'(`CFG_ADDR_DN_RPR_OFFSET)]   <= p_config_width'(`CFG_DEF_DN_RPR_OFFSET);
            cfg_val_reg                               <= 0;
        end else begin
            // Update read-only configuration registers
            cfg_regs[int'(`CFG_ADDR_PATTERN_1_DOWN)]  <= cfg_pattern_1_down;
            cfg_regs[int'(`CFG_ADDR_PATTERN_2_DOWN)]  <= cfg_pattern_2_down;
            cfg_regs[int'(`CFG_ADDR_PATTERN_STATE)]   <= cfg_pattern_state;
            cfg_regs[int'(`CFG_ADDR_PAT_ERR_COUNT)]   <= cfg_pat_err_count;
            cfg_regs[int'(`CFG_ADDR_CRC_ERROR)]       <= cfg_crc_error;

            cfg_addr_reg <= cfg_addr;
            cfg_val_reg  <= reqstream_val;

            if (reqstream_val && reqstream_rdy) begin
                if (cfg_addr != int'(`CFG_ADDR_PATTERN_1_DOWN)
                    && cfg_addr != int'(`CFG_ADDR_PATTERN_2_DOWN)
                    && cfg_addr != int'(`CFG_ADDR_PATTERN_STATE)
                    && cfg_addr != int'(`CFG_ADDR_PAT_ERR_COUNT)
                    && cfg_addr != int'(`CFG_ADDR_CRC_ERROR)
                ) begin
                    // Update writeable configuration registers
                    cfg_regs[cfg_addr] <= cfg_value;
                end
            end
        end
    end

    assign enque_msg = cfg_regs[cfg_addr_reg] | (cfg_addr_reg << p_config_width);
    assign enque_val = cfg_val_reg;
    assign reqstream_rdy = enque_rdy;

    assign cfg_loopback       = cfg_regs[int'(`CFG_ADDR_LOOPBACK)][0];
    assign cfg_pat_bypass     = cfg_regs[int'(`CFG_ADDR_PAT_BYPASS)][0];
    assign cfg_pattern_mode   = cfg_regs[int'(`CFG_ADDR_PATTERN_MODE)][0];
    assign cfg_pattern_1_up   = cfg_regs[int'(`CFG_ADDR_PATTERN_1_UP)][p_channel_width-1:0];
    assign cfg_pattern_2_up   = cfg_regs[int'(`CFG_ADDR_PATTERN_2_UP)][p_channel_width-1:0];

    assign cfg_go             = cfg_regs[int'(`CFG_ADDR_GO)][0];
    assign cfg_clk_div_factor = cfg_regs[int'(`CFG_ADDR_CLK_DIV_FACTOR)][p_clk_div_width-1:0];
    assign cfg_clk_div_skew   = cfg_regs[int'(`CFG_ADDR_CLK_DIV_SKEW)][p_clk_div_width-1:0];

    assign cfg_up_rpr_offset  = cfg_regs[int'(`CFG_ADDR_UP_RPR_OFFSET)][p_channel_width-1:0];
    assign cfg_dn_rpr_offset  = cfg_regs[int'(`CFG_ADDR_DN_RPR_OFFSET)][p_channel_width-1:0];

endmodule

`endif /* BRGTC6_CONFIG_IFC */
