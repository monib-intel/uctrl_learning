// =============================================================================
// Clock & Reset Manager
// =============================================================================
// Module: clock_reset_manager
// Designer: Copilot
// Reviewer: Microarchitecture Lead
// 
// Description:
//   Manages clock domains, gating, and reset synchronization across TCP.
//   - 3 clock domains: CPU, Test, Reference
//   - Clock gating with ICG cells
//   - 3 reset domains with 2-stage synchronizers
//   - 256-cycle cold reset debounce
//   - 16-cycle staged reset release
//
// Specification: docs/spec_clock_reset_manager.md
// =============================================================================

module clock_reset_manager (
    // =========================================================================
    // External Inputs
    // =========================================================================
    input  logic       clk_ref,        // Reference clock (crystal)
    input  logic       pll_clk,        // PLL output (optional)
    input  logic       por_n,          // Power-on reset
    input  logic       rst_ext_n,      // External reset pin

    // =========================================================================
    // Clock Outputs
    // =========================================================================
    output logic       clk_cpu,        // CPU domain clock
    output logic       clk_test,       // Test/JTAG domain clock

    // =========================================================================
    // Reset Outputs
    // =========================================================================
    output logic       rst_cold_n,     // Cold reset (all domains)
    output logic       rst_cpu_n,      // CPU reset
    output logic       rst_test_n,     // Test logic reset

    // =========================================================================
    // Control
    // =========================================================================
    input  logic       clk_gate_en,    // Enable clock gating
    input  logic [2:0] clk_div_sel,    // Clock divider (÷1, ÷2, ÷4, ÷8)
    input  logic       test_mode,      // Force clocks on

    // =========================================================================
    // Status
    // =========================================================================
    input  logic       pll_locked,     // PLL lock indicator
    output logic       rst_done        // Reset sequence complete
);

    // =========================================================================
    // Internal Signals
    // =========================================================================
    
    // Clock generation
    logic        clk_cpu_pre_gate;     // CPU clock before gating
    logic        clk_cpu_divided;      // Divided CPU clock
    
    // ICG (Integrated Clock Gate) signals
    logic        icg_enable;           // Combined enable for ICG
    logic        icg_enable_latched;   // Latched enable for glitch-free gating
    
    // Reset FSM
    typedef enum logic [2:0] {
        RST_ASSERT,         // All resets asserted
        RST_DEBOUNCE,       // Debouncing cold reset
        RST_COLD_RELEASE,   // Cold reset released
        RST_STAGE_DELAY,    // Delay before releasing domain resets
        RST_DOMAIN_RELEASE, // Domain resets released
        RST_COMPLETE        // Reset sequence complete
    } reset_state_t;
    
    reset_state_t rst_state;
    logic [8:0]  rst_counter;          // Reset sequence counter (up to 256 cycles)
    
    // Reset synchronizers (2-stage per domain)
    logic [1:0]  rst_cold_sync;        // Cold reset synchronizer
    logic [1:0]  rst_cpu_sync;         // CPU reset synchronizer
    logic [1:0]  rst_test_sync;        // Test reset synchronizer
    
    // Internal async reset signals
    logic        rst_cold_async;       // Async cold reset
    logic        rst_cpu_async;        // Async CPU reset
    logic        rst_test_async;       // Async test reset

    // =========================================================================
    // Clock Divider Logic
    // =========================================================================
    
    // Clock divider - toggle flip-flops for 50% duty cycle
    // NOTE: This creates actual clock domains per specification
    // The cascaded dividers create clean divided clocks with 50% duty cycle
    // For single-domain designs, consider enable-based counters instead
    logic clk_div2, clk_div4, clk_div8;
    
    // Divide by 2 (toggle at pll_clk rate)
    always_ff @(posedge pll_clk or negedge por_n) begin
        if (!por_n) begin
            clk_div2 <= 1'b0;
        end else begin
            clk_div2 <= ~clk_div2;
        end
    end
    
    // Divide by 4 (toggle at clk_div2 rate)
    always_ff @(posedge clk_div2 or negedge por_n) begin
        if (!por_n) begin
            clk_div4 <= 1'b0;
        end else begin
            clk_div4 <= ~clk_div4;
        end
    end
    
    // Divide by 8 (toggle at clk_div4 rate)
    always_ff @(posedge clk_div4 or negedge por_n) begin
        if (!por_n) begin
            clk_div8 <= 1'b0;
        end else begin
            clk_div8 <= ~clk_div8;
        end
    end
    
    // Clock divider MUX
    always_comb begin
        case (clk_div_sel)
            3'b000:  clk_cpu_divided = pll_clk;              // ÷1
            3'b001:  clk_cpu_divided = clk_div2;             // ÷2
            3'b010:  clk_cpu_divided = clk_div4;             // ÷4
            3'b011:  clk_cpu_divided = clk_div8;             // ÷8
            default: clk_cpu_divided = pll_clk;              // Default ÷1
        endcase
    end
    
    // Clock source selection (PLL or ref in test mode)
    assign clk_cpu_pre_gate = test_mode ? clk_ref : clk_cpu_divided;

    // =========================================================================
    // ICG (Integrated Clock Gate) Cell
    // =========================================================================
    
    // ICG enable logic: gate when clk_gate_en=1 AND not in test_mode
    // When test_mode=1, force clocks on (disable gating)
    assign icg_enable = !clk_gate_en || test_mode;
    
    // Latch enable on negative phase to avoid glitches
    // NOTE: always_latch is used here for simulation and clarity
    // In production synthesis, replace with vendor-specific ICG cells such as:
    // - SKY130: sky130_fd_sc_hd__dlclkp_1
    // - Intel: CKLNQD12 or equivalent
    // - ARM: TLATNCAX or equivalent ICG cell
    always_latch begin
        if (!clk_cpu_pre_gate) begin
            icg_enable_latched = icg_enable;
        end
    end
    
    // Gated clock output: AND gate with latched enable
    // When icg_enable_latched=1, clock passes through
    // When icg_enable_latched=0, clock is gated (output 0)
    assign clk_cpu = icg_enable_latched & clk_cpu_pre_gate;
    
    // Test clock: derived from reference clock (simplified - in real design may come from JTAG TCK)
    assign clk_test = clk_ref;

    // =========================================================================
    // Reset FSM
    // =========================================================================
    
    always_ff @(posedge clk_ref or negedge por_n) begin
        if (!por_n) begin
            rst_state     <= RST_ASSERT;
            rst_counter   <= 9'd0;
            rst_cold_async <= 1'b0;
            rst_cpu_async  <= 1'b0;
            rst_test_async <= 1'b0;
            rst_done      <= 1'b0;
        end else if (!rst_ext_n) begin
            // External reset forces back to ASSERT state
            rst_state     <= RST_ASSERT;
            rst_counter   <= 9'd0;
            rst_cold_async <= 1'b0;
            rst_cpu_async  <= 1'b0;
            rst_test_async <= 1'b0;
            rst_done      <= 1'b0;
        end else begin
            case (rst_state)
                RST_ASSERT: begin
                    // Wait for PLL lock before proceeding
                    if (pll_locked) begin
                        rst_state   <= RST_DEBOUNCE;
                        rst_counter <= 9'd0;
                    end
                    rst_cold_async <= 1'b0;
                    rst_cpu_async  <= 1'b0;
                    rst_test_async <= 1'b0;
                    rst_done       <= 1'b0;
                end
                
                RST_DEBOUNCE: begin
                    // Hold cold reset for 256 clk_ref cycles
                    if (rst_counter == 9'd255) begin
                        rst_state   <= RST_COLD_RELEASE;
                        rst_counter <= 9'd0;
                    end else begin
                        rst_counter <= rst_counter + 1'b1;
                    end
                    rst_cold_async <= 1'b0;
                    rst_cpu_async  <= 1'b0;
                    rst_test_async <= 1'b0;
                end
                
                RST_COLD_RELEASE: begin
                    // Release cold reset
                    rst_state      <= RST_STAGE_DELAY;
                    rst_counter    <= 9'd0;
                    rst_cold_async <= 1'b1;
                    rst_cpu_async  <= 1'b0;
                    rst_test_async <= 1'b0;
                end
                
                RST_STAGE_DELAY: begin
                    // Wait 16 cycles before releasing domain resets
                    if (rst_counter == 9'd15) begin
                        rst_state   <= RST_DOMAIN_RELEASE;
                        rst_counter <= 9'd0;
                    end else begin
                        rst_counter <= rst_counter + 1'b1;
                    end
                    rst_cpu_async  <= 1'b0;
                    rst_test_async <= 1'b0;
                end
                
                RST_DOMAIN_RELEASE: begin
                    // Release CPU and Test resets
                    rst_state      <= RST_COMPLETE;
                    rst_cpu_async  <= 1'b1;
                    rst_test_async <= 1'b1;
                end
                
                RST_COMPLETE: begin
                    // Reset sequence complete
                    rst_done <= 1'b1;
                end
                
                default: begin
                    rst_state <= RST_ASSERT;
                end
            endcase
        end
    end

    // =========================================================================
    // 2-Stage Reset Synchronizers
    // =========================================================================
    
    // Cold reset synchronizer (clocked by clk_ref)
    always_ff @(posedge clk_ref or negedge rst_cold_async) begin
        if (!rst_cold_async) begin
            rst_cold_sync <= 2'b00;
        end else begin
            rst_cold_sync <= {rst_cold_sync[0], 1'b1};
        end
    end
    assign rst_cold_n = rst_cold_sync[1];
    
    // CPU reset synchronizer (clocked by clk_cpu_pre_gate to avoid gating issues)
    always_ff @(posedge clk_cpu_pre_gate or negedge rst_cpu_async) begin
        if (!rst_cpu_async) begin
            rst_cpu_sync <= 2'b00;
        end else begin
            rst_cpu_sync <= {rst_cpu_sync[0], 1'b1};
        end
    end
    assign rst_cpu_n = rst_cpu_sync[1];
    
    // Test reset synchronizer (clocked by clk_test)
    always_ff @(posedge clk_test or negedge rst_test_async) begin
        if (!rst_test_async) begin
            rst_test_sync <= 2'b00;
        end else begin
            rst_test_sync <= {rst_test_sync[0], 1'b1};
        end
    end
    assign rst_test_n = rst_test_sync[1];

endmodule
