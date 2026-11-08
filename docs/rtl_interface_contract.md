# RTL Interface Contract — Phase I

This contract is the shared baseline for issues #1–#3 and integration across #4, #7, #9 and #11. All sequential modules use `clk` and synchronous active-high `reset`.

## Address decoder — `rtl/address_decoder.v` (Aditya, #11)

```verilog
module address_decoder (
  input  wire [31:0] address,
  input  wire [21:0] stored_tag,
  input  wire        stored_valid,
  output wire [21:0] tag,
  output wire [5:0]  index,
  output wire [3:0]  byte_offset,
  output wire [1:0]  word_offset,
  output wire        tag_match,
  output wire        hit
);
```

- `tag = address[31:10]`, `index = address[9:4]`.
- `byte_offset = address[3:0]`, `word_offset = address[3:2]`.
- `tag_match = (stored_tag == tag)`.
- `hit = stored_valid && tag_match`.
- Prototype accepts aligned 32-bit words only: address[1:0] must be 2'b00.

## Cache storage — `rtl/cache_storage.v` (Rachit, #9)

```verilog
module cache_storage (
  input  wire         clk,
  input  wire         reset,
  input  wire [5:0]   lookup_index,
  input  wire [1:0]   lookup_word_offset,
  output wire [21:0]  lookup_tag,
  output wire         lookup_valid,
  output wire [31:0]  lookup_word_data,
  input  wire         refill_en,
  input  wire [5:0]   refill_index,
  input  wire [21:0]  refill_tag,
  input  wire [127:0] refill_block_data,
  input  wire         word_write_en,
  input  wire [5:0]   word_write_index,
  input  wire [1:0]   word_write_offset,
  input  wire [31:0]  word_write_data
);
```

Read outputs are combinational. Writes occur on the rising edge. Reset invalidates all 64 lines. A refill writes the tag, valid bit and all four words. A word write changes only the selected word. Refill has priority if both enables are asserted (the controller never intentionally asserts both).

Block ordering: [31:0] = word 0 at the lowest address; [63:32], [95:64], [127:96] = words 1–3.

## Main memory — `memory/main_memory_model.v` (Saumya, #4)

The merged implementation's existing interface is:

```verilog
module main_memory_model #(
  parameter ADDR_WIDTH = 32,
  parameter MEM_WORDS  = 4096,
  parameter LATENCY    = 5
)(
  input wire clk, input wire reset,
  input wire req, input wire write_en,
  input wire [ADDR_WIDTH-1:0] addr,
  input wire [31:0] write_data,
  output reg ready,
  output reg [127:0] block_data
);
```

`req` is a one-cycle pulse accepted while memory is idle. `write_en=0` reads the aligned four-word block containing `addr`; `write_en=1` writes one 32-bit word. `ready` is a one-cycle response after configured latency. The memory accepts one outstanding request. Contents initialize to zero at simulation start; reset resets protocol state, not the memory array.

## Performance monitor — `rtl/performance_monitor.v` (Saumya, #5)

```verilog
module performance_monitor (
  input wire clk, input wire reset,
  input wire access_complete, input wire hit_event, input wire miss_event,
  output reg [31:0] total_accesses,
  output reg [31:0] total_hits,
  output reg [31:0] total_misses
);
```

Update counters only when `access_complete` is high and exactly one of hit/miss is high.

## Cache controller — `rtl/cache_controller.v` (Krishna, #2)

The full port list is in the source. Functional groups:

- CPU request: `cpu_req`, `cpu_write`, `cpu_addr`, `cpu_wdata`.
- CPU response: one-cycle `cpu_ready`; read data valid for reads with that pulse.
- Lookup: `lookup_addr` exposes the latched address; decoded fields, `cache_hit` and selected word data return from decoder/storage.
- Cache writes: `cache_refill_en` updates a complete line; `cache_word_we` updates one word. Enables are synchronous one-cycle pulses.
- Memory: `mem_req` is a one-cycle pulse, `mem_ready` is a one-cycle response, and `mem_block_data` returns the four-word block.
- Accounting: `access_complete` and exactly one hit/miss event accompany CPU completion.

Debug state encodings: 0 IDLE, 1 LOOKUP, 2 REFILL_WAIT, 3 REFILL_INSTALL, 4 READ_MISS_RETURN, 5 WRITE_HIT_WAIT, 6 WRITE_MISS_UPDATE, 7 WRITE_MISS_WAIT.

## Top level — `rtl/cache_top.v` (Krishna, #3)

Exposes CPU request/response, the three performance counters and controller debug state. It instantiates decoder, storage, controller, memory and performance monitor using named ports. Default memory is 4096 words with five latency cycles.

## Timing contract

| Event | Timing |
|---|---|
| Request acceptance | Rising edge in IDLE when `cpu_req && !request_seen` |
| Lookup | Combinational using the latched request address |
| Cache refill/word write | Synchronous storage write on rising edge while enable is high |
| Memory request acceptance | Rising edge while memory is idle and registered `mem_req` is high |
| Memory response | One-cycle `ready` pulse after configured latency |
| CPU response | One-cycle `cpu_ready` after the full operation completes |
| Performance accounting | Event pulses accompany CPU response; monitor samples them on the rising edge |

## Integration invariants

1. Preserve tag/index/word fields [31:10], [9:4], [3:2].
2. Each line contains a 22-bit tag, one valid bit and 128 data bits.
3. Read miss installs all four words in the documented order.
4. Write hit updates cache and memory; write miss refills, updates the selected word and writes through.
5. Emit exactly one completion classification per accepted request.
6. Busy requests are not queued. Wait for completion and deassert `cpu_req` for one rising edge before the next request.
