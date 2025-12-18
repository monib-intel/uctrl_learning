// =============================================================================
// APB Interconnect
// =============================================================================
// Module: apb_interconnect
// Designer: Copilot
// Reviewer: Microarchitecture Lead
//
// Description:
//   Simple peripheral bus interconnect. 1 master (CPU), 5 slaves.
//   Slaves: ROM (32KB), Flash (128KB), SRAM (8KB), Control Regs, Diag Buffer
//   APB4 compatible with error handling for unmapped addresses.
//
// Specification: docs/spec_apb_interconnect.md
// =============================================================================

module apb_interconnect (
    // Clocking & Reset
    input  logic        pclk,
    input  logic        preset_n,

    // Master Port (from CPU)
    input  logic [31:0] m_paddr,
    input  logic        m_psel,
    input  logic        m_penable,
    input  logic        m_pwrite,
    input  logic [31:0] m_pwdata,
    input  logic [3:0]  m_pstrb,
    output logic        m_pready,
    output logic [31:0] m_prdata,
    output logic        m_pslverr,

    // Slave 0: ROM (0x0000_0000 - 0x0000_7FFF, 32KB)
    output logic [31:0] s0_paddr,
    output logic        s0_psel,
    output logic        s0_penable,
    output logic        s0_pwrite,
    output logic [31:0] s0_pwdata,
    output logic [3:0]  s0_pstrb,
    input  logic        s0_pready,
    input  logic [31:0] s0_prdata,
    input  logic        s0_pslverr,

    // Slave 1: Flash (0x0000_8000 - 0x0002_7FFF, 128KB)
    output logic [31:0] s1_paddr,
    output logic        s1_psel,
    output logic        s1_penable,
    output logic        s1_pwrite,
    output logic [31:0] s1_pwdata,
    output logic [3:0]  s1_pstrb,
    input  logic        s1_pready,
    input  logic [31:0] s1_prdata,
    input  logic        s1_pslverr,

    // Slave 2: SRAM (0x0002_8000 - 0x0002_9FFF, 8KB)
    output logic [31:0] s2_paddr,
    output logic        s2_psel,
    output logic        s2_penable,
    output logic        s2_pwrite,
    output logic [31:0] s2_pwdata,
    output logic [3:0]  s2_pstrb,
    input  logic        s2_pready,
    input  logic [31:0] s2_prdata,
    input  logic        s2_pslverr,

    // Slave 3: Control Registers (0x0002_A000 - 0x0002_AFFF, 4KB)
    output logic [31:0] s3_paddr,
    output logic        s3_psel,
    output logic        s3_penable,
    output logic        s3_pwrite,
    output logic [31:0] s3_pwdata,
    output logic [3:0]  s3_pstrb,
    input  logic        s3_pready,
    input  logic [31:0] s3_prdata,
    input  logic        s3_pslverr,

    // Slave 4: Diagnostic Buffer (0x0002_B000 - 0x0002_BFFF, 4KB)
    output logic [31:0] s4_paddr,
    output logic        s4_psel,
    output logic        s4_penable,
    output logic        s4_pwrite,
    output logic [31:0] s4_pwdata,
    output logic [3:0]  s4_pstrb,
    input  logic        s4_pready,
    input  logic [31:0] s4_prdata,
    input  logic        s4_pslverr
);

    // =========================================================================
    // Address Decode Parameters
    // =========================================================================
    // Address ranges per specification
    localparam logic [31:0] ROM_BASE   = 32'h0000_0000;  // 0x0000_0000
    localparam logic [31:0] ROM_LIMIT  = 32'h0000_7FFF;  // 32KB
    
    localparam logic [31:0] FLASH_BASE = 32'h0000_8000;  // 0x0000_8000
    localparam logic [31:0] FLASH_LIMIT = 32'h0002_7FFF; // 128KB
    
    localparam logic [31:0] SRAM_BASE  = 32'h0002_8000;  // 0x0002_8000
    localparam logic [31:0] SRAM_LIMIT = 32'h0002_9FFF;  // 8KB
    
    localparam logic [31:0] CTRL_BASE  = 32'h0002_A000;  // 0x0002_A000
    localparam logic [31:0] CTRL_LIMIT = 32'h0002_AFFF;  // 4KB
    
    localparam logic [31:0] DIAG_BASE  = 32'h0002_B000;  // 0x0002_B000
    localparam logic [31:0] DIAG_LIMIT = 32'h0002_BFFF;  // 4KB

    // =========================================================================
    // Internal Signals
    // =========================================================================
    logic [4:0] slave_sel;      // One-hot slave selection
    logic [4:0] slave_sel_reg;  // Registered slave selection for ACCESS phase
    logic       unmapped;       // Unmapped address flag
    logic       unmapped_reg;   // Registered unmapped flag

    // =========================================================================
    // Address Decoder (Combinational)
    // =========================================================================
    // Decode address during SETUP phase (when m_psel is asserted)
    always_comb begin
        slave_sel = 5'b00000;
        unmapped = 1'b0;

        if (m_psel) begin
            // Check each address range
            if (m_paddr >= ROM_BASE && m_paddr <= ROM_LIMIT) begin
                slave_sel[0] = 1'b1;  // ROM
            end else if (m_paddr >= FLASH_BASE && m_paddr <= FLASH_LIMIT) begin
                slave_sel[1] = 1'b1;  // Flash
            end else if (m_paddr >= SRAM_BASE && m_paddr <= SRAM_LIMIT) begin
                slave_sel[2] = 1'b1;  // SRAM
            end else if (m_paddr >= CTRL_BASE && m_paddr <= CTRL_LIMIT) begin
                slave_sel[3] = 1'b1;  // Control Registers
            end else if (m_paddr >= DIAG_BASE && m_paddr <= DIAG_LIMIT) begin
                slave_sel[4] = 1'b1;  // Diagnostic Buffer
            end else begin
                unmapped = 1'b1;      // Unmapped address
            end
        end
    end

    // =========================================================================
    // Register Slave Selection (SETUP -> ACCESS phase)
    // =========================================================================
    // Capture slave selection at the end of SETUP phase
    always_ff @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
            slave_sel_reg <= 5'b00000;
            unmapped_reg  <= 1'b0;
        end else begin
            if (m_psel && !m_penable) begin
                // SETUP phase - register the decoded slave
                slave_sel_reg <= slave_sel;
                unmapped_reg  <= unmapped;
            end else if (!m_psel) begin
                // Idle - clear selection
                slave_sel_reg <= 5'b00000;
                unmapped_reg  <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Slave Port Assignments
    // =========================================================================
    // Broadcast address, write data, and strobe to all slaves
    // Use registered selection for psel to maintain stability during transaction
    // penable is gated by both m_penable and registered selection
    
    // ROM (Slave 0)
    assign s0_paddr   = m_paddr;
    assign s0_psel    = m_psel && (slave_sel[0] || slave_sel_reg[0]);
    assign s0_penable = m_penable && slave_sel_reg[0];
    assign s0_pwrite  = m_pwrite;
    assign s0_pwdata  = m_pwdata;
    assign s0_pstrb   = m_pstrb;

    // Flash (Slave 1)
    assign s1_paddr   = m_paddr;
    assign s1_psel    = m_psel && (slave_sel[1] || slave_sel_reg[1]);
    assign s1_penable = m_penable && slave_sel_reg[1];
    assign s1_pwrite  = m_pwrite;
    assign s1_pwdata  = m_pwdata;
    assign s1_pstrb   = m_pstrb;

    // SRAM (Slave 2)
    assign s2_paddr   = m_paddr;
    assign s2_psel    = m_psel && (slave_sel[2] || slave_sel_reg[2]);
    assign s2_penable = m_penable && slave_sel_reg[2];
    assign s2_pwrite  = m_pwrite;
    assign s2_pwdata  = m_pwdata;
    assign s2_pstrb   = m_pstrb;

    // Control Registers (Slave 3)
    assign s3_paddr   = m_paddr;
    assign s3_psel    = m_psel && (slave_sel[3] || slave_sel_reg[3]);
    assign s3_penable = m_penable && slave_sel_reg[3];
    assign s3_pwrite  = m_pwrite;
    assign s3_pwdata  = m_pwdata;
    assign s3_pstrb   = m_pstrb;

    // Diagnostic Buffer (Slave 4)
    assign s4_paddr   = m_paddr;
    assign s4_psel    = m_psel && (slave_sel[4] || slave_sel_reg[4]);
    assign s4_penable = m_penable && slave_sel_reg[4];
    assign s4_pwrite  = m_pwrite;
    assign s4_pwdata  = m_pwdata;
    assign s4_pstrb   = m_pstrb;

    // =========================================================================
    // Master Port Response Multiplexing
    // =========================================================================
    // Multiplex slave responses back to master based on registered selection
    always_comb begin
        // Default values for unmapped addresses
        m_pready  = 1'b0;
        m_prdata  = 32'h0;
        m_pslverr = 1'b0;

        if (m_penable) begin
            // ACCESS phase - use registered selection
            if (unmapped_reg) begin
                // Unmapped address - return error immediately
                m_pready  = 1'b1;
                m_prdata  = 32'h0;
                m_pslverr = 1'b1;
            end else begin
                // Valid slave - multiplex response
                case (slave_sel_reg)
                    5'b00001: begin  // ROM
                        m_pready  = s0_pready;
                        m_prdata  = s0_prdata;
                        m_pslverr = s0_pslverr;
                    end
                    5'b00010: begin  // Flash
                        m_pready  = s1_pready;
                        m_prdata  = s1_prdata;
                        m_pslverr = s1_pslverr;
                    end
                    5'b00100: begin  // SRAM
                        m_pready  = s2_pready;
                        m_prdata  = s2_prdata;
                        m_pslverr = s2_pslverr;
                    end
                    5'b01000: begin  // Control Registers
                        m_pready  = s3_pready;
                        m_prdata  = s3_prdata;
                        m_pslverr = s3_pslverr;
                    end
                    5'b10000: begin  // Diagnostic Buffer
                        m_pready  = s4_pready;
                        m_prdata  = s4_prdata;
                        m_pslverr = s4_pslverr;
                    end
                    default: begin
                        // Should not happen (unmapped is checked above)
                        // Defensive code to catch unexpected conditions
                        m_pready  = 1'b1;
                        m_prdata  = 32'h0;
                        m_pslverr = 1'b1;
                        `ifdef SIMULATION
                            $error("APB Interconnect: Invalid slave selection state 0x%b", slave_sel_reg);
                        `endif
                    end
                endcase
            end
        end
    end

    // =========================================================================
    // Assertions (for simulation/formal verification)
    // =========================================================================
    `ifdef SIMULATION
        // Only one slave should be selected at a time
        property p_one_hot_slave_sel;
            @(posedge pclk) m_psel |-> $onehot0(slave_sel);
        endproperty
        assert property (p_one_hot_slave_sel) else
            $error("APB Interconnect: Multiple slaves selected simultaneously");

        // Penable should only be asserted after psel
        property p_penable_after_psel;
            @(posedge pclk) m_penable |-> $past(m_psel);
        endproperty
        assert property (p_penable_after_psel) else
            $error("APB Interconnect: PENABLE asserted without PSEL");

        // During ACCESS phase, registered selection should remain stable
        property p_stable_selection;
            @(posedge pclk) (m_psel && m_penable) |-> $stable(slave_sel_reg);
        endproperty
        assert property (p_stable_selection) else
            $error("APB Interconnect: Slave selection changed during ACCESS phase");
    `endif

endmodule
