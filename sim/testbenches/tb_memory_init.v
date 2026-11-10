`timescale 1ns/1ps

module tb_memory_init;

    reg clk = 0;
    reg reset = 1;
    reg req = 0;
    reg write_en = 0;
    reg [31:0] addr = 0;
    reg [31:0] write_data = 0;

    wire ready;
    wire [127:0] block_data;

    always #5 clk = ~clk;

    main_memory_model #(
        .MEM_INIT_FILE("memory/init_memory.hex")
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

    initial begin
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 0;
        req = 1;

        @(negedge clk);
        req = 0;

        wait (ready);

        if (block_data === {
            32'hD3D30003,
            32'hC2C20002,
            32'hB1B10001,
            32'hA0A00000
        }) begin
            $display("PASS: Memory file loaded correctly");
            $display("Block data: %h", block_data);
        end else begin
            $display("FAIL: Memory file loading incorrect");
            $display("Block data: %h", block_data);
            $fatal;
        end

        $finish;
    end

endmodule
