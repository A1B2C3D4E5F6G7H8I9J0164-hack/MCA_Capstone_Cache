
`timescale 1ns/1ps

module main_memory_model #(
    parameter ADDR_WIDTH = 32,
    parameter MEM_WORDS  = 4096,
    parameter LATENCY    = 5
)(
    input wire clk,
    input wire reset,

    // Memory request interface
    input wire req,
    input wire write_en,

    // Address and write data
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [31:0] write_data,

    // Memory response interface
    output reg ready,
    output reg [127:0] block_data
);

    // -----------------------------------------
    // 1. MAIN MEMORY ARRAY
    // -----------------------------------------

    // 4096 words x 32 bits = 16 KB

    reg [31:0] mem [0:MEM_WORDS-1];


    // -----------------------------------------
    // 2. FSM STATES
    // -----------------------------------------

    localparam IDLE = 1'b0;
    localparam WAIT = 1'b1;

    reg state;


    // -----------------------------------------
    // 3. REQUEST REGISTERS
    // -----------------------------------------

    reg [ADDR_WIDTH-1:0] saved_addr;
    reg [31:0] saved_write_data;
    reg saved_write_en;

    integer latency_count;
    integer i;


    // -----------------------------------------
    // 4. MEMORY INITIALIZATION
    // -----------------------------------------

    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1)
            mem[i] = 32'h00000000;
    end


    // -----------------------------------------
    // 5. MAIN MEMORY FSM
    // -----------------------------------------

    always @(posedge clk) begin

        if (reset) begin

            state <= IDLE;
            ready <= 1'b0;

            block_data <= 128'b0;

            saved_addr <= 0;
            saved_write_data <= 0;
            saved_write_en <= 0;

            latency_count <= 0;

        end

        else begin

            case (state)

                // =================================
                // IDLE STATE
                // Accept a new request
                // =================================

                IDLE: begin

                    ready <= 1'b0;

                    if (req) begin

                        saved_addr <= addr;
                        saved_write_data <= write_data;
                        saved_write_en <= write_en;

                        latency_count <= (LATENCY > 0) ?
                                         LATENCY : 1;

                        state <= WAIT;

                    end

                end


                // =================================
                // WAIT STATE
                // Wait for configured latency
                // =================================

                WAIT: begin

                    if (latency_count > 1) begin

                        latency_count <= latency_count - 1;

                    end

                    else begin

                        // -------------------------
                        // WRITE OPERATION
                        // -------------------------

                        if (saved_write_en) begin

                            mem[saved_addr[ADDR_WIDTH-1:2]
                                % MEM_WORDS] <= saved_write_data;

                        end

                        // -------------------------
                        // BLOCK READ OPERATION
                        // -------------------------

                        else begin

                            // Four consecutive words
                            // from aligned 16-byte block

                            block_data[31:0] <=
                                mem[((saved_addr >> 2) / 4 * 4 + 0)
                                    % MEM_WORDS];

                            block_data[63:32] <=
                                mem[((saved_addr >> 2) / 4 * 4 + 1)
                                    % MEM_WORDS];

                            block_data[95:64] <=
                                mem[((saved_addr >> 2) / 4 * 4 + 2)
                                    % MEM_WORDS];

                            block_data[127:96] <=
                                mem[((saved_addr >> 2) / 4 * 4 + 3)
                                    % MEM_WORDS];

                        end

                        // Signal completion
                        ready <= 1'b1;

                        // Return to idle
                        state <= IDLE;

                    end

                end


                // =================================
                // DEFAULT STATE
                // =================================

                default: begin

                    state <= IDLE;
                    ready <= 1'b0;

                end

            endcase

        end

    end

endmodule
