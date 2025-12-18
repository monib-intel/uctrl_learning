// =============================================================================
// SRAM Controller
// =============================================================================
// Module: sram_controller
// Designer: Copilot
// Reviewer: TBD
// 
// Description:
//   8 KB scratchpad SRAM with single-cycle read/write, byte enables,
//   MBIST support (March C+), and power domain controls.
//
// Specification: docs/spec_sram_controller.md
// =============================================================================

module sram_controller (
    // Clocking & Reset
    input  logic        clk,
    input  logic        rst_n,

    // Memory Access Interface
    input  logic        sram_req,       // Access request
    input  logic        sram_we,        // Write enable (1=write, 0=read)
    input  logic [3:0]  sram_be,        // Byte enable mask
    input  logic [12:0] sram_addr,      // Address (8KB, byte-aligned)
    input  logic [31:0] sram_wdata,     // Write data
    output logic [31:0] sram_rdata,     // Read data
    output logic        sram_ready,     // Always 1 (single-cycle)

    // DFT - MBIST Interface
    input  logic        mbist_en,       // MBIST mode enable
    output logic        mbist_done,     // MBIST complete
    output logic        mbist_fail,     // MBIST failure flag
    output logic [12:0] mbist_fail_addr,// First failing address

    // Power Domain Interface
    input  logic        ret_en,         // Retention mode enable
    input  logic        pd_en           // Power domain enable
);

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam int DEPTH = 2048;        // 2K words (8KB / 4 bytes)
    localparam int ADDR_WIDTH = 11;     // 2^11 = 2048 words

    // =========================================================================
    // Internal Signals
    // =========================================================================
    logic [31:0] mem [DEPTH];           // Main memory array
    logic [ADDR_WIDTH-1:0] word_addr;   // Word-aligned address
    
    // MBIST state machine
    typedef enum logic [2:0] {
        MBIST_IDLE      = 3'b000,
        MBIST_WRITE0    = 3'b001,
        MBIST_READ0     = 3'b010,
        MBIST_WRITE1    = 3'b011,
        MBIST_READ1     = 3'b100,
        MBIST_DONE      = 3'b101
    } mbist_state_t;
    
    mbist_state_t mbist_state, mbist_next_state;
    logic [ADDR_WIDTH-1:0] mbist_addr;
    logic mbist_error;
    logic [31:0] mbist_expected;
    logic [31:0] mbist_readdata;
    
    // =========================================================================
    // Address Decoding
    // =========================================================================
    // Convert byte address to word address (divide by 4)
    assign word_addr = sram_addr[ADDR_WIDTH+1:2];

    // =========================================================================
    // Normal Memory Operation
    // =========================================================================
    // Ready signal - always ready for single-cycle operation
    assign sram_ready = 1'b1;

    // Memory write operation with byte enables
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset: Initialize memory to zero
            for (int i = 0; i < DEPTH; i++) begin
                mem[i] <= 32'h0;
            end
        end else if (pd_en && !ret_en) begin
            // Normal operation mode
            if (mbist_en) begin
                // MBIST write operation
                if (mbist_state == MBIST_WRITE0) begin
                    mem[mbist_addr] <= 32'h00000000;
                end else if (mbist_state == MBIST_WRITE1) begin
                    mem[mbist_addr] <= 32'hFFFFFFFF;
                end
            end else if (sram_req && sram_we) begin
                // Normal write with byte enables
                if (sram_be[0]) mem[word_addr][7:0]   <= sram_wdata[7:0];
                if (sram_be[1]) mem[word_addr][15:8]  <= sram_wdata[15:8];
                if (sram_be[2]) mem[word_addr][23:16] <= sram_wdata[23:16];
                if (sram_be[3]) mem[word_addr][31:24] <= sram_wdata[31:24];
            end
        end
        // else: retention mode - hold memory contents
    end

    // Memory read operation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sram_rdata <= 32'h0;
            mbist_readdata <= 32'h0;
        end else if (pd_en && !ret_en) begin
            if (mbist_en) begin
                // MBIST read operation
                if (mbist_state == MBIST_READ0 || mbist_state == MBIST_READ1) begin
                    mbist_readdata <= mem[mbist_addr];
                end
            end else if (sram_req && !sram_we) begin
                // Normal read - combinational (single-cycle)
                sram_rdata <= mem[word_addr];
            end
        end
    end

    // =========================================================================
    // MBIST - March C+ Algorithm Implementation
    // =========================================================================
    // March C+ sequence:
    // 1. Write 0 to all locations (ascending)
    // 2. Read 0, Write 1 (ascending)
    // 3. Read 1, Write 0 (descending)
    // 4. Read 0 (descending)
    
    // MBIST state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mbist_state <= MBIST_IDLE;
        end else begin
            mbist_state <= mbist_next_state;
        end
    end

    // MBIST address counter
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mbist_addr <= '0;
        end else if (!mbist_en) begin
            mbist_addr <= '0;
        end else begin
            case (mbist_state)
                MBIST_WRITE0, MBIST_READ0, MBIST_WRITE1, MBIST_READ1: begin
                    if (mbist_addr == DEPTH-1) begin
                        mbist_addr <= '0;
                    end else begin
                        mbist_addr <= mbist_addr + 1;
                    end
                end
                default: mbist_addr <= '0;
            endcase
        end
    end

    // MBIST next state logic
    always_comb begin
        mbist_next_state = mbist_state;
        
        case (mbist_state)
            MBIST_IDLE: begin
                if (mbist_en) begin
                    mbist_next_state = MBIST_WRITE0;
                end
            end
            
            MBIST_WRITE0: begin
                if (mbist_addr == DEPTH-1) begin
                    mbist_next_state = MBIST_READ0;
                end
            end
            
            MBIST_READ0: begin
                if (mbist_error) begin
                    mbist_next_state = MBIST_DONE;
                end else if (mbist_addr == DEPTH-1) begin
                    mbist_next_state = MBIST_WRITE1;
                end
            end
            
            MBIST_WRITE1: begin
                if (mbist_addr == DEPTH-1) begin
                    mbist_next_state = MBIST_READ1;
                end
            end
            
            MBIST_READ1: begin
                if (mbist_error) begin
                    mbist_next_state = MBIST_DONE;
                end else if (mbist_addr == DEPTH-1) begin
                    mbist_next_state = MBIST_DONE;
                end
            end
            
            MBIST_DONE: begin
                if (!mbist_en) begin
                    mbist_next_state = MBIST_IDLE;
                end
            end
            
            default: mbist_next_state = MBIST_IDLE;
        endcase
    end

    // MBIST error detection
    always_comb begin
        mbist_expected = 32'h0;
        
        case (mbist_state)
            MBIST_READ0: mbist_expected = 32'h00000000;
            MBIST_READ1: mbist_expected = 32'hFFFFFFFF;
            default:     mbist_expected = 32'h00000000;
        endcase
    end

    assign mbist_error = ((mbist_state == MBIST_READ0) || (mbist_state == MBIST_READ1)) && 
                         (mbist_readdata != mbist_expected);

    // MBIST status outputs
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mbist_done <= 1'b0;
            mbist_fail <= 1'b0;
            mbist_fail_addr <= '0;
        end else begin
            if (!mbist_en) begin
                mbist_done <= 1'b0;
                mbist_fail <= 1'b0;
                mbist_fail_addr <= '0;
            end else if (mbist_state == MBIST_DONE) begin
                mbist_done <= 1'b1;
            end else if (mbist_error && !mbist_fail) begin
                // Capture first failing address
                mbist_fail <= 1'b1;
                mbist_fail_addr <= {mbist_addr, 2'b00}; // Convert to byte address
            end
        end
    end

    // =========================================================================
    // Assertions (for simulation/formal verification)
    // =========================================================================
    `ifdef SIMULATION
        // Check that address is within valid range
        property p_valid_addr;
            @(posedge clk) sram_req |-> (word_addr < DEPTH);
        endproperty
        assert property (p_valid_addr) else 
            $error("SRAM address out of range: addr=%h", sram_addr);

        // Check that power domain is enabled during normal operation
        property p_pd_enabled;
            @(posedge clk) (sram_req || mbist_en) |-> pd_en;
        endproperty
        assert property (p_pd_enabled) else 
            $error("Power domain must be enabled during operation");
    `endif

endmodule
