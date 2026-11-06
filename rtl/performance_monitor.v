
`timescale 1ns/1ps

module performance_monitor (

    input wire clk,
    input wire reset,

    // Event signals from cache controller
    input wire access_complete,
    input wire hit_event,
    input wire miss_event,

    // 32-bit performance counters
    output reg [31:0] total_accesses,
    output reg [31:0] total_hits,
    output reg [31:0] total_misses

);

    // -----------------------------------------
    // PERFORMANCE MONITOR
    // -----------------------------------------

    always @(posedge clk) begin

        if (reset) begin

            // Reset all performance counters
            total_accesses <= 32'd0;
            total_hits     <= 32'd0;
            total_misses   <= 32'd0;

        end

        // Count only completed requests having
        // exactly one valid hit/miss event
        else if (access_complete && (hit_event ^ miss_event)) begin

            total_accesses <= total_accesses + 1'b1;

            if (hit_event) begin

                total_hits <= total_hits + 1'b1;

            end

            else begin

                total_misses <= total_misses + 1'b1;

            end

        end

    end

endmodule
