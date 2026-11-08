`timescale 1ns/1ps

// Integrated direct-mapped cache top level. Decoder and cache-storage ports
// are specified in docs/rtl_interface_contract.md.
module cache_top #(
    parameter MEM_WORDS=4096,
    parameter MEM_LATENCY=5
)(
    input wire clk, input wire reset,
    input wire cpu_req, input wire cpu_write,
    input wire [31:0] cpu_addr, input wire [31:0] cpu_wdata,
    output wire cpu_ready, output wire [31:0] cpu_rdata,
    output wire [31:0] total_accesses,
    output wire [31:0] total_hits,
    output wire [31:0] total_misses,
    output wire [3:0] controller_state
);
    wire [31:0] lookup_addr;
    wire [21:0] decoded_tag, stored_tag;
    wire [5:0] decoded_index;
    wire [3:0] decoded_byte_offset;
    wire [1:0] decoded_word_offset;
    wire tag_match, cache_hit, stored_valid;
    wire [31:0] stored_word_data;

    wire cache_refill_en;
    wire [5:0] cache_refill_index;
    wire [21:0] cache_refill_tag;
    wire [127:0] cache_refill_data;
    wire cache_word_we;
    wire [5:0] cache_word_index;
    wire [1:0] cache_word_offset;
    wire [31:0] cache_word_wdata;

    wire mem_req, mem_write_en, mem_ready;
    wire [31:0] mem_addr, mem_write_data;
    wire [127:0] mem_block_data;
    wire access_complete, hit_event, miss_event;

    address_decoder u_address_decoder (
        .address(lookup_addr), .stored_tag(stored_tag),
        .stored_valid(stored_valid), .tag(decoded_tag),
        .index(decoded_index), .byte_offset(decoded_byte_offset),
        .word_offset(decoded_word_offset), .tag_match(tag_match),
        .hit(cache_hit)
    );

    cache_storage u_cache_storage (
        .clk(clk), .reset(reset),
        .lookup_index(decoded_index),
        .lookup_word_offset(decoded_word_offset),
        .lookup_tag(stored_tag), .lookup_valid(stored_valid),
        .lookup_word_data(stored_word_data),
        .refill_en(cache_refill_en), .refill_index(cache_refill_index),
        .refill_tag(cache_refill_tag), .refill_block_data(cache_refill_data),
        .word_write_en(cache_word_we), .word_write_index(cache_word_index),
        .word_write_offset(cache_word_offset),
        .word_write_data(cache_word_wdata)
    );

    main_memory_model #(
        .ADDR_WIDTH(32), .MEM_WORDS(MEM_WORDS), .LATENCY(MEM_LATENCY)
    ) u_main_memory (
        .clk(clk), .reset(reset), .req(mem_req), .write_en(mem_write_en),
        .addr(mem_addr), .write_data(mem_write_data),
        .ready(mem_ready), .block_data(mem_block_data)
    );

    cache_controller u_cache_controller (
        .clk(clk), .reset(reset), .cpu_req(cpu_req), .cpu_write(cpu_write),
        .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata),
        .cpu_ready(cpu_ready), .cpu_rdata(cpu_rdata),
        .lookup_addr(lookup_addr), .lookup_tag(decoded_tag),
        .lookup_index(decoded_index), .lookup_word_offset(decoded_word_offset),
        .cache_hit(cache_hit), .cache_word_data(stored_word_data),
        .cache_refill_en(cache_refill_en),
        .cache_refill_index(cache_refill_index),
        .cache_refill_tag(cache_refill_tag),
        .cache_refill_data(cache_refill_data),
        .cache_word_we(cache_word_we), .cache_word_index(cache_word_index),
        .cache_word_offset(cache_word_offset), .cache_word_wdata(cache_word_wdata),
        .mem_req(mem_req), .mem_write_en(mem_write_en), .mem_addr(mem_addr),
        .mem_write_data(mem_write_data), .mem_ready(mem_ready),
        .mem_block_data(mem_block_data), .access_complete(access_complete),
        .hit_event(hit_event), .miss_event(miss_event),
        .debug_state(controller_state)
    );

    performance_monitor u_performance_monitor (
        .clk(clk), .reset(reset), .access_complete(access_complete),
        .hit_event(hit_event), .miss_event(miss_event),
        .total_accesses(total_accesses), .total_hits(total_hits),
        .total_misses(total_misses)
    );
endmodule
