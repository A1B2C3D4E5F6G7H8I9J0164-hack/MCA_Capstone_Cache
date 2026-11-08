`timescale 1ns/1ps
// Controller-level verification with behavioural cache and memory models.
// The real decoder and cache_storage are supplied by the other task owners.
module tb_cache_controller;
  reg clk, reset, cpu_req, cpu_write;
  reg [31:0] cpu_addr, cpu_wdata;
  wire cpu_ready;
  wire [31:0] cpu_rdata;
  wire [31:0] lookup_addr;
  wire [21:0] lookup_tag;
  wire [5:0] lookup_index;
  wire [1:0] lookup_word_offset;
  wire cache_hit;
  wire [31:0] cache_word_data;
  wire cache_refill_en;
  wire [5:0] cache_refill_index;
  wire [21:0] cache_refill_tag;
  wire [127:0] cache_refill_data;
  wire cache_word_we;
  wire [5:0] cache_word_index;
  wire [1:0] cache_word_offset;
  wire [31:0] cache_word_wdata;
  wire mem_req, mem_write_en;
  wire [31:0] mem_addr, mem_write_data;
  reg mem_ready;
  reg [127:0] mem_block_data;
  wire access_complete, hit_event, miss_event;
  wire [3:0] debug_state;
  wire [31:0] total_accesses, total_hits, total_misses;

  reg [21:0] tags [0:63];
  reg valid [0:63];
  reg [31:0] cache_words [0:255];
  reg [31:0] memory [0:4095];
  reg memory_busy;
  integer countdown, base_word, i, errors, timeout;
  reg [31:0] saved_mem_addr, saved_mem_data;
  reg saved_mem_write;

  assign lookup_tag = lookup_addr[31:10];
  assign lookup_index = lookup_addr[9:4];
  assign lookup_word_offset = lookup_addr[3:2];
  assign cache_hit = valid[lookup_index] && (tags[lookup_index] == lookup_tag);
  assign cache_word_data = cache_words[{lookup_index, lookup_word_offset}];

  cache_controller dut (
    .clk(clk), .reset(reset), .cpu_req(cpu_req), .cpu_write(cpu_write),
    .cpu_addr(cpu_addr), .cpu_wdata(cpu_wdata), .cpu_ready(cpu_ready),
    .cpu_rdata(cpu_rdata), .lookup_addr(lookup_addr), .lookup_tag(lookup_tag),
    .lookup_index(lookup_index), .lookup_word_offset(lookup_word_offset),
    .cache_hit(cache_hit), .cache_word_data(cache_word_data),
    .cache_refill_en(cache_refill_en), .cache_refill_index(cache_refill_index),
    .cache_refill_tag(cache_refill_tag), .cache_refill_data(cache_refill_data),
    .cache_word_we(cache_word_we), .cache_word_index(cache_word_index),
    .cache_word_offset(cache_word_offset), .cache_word_wdata(cache_word_wdata),
    .mem_req(mem_req), .mem_write_en(mem_write_en), .mem_addr(mem_addr),
    .mem_write_data(mem_write_data), .mem_ready(mem_ready),
    .mem_block_data(mem_block_data), .access_complete(access_complete),
    .hit_event(hit_event), .miss_event(miss_event), .debug_state(debug_state)
  );

  performance_monitor monitor (
    .clk(clk), .reset(reset), .access_complete(access_complete),
    .hit_event(hit_event), .miss_event(miss_event),
    .total_accesses(total_accesses), .total_hits(total_hits),
    .total_misses(total_misses)
  );

  always #5 clk = ~clk;

  // Synchronous cache writes; combinational reads are provided by assigns.
  always @(posedge clk) begin
    if (reset) begin
      for (i = 0; i < 64; i = i + 1) begin
        tags[i] <= 0;
        valid[i] <= 0;
      end
      for (i = 0; i < 256; i = i + 1)
        cache_words[i] <= 0;
    end else if (cache_refill_en) begin
      tags[cache_refill_index] <= cache_refill_tag;
      valid[cache_refill_index] <= 1'b1;
      cache_words[{cache_refill_index,2'b00}] <= cache_refill_data[31:0];
      cache_words[{cache_refill_index,2'b01}] <= cache_refill_data[63:32];
      cache_words[{cache_refill_index,2'b10}] <= cache_refill_data[95:64];
      cache_words[{cache_refill_index,2'b11}] <= cache_refill_data[127:96];
    end else if (cache_word_we && valid[cache_word_index]) begin
      cache_words[{cache_word_index,cache_word_offset}] <= cache_word_wdata;
    end
  end

  // Delayed one-outstanding-request memory model; ready is a one-cycle pulse.
  always @(posedge clk) begin
    if (reset) begin
      memory_busy <= 0; countdown <= 0; mem_ready <= 0;
      mem_block_data <= 0; saved_mem_addr <= 0;
      saved_mem_data <= 0; saved_mem_write <= 0;
    end else begin
      mem_ready <= 0;
      if (!memory_busy && mem_req) begin
        memory_busy <= 1; countdown <= 3;
        saved_mem_addr <= mem_addr;
        saved_mem_data <= mem_write_data;
        saved_mem_write <= mem_write_en;
      end else if (memory_busy) begin
        if (countdown > 1)
          countdown <= countdown - 1;
        else begin
          memory_busy <= 0; mem_ready <= 1;
          if (saved_mem_write)
            memory[saved_mem_addr[31:2] % 4096] <= saved_mem_data;
          else begin
            base_word = ((saved_mem_addr >> 2) / 4) * 4;
            mem_block_data[31:0] <= memory[(base_word+0) % 4096];
            mem_block_data[63:32] <= memory[(base_word+1) % 4096];
            mem_block_data[95:64] <= memory[(base_word+2) % 4096];
            mem_block_data[127:96] <= memory[(base_word+3) % 4096];
          end
        end
      end
    end
  end

  task check_read;
    input [31:0] address, expected;
    begin
      @(negedge clk);
      cpu_addr=address; cpu_write=0; cpu_wdata=0; cpu_req=1;
      @(negedge clk); cpu_req=0; timeout=0;
      while (cpu_ready !== 1'b1 && timeout < 60) begin
        @(negedge clk); timeout=timeout+1;
      end
      if (cpu_ready !== 1'b1 || cpu_rdata !== expected) begin
        $display("FAIL read %h expected=%h actual=%h",address,expected,cpu_rdata);
        errors=errors+1;
      end else $display("PASS read %h -> %h",address,cpu_rdata);
      @(negedge clk);
    end
  endtask

  task check_write;
    input [31:0] address, data;
    begin
      @(negedge clk);
      cpu_addr=address; cpu_write=1; cpu_wdata=data; cpu_req=1;
      @(negedge clk); cpu_req=0; timeout=0;
      while (cpu_ready !== 1'b1 && timeout < 60) begin
        @(negedge clk); timeout=timeout+1;
      end
      if (cpu_ready !== 1'b1) begin
        $display("FAIL write timeout %h",address); errors=errors+1;
      end else $display("PASS write %h <- %h",address,data);
      @(negedge clk);
    end
  endtask

  initial begin
    clk=0; reset=1; cpu_req=0; cpu_write=0; cpu_addr=0; cpu_wdata=0;
    mem_ready=0; mem_block_data=0; memory_busy=0; countdown=0;
    saved_mem_addr=0; saved_mem_data=0; saved_mem_write=0; errors=0;
    for (i=0;i<4096;i=i+1) memory[i]=0;
    memory[0]=32'hA0A0_0000; memory[1]=32'hB1B1_0001;
    memory[2]=32'hC2C2_0002; memory[3]=32'hD3D3_0003;
    memory[256]=32'hE4E4_0000; memory[257]=32'hE5E5_0001;
    memory[258]=32'hE6E6_0002; memory[259]=32'hE7E7_0003;
    memory[512]=32'hF8F8_0000; memory[513]=32'hF9F9_0001;
    memory[514]=32'hFAFA_0002; memory[515]=32'hFBFB_0003;
    memory[768]=32'hACAC_0000; memory[769]=32'hADAD_0001;
    memory[770]=32'hAEAE_0002; memory[771]=32'hAFAF_0003;
    $dumpfile("sim/waveforms/cache_controller.vcd");
    $dumpvars(0,tb_cache_controller);
    repeat(3) @(negedge clk);
    reset=0; @(negedge clk);

    $display("TEST: cold miss and four-word refill");
    check_read(32'h0000_0000,32'hA0A0_0000);
    $display("TEST: repeated address and next word hit");
    check_read(32'h0000_0000,32'hA0A0_0000);
    check_read(32'h0000_0004,32'hB1B1_0001);
    check_read(32'h0000_0008,32'hC2C2_0002);
    check_read(32'h0000_000C,32'hD3D3_0003);
    $display("TEST: conflicting tag at same index replaces line");
    check_read(32'h0000_0400,32'hE4E4_0000);
    check_read(32'h0000_0000,32'hA0A0_0000);
    $display("TEST: write hit updates cache and main memory");
    check_write(32'h0000_0004,32'h1234_5678);
    if (memory[1] !== 32'h1234_5678) begin
      $display("FAIL write-hit not in memory"); errors=errors+1;
    end
    check_read(32'h0000_0004,32'h1234_5678);
    $display("TEST: write miss allocates and writes through");
    check_write(32'h0000_0804,32'h8765_4321);
    if (memory[513] !== 32'h8765_4321) begin
      $display("FAIL write-miss not in memory"); errors=errors+1;
    end
    check_read(32'h0000_0804,32'h8765_4321);

    $display("TEST: busy request is discarded; original miss completes");
    @(negedge clk);
    cpu_addr=32'h0000_0C00; cpu_write=0; cpu_req=1;
    @(negedge clk); cpu_req=0; timeout=0;
    while (debug_state != 4'd2 && timeout < 20) begin
      @(negedge clk); timeout=timeout+1;
    end
    if (debug_state != 4'd2) begin
      $display("FAIL controller did not reach REFILL_WAIT"); errors=errors+1;
    end else begin
      @(negedge clk); cpu_addr=32'h0000_0010; cpu_req=1;
      @(negedge clk); cpu_req=0; timeout=0;
      while (cpu_ready !== 1'b1 && timeout < 60) begin
        @(negedge clk); timeout=timeout+1;
      end
      if (cpu_ready !== 1'b1 || cpu_rdata !== 32'hACAC_0000) begin
        $display("FAIL original busy-period request returned wrong data"); errors=errors+1;
      end else $display("PASS original request completed; busy request was not queued");
      @(negedge clk);
    end
    check_read(32'h0000_0010,32'h0000_0000);

    if (total_accesses !== 32'd13 || total_hits !== 32'd7 || total_misses !== 32'd6) begin
      $display("FAIL counters expected 13/7/6 got %0d/%0d/%0d",
               total_accesses,total_hits,total_misses);
      errors=errors+1;
    end else $display("PASS counters accesses=13 hits=7 misses=6");

    if (errors==0) $display("FINAL RESULT: ALL CONTROLLER TESTS PASSED");
    else $display("FINAL RESULT: %0d CONTROLLER TEST(S) FAILED",errors);
    $finish;
  end
endmodule
