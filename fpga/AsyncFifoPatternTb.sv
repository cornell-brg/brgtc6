`include "../../fpga/archive/AsyncFifoSrcFpga.sv"
`include "../../fpga/archive/AsyncFifoSinkFpga.sv"

module AsyncFifoPatternTb;

logic i_clk, o_clk;
logic i_reset_n, o_reset_n;
logic i_reset;
logic i_start, o_start;
logic val, rdy;
logic [4:0] msg;
logic [1:0] o_state;

logic locked;

always #10 i_clk = ~i_clk;
always #35 o_clk = ~o_clk;

AsyncFifoSrcFPGA async_fifo_src (
    .clk(i_clk),
    .reset_n(i_reset_n),
    .start(i_start),
    .ostream_val(val),
    .ostream_msg(msg),
    .ostream_rdy(rdy),
    .started(),
    .ostream_val_dup(),
    .ostream_rdy_dup(),
    .i_reset(i_reset),
    .i_clk()
);


AsyncFifoSinkFPGA async_fifo_sink (
    .o_clk(o_clk),
    .o_reset_n(o_reset_n),
    .start(o_start),
    .i_clk(i_clk),
    .i_reset(i_reset),
    .istream_val(val),
    .istream_msg(msg),
    .istream_rdy(rdy),
    .state(o_state),
    .istream_val_dup(),
    .istream_rdy_dup(),
    .started()
);

initial begin
    i_clk = 1'b0; i_reset_n = 1'b0; i_start = 1'b0;

    repeat(10) @(posedge i_clk);
    i_reset_n = 1'b1;

    i_start = 1'b1;
end

initial begin
    o_clk = 1'b0; o_reset_n = 1'b0; o_start = 1'b0;

    locked = 1'b0;

    repeat(10) @(posedge o_clk);
    o_reset_n = 1'b1;

    o_start = 1'b1;

    repeat(1000) begin
        @(posedge o_clk);
        #17.5
        if(o_state == `PATTERN_CHK_LOCK) begin
            locked = 1'b1;
        end

        if(o_state == `PATTERN_CHK_ERR) begin
            $error("ERROR, GOT WRONG DATA AFTER LOCKING");
        end
    end

    if(locked) begin
        $display("");
        $display("  [ passed ]");
        $display("");

    end else begin
        $error("ERROR, DID NOT LOCK");
    end

    $finish;
end

initial begin
    $dumpfile("async_fifo_pattern_tb.vcd");
    $dumpvars(0, AsyncFifoPatternTb);
end




endmodule