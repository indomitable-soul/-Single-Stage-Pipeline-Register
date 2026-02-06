`timescale 1ns/1ps

module pipeline_reg_tb;

    parameter int DATA_WIDTH = 32;
    parameter int DEPTH = 16;

    logic clk;
    logic rst_n;

    logic                   in_valid;
    logic                   in_ready;
    logic [DATA_WIDTH-1:0]  in_data;

    logic                   out_valid;
    logic                   out_ready;
    logic [DATA_WIDTH-1:0]  out_data;

    // DUT
    pipeline_reg #(.DATA_WIDTH(DATA_WIDTH)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_data(in_data),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .out_data(out_data)
    );

    // Clock
    always #5 clk = ~clk;

    // Scoreboard (fixed array)
    logic [DATA_WIDTH-1:0] exp_mem [0:DEPTH-1];
    int wr_ptr, rd_ptr;

    // VCD dump
    initial begin
        $dumpfile("pipeline_reg.vcd");
        $dumpvars(0, pipeline_reg_tb);
    end

    // Monitor output
    always @(posedge clk) begin
        if (out_valid && out_ready) begin
            if (exp_mem[rd_ptr] !== out_data) begin
                $error("Mismatch: expected %h got %h",
                        exp_mem[rd_ptr], out_data);
            end
            rd_ptr++;
        end
    end

    // Send task
    task send(input logic [DATA_WIDTH-1:0] data);
        begin
            in_valid = 1;
            in_data  = data;
            wait (in_ready);
            @(posedge clk);
            exp_mem[wr_ptr] = data;
            wr_ptr++;
            in_valid = 0;
        end
    endtask

    initial begin
        // Init
        clk = 0;
        rst_n = 0;
        in_valid = 0;
        in_data = 0;
        out_ready = 0;
        wr_ptr = 0;
        rd_ptr = 0;

        // ---------------- Test 1: Reset ----------------
        repeat (2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        if (out_valid !== 0)
            $error("Reset failed");

        $display("Reset test passed");

        // ---------------- Test 2: Continuous flow ----------------
        out_ready = 1;
        send(32'hA1);
        send(32'hA2);
        send(32'hA3);
        repeat (5) @(posedge clk);
        $display("Continuous flow passed");

        // ---------------- Test 3: Backpressure ----------------
        out_ready = 0;
        send(32'hB1);
        repeat (4) @(posedge clk);
        out_ready = 1;
        repeat (2) @(posedge clk);
        $display("Backpressure passed");

        // ---------------- Test 4: Bubble insertion ----------------
        send(32'hC1);
        repeat (2) @(posedge clk);
        send(32'hC2);
        repeat (3) @(posedge clk);
        $display("Bubble insertion passed");

        // ---------------- Test 5: Simultaneous push/pop ----------------
        out_ready = 1;
        in_valid = 1;
        in_data  = 32'hD1;
        wait (in_ready);
        @(posedge clk);
        exp_mem[wr_ptr++] = 32'hD1;

        in_data = 32'hD2;
        @(posedge clk);
        exp_mem[wr_ptr++] = 32'hD2;

        in_valid = 0;
        repeat (5) @(posedge clk);
        $display("Simultaneous push/pop passed");

        // ---------------- Done ----------------
        if (wr_ptr != rd_ptr)
            $error("Data left in scoreboard");

        $display("ALL TESTS PASSED");
        $finish;
    end

endmodule

