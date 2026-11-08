
`timescale 1ns/1ps

module tb_performance_monitor;

    reg clk;
    reg reset;
    reg access_complete;
    reg hit_event;
    reg miss_event;

    wire [31:0] total_accesses;
    wire [31:0] total_hits;
    wire [31:0] total_misses;

    integer errors;

    // DUT instantiation
    performance_monitor dut (
        .clk(clk),
        .reset(reset),
        .access_complete(access_complete),
        .hit_event(hit_event),
        .miss_event(miss_event),
        .total_accesses(total_accesses),
        .total_hits(total_hits),
        .total_misses(total_misses)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    // Task to generate one cache access
    task send_access;
        input is_hit;
        begin
            @(negedge clk);
            access_complete = 1'b1;
            hit_event = is_hit;
            miss_event = !is_hit;

            @(negedge clk);
            access_complete = 1'b0;
            hit_event = 1'b0;
            miss_event = 1'b0;
        end
    endtask

    initial begin

        $dumpfile("sim/waveforms/performance_monitor.vcd");
        $dumpvars(0, tb_performance_monitor);

        clk = 0;
        reset = 1;
        access_complete = 0;
        hit_event = 0;
        miss_event = 0;
        errors = 0;

        // TEST 1: RESET
        $display("\nTEST 1: RESET");

        repeat(2) @(negedge clk);
        #1 reset = 0;

        @(posedge clk);
        #1;

        if (total_accesses == 0 &&
            total_hits == 0 &&
            total_misses == 0)
            $display("PASS: All counters reset");
        else begin
            $display("FAIL: Reset failed");
            errors = errors + 1;
        end

        // TEST 2: HIT COUNTING
        $display("\nTEST 2: HIT COUNTING");

        send_access(1);
        send_access(1);
        send_access(1);

        if (total_hits == 3)
            $display("PASS: Three hits counted");
        else begin
            $display("FAIL: Hit counter incorrect");
            errors = errors + 1;
        end

        // TEST 3: MISS COUNTING
        $display("\nTEST 3: MISS COUNTING");

        send_access(0);
        send_access(0);
        send_access(0);

        if (total_misses == 3)
            $display("PASS: Three misses counted");
        else begin
            $display("FAIL: Miss counter incorrect");
            errors = errors + 1;
        end

        // TEST 4: TOTAL ACCESS COUNT
        $display("\nTEST 4: TOTAL ACCESS COUNT");

        if (total_accesses == 6)
            $display("PASS: Six accesses counted");
        else begin
            $display("FAIL: Total access counter incorrect");
            errors = errors + 1;
        end

        // TEST 5: INCOMPLETE ACCESS
        $display("\nTEST 5: INCOMPLETE ACCESS");

        @(negedge clk);
        access_complete = 0;
        hit_event = 1;
        miss_event = 0;

        @(negedge clk);
        hit_event = 0;

        if (total_accesses == 6 && total_hits == 3)
            $display("PASS: Incomplete access not counted");
        else begin
            $display("FAIL: False counter increment");
            errors = errors + 1;
        end

        // TEST 6: SIMULTANEOUS HIT AND MISS
        $display("\nTEST 6: MUTUALLY EXCLUSIVE EVENTS");

        @(negedge clk);
        access_complete = 1;
        hit_event = 1;
        miss_event = 1;

        @(negedge clk);
        access_complete = 0;
        hit_event = 0;
        miss_event = 0;

        if (total_accesses == 6 &&
            total_hits == 3 &&
            total_misses == 3)
            $display("PASS: Invalid simultaneous events ignored");
        else begin
            $display("FAIL: Mutual exclusion handling incorrect");
            errors = errors + 1;
        end

        // TEST 7: MISSING CLASSIFICATION
        $display("\nTEST 7: MISSING CLASSIFICATION");

        @(negedge clk);
        access_complete = 1;
        hit_event = 0;
        miss_event = 0;

        @(negedge clk);
        access_complete = 0;

        if (total_accesses == 6 &&
            total_hits == 3 &&
            total_misses == 3)
            $display("PASS: Unclassified access ignored");
        else begin
            $display("FAIL: Unclassified access counted");
            errors = errors + 1;
        end

        // TEST 8: COUNTER INVARIANT
        $display("\nTEST 8: COUNTER INVARIANT");

        if (total_accesses == total_hits + total_misses)
            $display("PASS: Total = Hits + Misses");
        else begin
            $display("FAIL: Counter invariant violated");
            errors = errors + 1;
        end

        // TEST 9: PERFORMANCE REPORT
        $display("\n================================");
        $display("     PERFORMANCE MONITOR REPORT");
        $display("================================");

        $display("TOTAL ACCESS : %0d", total_accesses);
        $display("TOTAL HITS   : %0d", total_hits);
        $display("TOTAL MISSES : %0d", total_misses);

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\nTESTS FAILED: %0d errors", errors);

        $display("================================");

        // TEST 10: RESET AFTER COUNTING
        $display("\nTEST 10: RESET AFTER COUNTING");

        @(negedge clk);
        reset = 1;

        @(negedge clk);
        reset = 0;

        @(posedge clk);
        #1;

        if (total_accesses == 0 &&
            total_hits == 0 &&
            total_misses == 0)
            $display("PASS: Reset clears all counters");
        else begin
            $display("FAIL: Counter reset unsuccessful");
            errors = errors + 1;
        end

        // FINAL RESULT
        $display("\n================================");

        if (errors == 0)
            $display("FINAL RESULT: ALL 10 TESTS PASSED");
        else
            $display("FINAL RESULT: %0d TESTS FAILED", errors);

        $display("================================\n");

        $finish;

    end

endmodule
