`timescale 1ns/1ps

// ============================================================================
// Testbench: tb_address_decoder
// Author: Aditya Rana
// Description:
//   Comprehensive unit testbench for 32-bit address decoder and tag comparator
//   (rtl/address_decoder.v) covering:
//     1. Address field decoding (tag [31:10], index [9:4], offset [3:0], word [3:2])
//     2. Cache line index sweep (all 64 indices, 0 to 63)
//     3. Word offset alignment sweep (words 0, 1, 2, 3)
//     4. Valid cache hit condition (valid=1, tag_match=1 -> hit=1)
//     5. Valid cache miss condition / tag mismatch (valid=1, tag_match=0 -> hit=0)
//     6. Cold/compulsory miss condition (valid=0, tag_match=1 -> hit=0)
//     7. Invalid tag mismatch condition (valid=0, tag_match=0 -> hit=0)
//     8. Tag bit-isolation walking 1s and 0s across all 22 tag bits
//     9. Extreme boundary patterns (all zeros, all ones, alternating bits)
//    10. Randomized stress test with self-checking golden model
// ============================================================================

module tb_address_decoder;

    reg  [31:0] address;
    reg  [21:0] stored_tag;
    reg         stored_valid;

    wire [21:0] tag;
    wire [5:0]  index;
    wire [3:0]  byte_offset;
    wire [1:0]  word_offset;
    wire        tag_match;
    wire        hit;

    integer errors;
    integer total_checks;
    integer i;

    // Instantiate Device Under Test (DUT)
    address_decoder dut (
        .address(address),
        .stored_tag(stored_tag),
        .stored_valid(stored_valid),
        .tag(tag),
        .index(index),
        .byte_offset(byte_offset),
        .word_offset(word_offset),
        .tag_match(tag_match),
        .hit(hit)
    );

    // Verification task: checks all output wires against expected values
    task verify_decoder;
        input [31:0] test_addr;
        input [21:0] test_stored_tag;
        input        test_stored_valid;
        input [63:0] label;

        reg [21:0] exp_tag;
        reg [5:0]  exp_index;
        reg [3:0]  exp_byte_offset;
        reg [1:0]  exp_word_offset;
        reg        exp_tag_match;
        reg        exp_hit;
        reg        case_failed;

        begin
            address      = test_addr;
            stored_tag   = test_stored_tag;
            stored_valid = test_stored_valid;
            #1; // Allow combinational logic to evaluate

            exp_tag         = test_addr[31:10];
            exp_index       = test_addr[9:4];
            exp_byte_offset = test_addr[3:0];
            exp_word_offset = test_addr[3:2];
            exp_tag_match   = (test_stored_tag == exp_tag);
            exp_hit         = test_stored_valid && exp_tag_match;

            case_failed = 0;
            total_checks = total_checks + 1;

            if (tag !== exp_tag) begin
                $display("FAIL [%s]: Tag mismatch! Addr=0x%08h, Expected Tag=0x%06h, Got=0x%06h",
                         label, test_addr, exp_tag, tag);
                case_failed = 1;
            end

            if (index !== exp_index) begin
                $display("FAIL [%s]: Index mismatch! Addr=0x%08h, Expected Index=0x%02h (%0d), Got=0x%02h (%0d)",
                         label, test_addr, exp_index, exp_index, index, index);
                case_failed = 1;
            end

            if (byte_offset !== exp_byte_offset) begin
                $display("FAIL [%s]: Byte offset mismatch! Addr=0x%08h, Expected Offset=0x%01h, Got=0x%01h",
                         label, test_addr, exp_byte_offset, byte_offset);
                case_failed = 1;
            end

            if (word_offset !== exp_word_offset) begin
                $display("FAIL [%s]: Word offset mismatch! Addr=0x%08h, Expected Word=0x%01h, Got=0x%01h",
                         label, test_addr, exp_word_offset, word_offset);
                case_failed = 1;
            end

            if (tag_match !== exp_tag_match) begin
                $display("FAIL [%s]: Tag match mismatch! Exp=%b, Got=%b (StoredTag=0x%06h, DecodedTag=0x%06h)",
                         label, exp_tag_match, tag_match, test_stored_tag, tag);
                case_failed = 1;
            end

            if (hit !== exp_hit) begin
                $display("FAIL [%s]: Hit mismatch! Exp=%b, Got=%b (Valid=%b, TagMatch=%b)",
                         label, exp_hit, hit, test_stored_valid, tag_match);
                case_failed = 1;
            end

            if (case_failed) begin
                errors = errors + 1;
            end
        end
    endtask

    reg [31:0] rand_addr;
    reg [21:0] rand_tag;
    reg        rand_valid;
    reg        force_hit;

    initial begin
        // Waveform dump for visual inspection
        $dumpfile("sim/waveforms/address_decoder.vcd");
        $dumpvars(0, tb_address_decoder);

        errors = 0;
        total_checks = 0;
        address = 32'h00000000;
        stored_tag = 22'h000000;
        stored_valid = 1'b0;
        #5;

        $display("================================================================");
        $display("   STARTING ADDRESS DECODER & COMPARATOR UNIT TESTBENCH");
        $display("   Author: Aditya Rana | Module: rtl/address_decoder.v");
        $display("================================================================");

        // --------------------------------------------------------------------
        // TEST 1: KNOWN ADDRESS FIELD DECODING
        // --------------------------------------------------------------------
        $display("\nTEST 1: KNOWN ADDRESS FIELD DECODING");
        // Address: 0x12345670 -> Tag = 0x12345670[31:10] = 0x048D15
        //                        Index = 0x12345670[9:4]   = 0x27 (39)
        //                        Word  = 0x12345670[3:2]   = 0x0
        //                        Byte  = 0x12345670[3:0]   = 0x0
        verify_decoder(32'h12345670, 22'h048D15, 1'b1, "T1_KNOWN1");

        // Address: 0xDEADBEE4 -> Tag = 0xDEADBEE4[31:10] = 0x37AB6F
        //                        Index = 0xDEADBEE4[9:4]   = 0x2E (46)
        //                        Word  = 0xDEADBEE4[3:2]   = 0x1
        //                        Byte  = 0xDEADBEE4[3:0]   = 0x4
        verify_decoder(32'hDEADBEE4, 22'h37AB6F, 1'b1, "T1_KNOWN2");

        // Address: 0x00000408 -> Tag = 0x000001
        //                        Index = 0x00
        //                        Word  = 0x2
        //                        Byte  = 0x8
        verify_decoder(32'h00000408, 22'h000001, 1'b1, "T1_KNOWN3");

        // Address: 0xFFFFFFFC -> Tag = 0x3FFFFF
        //                        Index = 0x3F (63)
        //                        Word  = 0x3
        //                        Byte  = 0xC (aligned word 3)
        verify_decoder(32'hFFFFFFFC, 22'h3FFFFF, 1'b1, "T1_KNOWN4");

        if (errors == 0)
            $display("PASS: Field extraction correct for all sample addresses");
        else
            $display("FAIL: Errors detected in known address field decoding");

        // --------------------------------------------------------------------
        // TEST 2: LINE INDEX SWEEP ACROSS ALL 64 CACHE LINES (0 to 63)
        // --------------------------------------------------------------------
        $display("\nTEST 2: LINE INDEX SWEEP ACROSS ALL 64 CACHE LINES (0 TO 63)");
        for (i = 0; i < 64; i = i + 1) begin
            // Place index in bits [9:4], keep tag=0x001234, word=1, byte=4
            verify_decoder({22'h001234, i[5:0], 4'h4}, 22'h001234, 1'b1, "T2_INDEX");
        end
        if (errors == 0)
            $display("PASS: All 64 direct-mapped cache indices decoded correctly");
        else
            $display("FAIL: Errors in index sweep");

        // --------------------------------------------------------------------
        // TEST 3: WORD SELECTOR SWEEP (WORDS 0, 1, 2, 3)
        // --------------------------------------------------------------------
        $display("\nTEST 3: WORD SELECTOR SWEEP (WORDS 0, 1, 2, 3)");
        verify_decoder(32'hA0000000, 22'h280000, 1'b1, "T3_WORD0"); // word 0 (byte 0x0)
        verify_decoder(32'hA0000004, 22'h280000, 1'b1, "T3_WORD1"); // word 1 (byte 0x4)
        verify_decoder(32'hA0000008, 22'h280000, 1'b1, "T3_WORD2"); // word 2 (byte 0x8)
        verify_decoder(32'hA000000C, 22'h280000, 1'b1, "T3_WORD3"); // word 3 (byte 0xC)
        if (errors == 0)
            $display("PASS: Word offsets 0, 1, 2, 3 decoded with 32-bit alignment");
        else
            $display("FAIL: Errors in word selector sweep");

        // --------------------------------------------------------------------
        // TEST 4: CACHE HIT (VALID=1, TAG_MATCH=1)
        // --------------------------------------------------------------------
        $display("\nTEST 4: CACHE HIT EVALUATION (VALID=1, TAG_MATCH=1)");
        verify_decoder(32'h00000000, 22'h000000, 1'b1, "T4_HIT1");
        verify_decoder(32'h55555550, 22'h155555, 1'b1, "T4_HIT2");
        verify_decoder(32'hAAAAAAA0, 22'h2AAAAA, 1'b1, "T4_HIT3");
        verify_decoder(32'hFFFFFFF0, 22'h3FFFFF, 1'b1, "T4_HIT4");
        if (errors == 0)
            $display("PASS: Cache hit asserted when valid=1 and tag matches");
        else
            $display("FAIL: Cache hit evaluation failed");

        // --------------------------------------------------------------------
        // TEST 5: CACHE MISS VIA TAG MISMATCH (VALID=1, TAG_MATCH=0)
        // --------------------------------------------------------------------
        $display("\nTEST 5: CACHE MISS VIA TAG MISMATCH (VALID=1, TAG_MATCH=0)");
        // Same index (0x05), different tags
        verify_decoder(32'h00000050, 22'h000001, 1'b1, "T5_MISS1");
        verify_decoder(32'h00000450, 22'h000000, 1'b1, "T5_MISS2");
        // Inverted tag
        verify_decoder(32'hAAAAAAAA, ~22'h2AAAAA, 1'b1, "T5_MISS3");
        // Tag differing by single LSB (bit 10 of address)
        verify_decoder(32'h00000400, 22'h000000, 1'b1, "T5_MISS4");
        // Tag differing by single MSB (bit 31 of address)
        verify_decoder(32'h80000000, 22'h000000, 1'b1, "T5_MISS5");
        if (errors == 0)
            $display("PASS: Tag match and hit are deasserted on tag mismatch");
        else
            $display("FAIL: Tag mismatch failed to deassert hit");

        // --------------------------------------------------------------------
        // TEST 6: COLD / COMPULSORY MISS (VALID=0, TAG_MATCH=1)
        // --------------------------------------------------------------------
        $display("\nTEST 6: COLD / COMPULSORY MISS (VALID=0, TAG_MATCH=1)");
        // Even if the stored tag matches the address tag, stored_valid=0 must suppress hit!
        verify_decoder(32'h00000000, 22'h000000, 1'b0, "T6_COLD1");
        verify_decoder(32'h12345670, 22'h048D15, 1'b0, "T6_COLD2");
        verify_decoder(32'hFFFFFFF0, 22'h3FFFFF, 1'b0, "T6_COLD3");
        if (errors == 0)
            $display("PASS: Stored valid=0 correctly suppresses hit even when tags match");
        else
            $display("FAIL: Cold miss handling failed (hit asserted when valid=0)");

        // --------------------------------------------------------------------
        // TEST 7: INVALID LINE AND TAG MISMATCH (VALID=0, TAG_MATCH=0)
        // --------------------------------------------------------------------
        $display("\nTEST 7: INVALID LINE AND TAG MISMATCH (VALID=0, TAG_MATCH=0)");
        verify_decoder(32'h12345670, 22'h3FFFFF, 1'b0, "T7_INVMIS1");
        verify_decoder(32'h00000000, 22'h000001, 1'b0, "T7_INVMIS2");
        if (errors == 0)
            $display("PASS: tag_match=0 and hit=0 when both valid=0 and tag mismatch");
        else
            $display("FAIL: Errors on invalid line with tag mismatch");

        // --------------------------------------------------------------------
        // TEST 8: TAG BIT ISOLATION (WALKING 1s AND WALKING 0s ACROSS ALL 22 TAG BITS)
        // --------------------------------------------------------------------
        $display("\nTEST 8: TAG BIT ISOLATION (WALKING 1s AND 0s)");
        // Walking 1: ensure every single bit of the 22-bit tag comparator is connected
        for (i = 0; i < 22; i = i + 1) begin
            // Address with single bit set in tag field [31:10]
            verify_decoder({ (22'b1 << i), 6'd10, 4'd0 }, (22'b1 << i), 1'b1, "T8_WALK1_HIT");
            // Mismatch against all-zero tag
            verify_decoder({ (22'b1 << i), 6'd10, 4'd0 }, 22'h000000, 1'b1, "T8_WALK1_MISS");
        end

        // Walking 0: ensure no stuck-at-1 bits
        for (i = 0; i < 22; i = i + 1) begin
            verify_decoder({ ~(22'b1 << i), 6'd20, 4'd0 }, ~(22'b1 << i), 1'b1, "T8_WALK0_HIT");
            verify_decoder({ ~(22'b1 << i), 6'd20, 4'd0 }, 22'h3FFFFF, 1'b1, "T8_WALK0_MISS");
        end
        if (errors == 0)
            $display("PASS: All 22 tag bits independently verified (no shorts or stuck bits)");
        else
            $display("FAIL: Tag bit isolation failed");

        // --------------------------------------------------------------------
        // TEST 9: RAPID COMBINATIONAL PROPAGATION / SETTLING
        // --------------------------------------------------------------------
        $display("\nTEST 9: COMBINATIONAL SETTLING AND ZERO-LATENCY PROPAGATION");
        // Verify immediate response to address changes without any clock
        address = 32'hCAFE0000;
        stored_tag = 22'h32BF80;
        stored_valid = 1'b1;
        #1;
        if (hit !== 1'b1 || tag_match !== 1'b1 || index !== 6'd0) begin
            $display("FAIL: Combinational evaluation step 1 failed");
            errors = errors + 1;
        end

        // Flip validity immediately
        stored_valid = 1'b0;
        #1;
        if (hit !== 1'b0 || tag_match !== 1'b1) begin
            $display("FAIL: Valid deassertion did not immediately deassert hit");
            errors = errors + 1;
        end

        // Change address immediately
        address = 32'hBABE0014; // Index=1, Word=1, Byte=4
        #1;
        if (index !== 6'd1 || word_offset !== 2'd1 || byte_offset !== 4'd4 || tag_match !== 1'b0) begin
            $display("FAIL: Immediate address change not reflected on outputs");
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: Purely combinational propagation confirmed");
        else
            $display("FAIL: Combinational settling errors");

        // --------------------------------------------------------------------
        // TEST 10: RANDOMIZED STRESS TEST WITH PSEUDO-RANDOM VECTORS
        // --------------------------------------------------------------------
        $display("\nTEST 10: RANDOMIZED STRESS TEST (200 RANDOM VECTORS)");
        for (i = 0; i < 200; i = i + 1) begin
            rand_addr  = $random;
            // Ensure 32-bit word aligned lower 2 bits
            rand_addr[1:0] = 2'b00;
            rand_valid = $random;
            force_hit  = $random;

            if (force_hit) begin
                // Match tag to test hit behavior
                rand_tag = rand_addr[31:10];
            end else begin
                rand_tag = $random;
            end

            verify_decoder(rand_addr, rand_tag, rand_valid, "T10_RAND");
        end

        if (errors == 0)
            $display("PASS: 200 random vectors passed self-checking reference model");
        else
            $display("FAIL: Errors found during randomized stress testing");

        // --------------------------------------------------------------------
        // FINAL SUMMARY REPORT
        // --------------------------------------------------------------------
        $display("\n================================================================");
        $display("   ADDRESS DECODER UNIT VERIFICATION REPORT");
        $display("================================================================");
        $display("TOTAL CHECKS EXECUTED : %0d", total_checks);
        $display("TOTAL ERRORS DETECTED : %0d", errors);

        if (errors == 0) begin
            $display("\nFINAL RESULT: ALL 10 TEST SUITES PASSED SUCCESSFULLY!");
            $display("RTL Module: rtl/address_decoder.v is fully verified.");
        end else begin
            $display("\nFINAL RESULT: VERIFICATION FAILED WITH %0d ERRORS!", errors);
        end
        $display("================================================================\n");

        $finish;
    end

endmodule
