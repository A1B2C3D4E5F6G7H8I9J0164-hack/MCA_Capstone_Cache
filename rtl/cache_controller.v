`timescale 1ns/1ps

// Direct-mapped cache controller.
//
// CPU protocol: cpu_req is captured once while IDLE. Requests asserted for
// the first time while busy are dropped, not queued. Deassert cpu_req for at
// least one rising edge between distinct transactions. cpu_ready is a pulse.
//
// Memory protocol: mem_req is a pulse, mem_ready is a response pulse.
// mem_block_data[31:0] is the lowest-address word, then [63:32], [95:64],
// and [127:96] are the next three words.
module cache_controller (
    input wire clk, input wire reset,
    input wire cpu_req, input wire cpu_write,
    input wire [31:0] cpu_addr, input wire [31:0] cpu_wdata,
    output reg cpu_ready, output reg [31:0] cpu_rdata,

    output wire [31:0] lookup_addr,
    input wire [21:0] lookup_tag, input wire [5:0] lookup_index,
    input wire [1:0] lookup_word_offset,
    input wire cache_hit, input wire [31:0] cache_word_data,

    output reg cache_refill_en, output reg [5:0] cache_refill_index,
    output reg [21:0] cache_refill_tag, output reg [127:0] cache_refill_data,
    output reg cache_word_we, output reg [5:0] cache_word_index,
    output reg [1:0] cache_word_offset, output reg [31:0] cache_word_wdata,

    output reg mem_req, output reg mem_write_en,
    output reg [31:0] mem_addr, output reg [31:0] mem_write_data,
    input wire mem_ready, input wire [127:0] mem_block_data,

    output reg access_complete, output reg hit_event, output reg miss_event,
    output wire [3:0] debug_state
);
    localparam [3:0] ST_IDLE=4'd0, ST_LOOKUP=4'd1,
        ST_REFILL_WAIT=4'd2, ST_REFILL_INSTALL=4'd3,
        ST_READ_MISS_RETURN=4'd4, ST_WRITE_HIT_WAIT=4'd5,
        ST_WRITE_MISS_UPDATE=4'd6, ST_WRITE_MISS_WAIT=4'd7;

    reg [3:0] state;
    reg request_seen;
    reg [31:0] saved_addr, saved_wdata;
    reg saved_write;

    assign lookup_addr = saved_addr;
    assign debug_state = state;

    always @(posedge clk) begin
        if (reset) begin
            state <= ST_IDLE;
            request_seen <= 1'b0;
            saved_addr <= 32'b0;
            saved_wdata <= 32'b0;
            saved_write <= 1'b0;
            cpu_ready <= 1'b0;
            cpu_rdata <= 32'b0;
            cache_refill_en <= 1'b0;
            cache_refill_index <= 6'b0;
            cache_refill_tag <= 22'b0;
            cache_refill_data <= 128'b0;
            cache_word_we <= 1'b0;
            cache_word_index <= 6'b0;
            cache_word_offset <= 2'b0;
            cache_word_wdata <= 32'b0;
            mem_req <= 1'b0;
            mem_write_en <= 1'b0;
            mem_addr <= 32'b0;
            mem_write_data <= 32'b0;
            access_complete <= 1'b0;
            hit_event <= 1'b0;
            miss_event <= 1'b0;
        end else begin
            // Default pulse outputs low every cycle.
            cpu_ready <= 1'b0;
            cache_refill_en <= 1'b0;
            cache_word_we <= 1'b0;
            mem_req <= 1'b0;
            access_complete <= 1'b0;
            hit_event <= 1'b0;
            miss_event <= 1'b0;

            // Do not replay a held request; only a new assertion is eligible.
            if (!cpu_req)
                request_seen <= 1'b0;
            else
                request_seen <= 1'b1;

            case (state)
                ST_IDLE: begin
                    if (cpu_req && !request_seen) begin
                        saved_addr <= cpu_addr;
                        saved_write <= cpu_write;
                        saved_wdata <= cpu_wdata;
                        state <= ST_LOOKUP;
                    end
                end

                ST_LOOKUP: begin
                    if (cache_hit) begin
                        if (saved_write) begin
                            // Write-through hit: update cache and memory.
                            cache_word_we <= 1'b1;
                            cache_word_index <= lookup_index;
                            cache_word_offset <= lookup_word_offset;
                            cache_word_wdata <= saved_wdata;
                            mem_req <= 1'b1;
                            mem_write_en <= 1'b1;
                            mem_addr <= saved_addr;
                            mem_write_data <= saved_wdata;
                            state <= ST_WRITE_HIT_WAIT;
                        end else begin
                            cpu_rdata <= cache_word_data;
                            cpu_ready <= 1'b1;
                            access_complete <= 1'b1;
                            hit_event <= 1'b1;
                            state <= ST_IDLE;
                        end
                    end else begin
                        // Every miss fetches a complete aligned 16-byte line.
                        mem_req <= 1'b1;
                        mem_write_en <= 1'b0;
                        mem_addr <= saved_addr;
                        mem_write_data <= 32'b0;
                        state <= ST_REFILL_WAIT;
                    end
                end

                ST_REFILL_WAIT: begin
                    if (mem_ready)
                        state <= ST_REFILL_INSTALL;
                end

                ST_REFILL_INSTALL: begin
                    // Registered pulse is sampled by storage on the next edge.
                    cache_refill_en <= 1'b1;
                    cache_refill_index <= lookup_index;
                    cache_refill_tag <= lookup_tag;
                    cache_refill_data <= mem_block_data;
                    if (saved_write)
                        state <= ST_WRITE_MISS_UPDATE;
                    else
                        state <= ST_READ_MISS_RETURN;
                end

                ST_READ_MISS_RETURN: begin
                    case (saved_addr[3:2])
                        2'd0: cpu_rdata <= mem_block_data[31:0];
                        2'd1: cpu_rdata <= mem_block_data[63:32];
                        2'd2: cpu_rdata <= mem_block_data[95:64];
                        2'd3: cpu_rdata <= mem_block_data[127:96];
                    endcase
                    cpu_ready <= 1'b1;
                    access_complete <= 1'b1;
                    miss_event <= 1'b1;
                    state <= ST_IDLE;
                end

                ST_WRITE_HIT_WAIT: begin
                    if (mem_ready) begin
                        cpu_ready <= 1'b1;
                        access_complete <= 1'b1;
                        hit_event <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                ST_WRITE_MISS_UPDATE: begin
                    // Storage sampled the refill on the preceding edge.
                    cache_word_we <= 1'b1;
                    cache_word_index <= lookup_index;
                    cache_word_offset <= lookup_word_offset;
                    cache_word_wdata <= saved_wdata;
                    mem_req <= 1'b1;
                    mem_write_en <= 1'b1;
                    mem_addr <= saved_addr;
                    mem_write_data <= saved_wdata;
                    state <= ST_WRITE_MISS_WAIT;
                end

                ST_WRITE_MISS_WAIT: begin
                    if (mem_ready) begin
                        cpu_ready <= 1'b1;
                        access_complete <= 1'b1;
                        miss_event <= 1'b1;
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
