
`timescale 1ns/1ps

module tb_main_memory;

    reg clk;
    reg reset;
    reg req;
    reg write_en;
    reg [31:0] addr;
    reg [31:0] write_data;

    wire ready;
    wire [127:0] block_data;

    integer cycles;
    integer errors;

    // Instantiate main memory
    main_memory_model #(
        .ADDR_WIDTH(32),
        .MEM_WORDS(4096),
        .LATENCY(5)
    ) dut (
        .clk(clk),
        .reset(reset),
        .req(req),
        .write_en(write_en),
        .addr(addr),
        .write_data(write_data),
        .ready(ready),
        .block_data(block_data)
    );

    // Clock: 10 ns period
    always #5 clk = ~clk;

    // Send a memory request and wait for response
    task send_request;
        input [31:0] request_addr;
        input request_write;
        input [31:0] request_data;

        begin
            @(negedge clk);

            addr = request_addr;
            write_en = request_write;
            write_data = request_data;
            req = 1'b1;

            @(negedge clk);
            req = 1'b0;

            cycles = 0;

            while (ready !== 1'b1 && cycles < 20) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (ready !== 1'b1) begin
                $display("FAIL: Memory response timeout");
                errors = errors + 1;
            end
        end
    endtask


    initial begin

        $dumpfile("sim/waveforms/main_memory.vcd");
        $dumpvars(0, tb_main_memory);

        clk = 0;
        reset = 1;
        req = 0;
        write_en = 0;
        addr = 0;
        write_data = 0;
        errors = 0;

        // Reset
        repeat(2) @(negedge clk);
        reset = 0;

        // --------------------------------
        // TEST 1: BLOCK READ
        // --------------------------------

        $display("\nTEST 1: BLOCK READ");

        // Initialize memory words
        dut.mem[4] = 32'hAAAAAAAA;
        dut.mem[5] = 32'hBBBBBBBB;
        dut.mem[6] = 32'hCCCCCCCC;
        dut.mem[7] = 32'hDDDDDDDD;

        send_request(32'h00000010, 1'b0, 32'b0);

        $display("Received block: %h", block_data);

        if (block_data[31:0] !== 32'hAAAAAAAA ||
            block_data[63:32] !== 32'hBBBBBBBB ||
            block_data[95:64] !== 32'hCCCCCCCC ||
            block_data[127:96] !== 32'hDDDDDDDD) begin

            $display("FAIL: Block read incorrect");
            errors = errors + 1;

        end
        else begin
            $display("PASS: Four consecutive words read correctly");
        end


        // --------------------------------
        // TEST 2: EXACT WORD WRITE
        // --------------------------------

        $display("\nTEST 2: WORD WRITE");

        // Address 0x24 corresponds to word index 9
        send_request(
            32'h00000024,
            1'b1,
            32'h12345678
        );

        if (dut.mem[9] !== 32'h12345678) begin
            $display("FAIL: Memory write incorrect");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Correct word updated");
        end


        // --------------------------------
        // TEST 3: READ AFTER WRITE
        // --------------------------------

        $display("\nTEST 3: READ AFTER WRITE");

        send_request(32'h00000020, 1'b0, 32'b0);

        if (block_data[63:32] !== 32'h12345678) begin
            $display("FAIL: Written value not returned");
            errors = errors + 1;
        end
        else begin
            $display("PASS: Written value read back correctly");
        end


        // --------------------------------
        // TEST 4: LATENCY
        // --------------------------------

        $display("\nTEST 4: MEMORY LATENCY");

        send_request(32'h00000010, 1'b0, 32'b0);

        $display("Response wait cycles: %0d", cycles);

        if (cycles >= 5 && cycles <= 20) begin
            $display("PASS: Configured latency respected");
        end
        else begin
            $display("FAIL: Unexpected response latency");
            errors = errors + 1;
        end


        // --------------------------------
        // FINAL REPORT
        // --------------------------------

        $display("\n-----------------------------");

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d errors", errors);

        $display("-----------------------------\n");

        $finish;

    end

endmodule
