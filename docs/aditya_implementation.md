# Aditya's Phase I Implementation Notes

**Author:** Aditya Rana  
**Scope:** Issues #11 and #12  
**Module:** 32-bit Address Decoder & Tag Comparator  

---

## Deliverables

- `rtl/address_decoder.v`: Purely combinational 32-bit address decoder, 22-bit tag comparator, and hit evaluation logic.
- `sim/testbenches/tb_address_decoder.v`: Comprehensive self-checking unit testbench covering 10 test suites (374 checks, 0 errors).
- `sim/run_aditya_tests.sh`: Reproducible standalone simulation runner for local verification.
- `sim/waveforms/address_decoder.vcd`: Signal waveform dump for visual inspection in GTKWave or Surfer.
- `sim/run_krishna_tests.sh`: Integrated address decoder verification into the project-wide simulation pipeline.
- `docs/results/address_decoder_test_log.txt`: Recorded simulation execution log.

---

## Architectural Mapping & Bit Breakdown

In the Phase I 1 KiB direct-mapped cache architecture (64 lines, 16 bytes/line, four 32-bit words/line):

| Field | Bit Range | Width | Description |
|---|---|---:|---|
| **Tag** | `address[31:10]` | 22 bits | Block identifier in memory |
| **Index** | `address[9:4]` | 6 bits | Cache line selector ($2^6 = 64$ lines) |
| **Byte Offset** | `address[3:0]` | 4 bits | Byte within 16-byte cache line |
| **Word Offset** | `address[3:2]` | 2 bits | Word selector within line ($2^2 = 4$ words) |
| **Alignment** | `address[1:0]` | 2 bits | Must be `2'b00` for 32-bit aligned accesses |

---

## RTL Design Details (`rtl/address_decoder.v`)

The module is implemented in strict accordance with `docs/rtl_interface_contract.md`:

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

    // Continuous bit-slicing
    assign tag         = address[31:10];
    assign index       = address[9:4];
    assign byte_offset = address[3:0];
    assign word_offset = address[3:2];

    // Tag comparison and valid qualification
    assign tag_match   = (stored_tag == tag);
    assign hit         = stored_valid && tag_match;

endmodule
```

### Key Design Invariants
1. **Zero-Latency Combinational Logic**: Does not consume clock cycles or require a reset line, providing instantaneous outputs for controller evaluation in the `LOOKUP` state.
2. **Tag Equality**: `tag_match` evaluates true if and only if all 22 bits of `stored_tag` match `address[31:10]`.
3. **Hit Qualification**: `hit` requires both `stored_valid == 1` and `tag_match == 1`. If a cache line is invalid (`stored_valid == 0`), `hit` is guaranteed low regardless of tag equality.

---

## Verification Strategy (`sim/testbenches/tb_address_decoder.v`)

The testbench incorporates 10 rigorous test suites validating all functional, boundary, and corner conditions:

1. **Known Address Decoding**: Tests deterministic addresses across the address space (`0x12345670`, `0xDEADBEE4`, `0x00000408`, `0xFFFFFFFC`).
2. **64-Index Line Sweep**: Exhaustively sweeps cache line indices from `6'd0` to `6'd63` to confirm zero bit aliasing or indexing skew.
3. **Word Selector Alignment Sweep**: Sweeps words 0, 1, 2, and 3 (`2'b00`, `2'b01`, `2'b10`, `2'b11`).
4. **Cache Hit Verification**: Validates `hit == 1` and `tag_match == 1` under valid matching conditions.
5. **Cache Miss Verification (Tag Mismatch)**: Verifies `hit == 0` and `tag_match == 0` for tag mismatches (MSB, LSB, and inverted patterns).
6. **Cold / Compulsory Miss**: Verifies `hit == 0` when `stored_valid == 0`, even when tags match.
7. **Invalid Line & Tag Mismatch**: Confirms both `tag_match == 0` and `hit == 0`.
8. **Tag Bit-Isolation (Walking 1s & 0s)**: Independently exercises all 22 bits of the comparator to detect any stuck-at faults or cross-bit shorts.
9. **Combinational Zero-Latency Settling**: Verifies instantaneous output updates upon asynchronous input changes.
10. **200 Randomized Fuzz Vectors**: Compares randomized permutations against an independent golden reference model.

---

## Acceptance Mapping

### Issue #11 — Implement 32-bit address decoder and tag comparator
- [x] Address slicing into tag, index, word offset, and byte offset implemented in `rtl/address_decoder.v`.
- [x] 22-bit tag comparator (`tag_match`) implemented.
- [x] Valid-qualified cache hit generation (`hit`) implemented.
- [x] Exact port list and naming matching `docs/rtl_interface_contract.md`.

### Issue #12 — Create address decoder and comparator unit testbench
- [x] Comprehensive self-checking unit testbench implemented in `sim/testbenches/tb_address_decoder.v`.
- [x] Standalone simulation runner `sim/run_aditya_tests.sh` created.
- [x] Waveform trace `sim/waveforms/address_decoder.vcd` generated.
- [x] 10 test suites executed with 374 checks and 0 failures.
- [x] Integration runner `sim/run_krishna_tests.sh` updated and passing.

