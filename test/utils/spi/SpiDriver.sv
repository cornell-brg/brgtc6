`ifndef BRGTC6_SPI_DRIVER
`define BRGTC6_SPI_DRIVER

`define CORE_CLK_FSM_WAIT_FOR_RDY 2'd0
`define CORE_CLK_FSM_IDLE 2'd1
`define CORE_OUTPUT_RDY 2'd2

`define SCLK_FSM_INIT 0
`define SCLK_FSM_SAMPLE 1
`define SCLK_FSM_SHIFT 0

`define CORE_CLK_FSM 0
`define SCLK_FSM 1

//----------------------------------------------------------------------
// SpiDriver
//----------------------------------------------------------------------
/*verilator coverage_off*/
/*verilator lint_off MULTIDRIVEN*/
module SpiDriver #(
  parameter p_bit_width           = 8,
  parameter p_sclk_period         = 1000, // 1 MHz typical SPI frequency
  parameter p_idle_cycles         = 4,
  parameter p_sclk_fsm_num_states = 2*(p_bit_width-1)+1, // double states for each bit and one extra for initial
  parameter p_sclk_fsm_bits       = $clog2(p_sclk_fsm_num_states)
) (
  input  logic clk,
  input  logic reset,

  output logic sclk,
  output logic mosi,
  input  logic miso,
  output logic cs,

  input  logic [p_bit_width-1:0] send_msg,
  input  logic                   send_val,
  output logic                   send_rdy,

  output logic [p_bit_width-1:0] recv_msg,
  output logic                   recv_val,
  input  logic                   recv_rdy
);

// Local transaction signals
logic core_cs;
logic core_sclk;
logic core_mosi;
logic core_recv_val;
logic core_send_rdy;
logic sclk_cs;
logic sclk_sclk;
logic sclk_mosi;
logic sclk_recv_val;
logic sclk_send_rdy;

logic sclk_half_cycle_wait;
initial sclk_half_cycle_wait = 0;

// Send message register
logic [p_bit_width-1:0] send_msg_reg;

// CORE CLK FSM states
logic [1:0] fsm_core_clk_state;

// SCLK FSM states
logic [p_sclk_fsm_bits-1:0] fsm_sclk_state;

// FSM selector
logic fsm_idx;

// SCLK clock generator
logic sclk_gen;
initial sclk_gen = 1'b0;
always #(p_sclk_period/2) sclk_gen <= ~sclk_gen;

// Idle counter
logic [$clog2(p_idle_cycles)-1:0] idle_ctr;

// Output muxes
always_comb begin
  cs       = ~fsm_idx ? core_cs : sclk_cs;
  sclk     = ~fsm_idx ? core_sclk : sclk_sclk;
  mosi     = ~fsm_idx ? core_mosi : sclk_mosi;
  recv_val = ~fsm_idx ? core_recv_val : sclk_recv_val;
  send_rdy = ~fsm_idx ? core_send_rdy : sclk_send_rdy;
end

//----------------------------------------------------------------------
// CORE CLK FSM
//----------------------------------------------------------------------
// CORE CLK FSM state
always @(posedge clk) begin
  if (reset) begin
    fsm_idx <= `CORE_CLK_FSM;
    fsm_core_clk_state <= `CORE_CLK_FSM_WAIT_FOR_RDY;
    idle_ctr <= 0;
  end
  else if (fsm_idx == `CORE_CLK_FSM) begin
    if (fsm_core_clk_state == `CORE_CLK_FSM_WAIT_FOR_RDY) begin
      idle_ctr <= 0;
      fsm_sclk_state <= `SCLK_FSM_INIT; // prevents static-0 hazard when sclk starts toggling later
      if (send_val) begin
        send_msg_reg <= send_msg;
        fsm_core_clk_state <= `CORE_CLK_FSM_IDLE;
      end
    end else if (fsm_core_clk_state == `CORE_CLK_FSM_IDLE) begin
      if (idle_ctr < p_idle_cycles-1) begin
        fsm_core_clk_state <= `CORE_CLK_FSM_IDLE;
        idle_ctr <= idle_ctr + 1;
      end else begin // Done idling - go to SCLK FSM and initialize its state
        fsm_idx <= `SCLK_FSM;
        fsm_sclk_state <= {p_sclk_fsm_bits{1'b0}};
      end
    end else if (fsm_core_clk_state == `CORE_OUTPUT_RDY) begin
      if (recv_rdy) fsm_core_clk_state <= `CORE_CLK_FSM_WAIT_FOR_RDY;
    end
  end
end

// CORE CLK FSM outputs
always_comb begin
  core_cs = 1;
  core_sclk = 0;
  core_mosi = 1'b0;
  case(fsm_core_clk_state)
    `CORE_CLK_FSM_WAIT_FOR_RDY: begin
      core_recv_val = 0;
      core_send_rdy = 1;
    end
    `CORE_CLK_FSM_IDLE: begin
      core_recv_val = 0;
      core_send_rdy = 0;
    end
    `CORE_OUTPUT_RDY: begin
      core_recv_val = 1;
      core_send_rdy = 0;
    end
    default: begin
      core_recv_val = 0;
      core_send_rdy = 1;
    end
  endcase
end

//----------------------------------------------------------------------
// SCLK FSM
//----------------------------------------------------------------------
// SCLK FSM state
always @(posedge sclk_gen, negedge sclk_gen) begin
  if (reset) begin
    fsm_sclk_state <= {p_sclk_fsm_bits{1'b0}};
  end else if (fsm_idx == `SCLK_FSM) begin
    if (fsm_sclk_state == 0) begin
      sclk_half_cycle_wait <= 1'b1;
      if (sclk_half_cycle_wait) fsm_sclk_state <= fsm_sclk_state + 1; // wait at least one sclk_gen half cycle so MISO can set up on slave side
    end else if (fsm_sclk_state < p_sclk_fsm_num_states) fsm_sclk_state <= fsm_sclk_state + 1; // increment state
    else begin // Done with SCLK FSM - go back to CORE CLK FSM and wait for receiver to be ready
      fsm_idx <= `CORE_CLK_FSM;
      fsm_core_clk_state <= `CORE_OUTPUT_RDY;
      sclk_half_cycle_wait <= 1'b0;
    end
  end
end

// SCLK FSM outputs
always_comb begin
  sclk_cs = 0;
  sclk_recv_val = 0;
  sclk_send_rdy = 0;
  if (fsm_sclk_state == `SCLK_FSM_INIT) begin // Initialize
    sclk_sclk = 0;
    sclk_mosi = logic'((send_msg_reg >> (p_bit_width-1)) & 1'b1);
    recv_msg  = 0;
  end else begin
    case(fsm_sclk_state % 2)
      `SCLK_FSM_SAMPLE: begin
        sclk_sclk = 1;
        if (!(p_bit_width-1-(fsm_sclk_state/2) == 0 && miso == 0)) // funky x put on first bit in this case, but we know it will be 0 anyway from start transmission state
          recv_msg |= (miso << (p_bit_width-1-(fsm_sclk_state/2)));
      end
      `SCLK_FSM_SHIFT: begin
        sclk_sclk = 0;
        sclk_mosi = logic'((send_msg_reg >> (p_bit_width-1-(fsm_sclk_state/2))) & 1'b1);
      end
      default: begin
        sclk_sclk = 0;
        sclk_mosi = 0;
        recv_msg  = 0;
      end
    endcase
  end
end

endmodule
/*verilator lint_on MULTIDRIVEN*/
/*verilator coverage_on*/

`endif
