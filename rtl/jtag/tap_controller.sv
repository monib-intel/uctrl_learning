// JTAG TAP Controller
// Designer: Copilot
// Reviewer: Microarchitecture Lead
//
// IEEE 1149.1 compliant Test Access Port Controller
// Provides external JTAG interface for ATE and debug

module tap_controller (
    // JTAG Pins
    input  logic        TCK,           // Test clock (async to system clocks)
    input  logic        TMS,           // Test mode select
    input  logic        TDI,           // Test data in
    output logic        TDO,           // Test data out
    input  logic        TRST_n,        // Test reset (optional, active low)

    // IJTAG Interface (to internal instruments)
    output logic        ijtag_select,   // Instrument select
    output logic        ijtag_capture,  // Capture trigger
    output logic        ijtag_shift,    // Shift enable
    output logic        ijtag_update,   // Update trigger
    output logic        ijtag_tdi,      // Scan data to instruments
    input  logic        ijtag_tdo       // Scan data from instruments
);

    // TAP State Machine (IEEE 1149.1 16-state FSM)
    typedef enum logic [3:0] {
        TEST_LOGIC_RESET = 4'h0,
        RUN_TEST_IDLE    = 4'h1,
        SELECT_DR_SCAN   = 4'h2,
        CAPTURE_DR       = 4'h3,
        SHIFT_DR         = 4'h4,
        EXIT1_DR         = 4'h5,
        PAUSE_DR         = 4'h6,
        EXIT2_DR         = 4'h7,
        UPDATE_DR        = 4'h8,
        SELECT_IR_SCAN   = 4'h9,
        CAPTURE_IR       = 4'hA,
        SHIFT_IR         = 4'hB,
        EXIT1_IR         = 4'hC,
        PAUSE_IR         = 4'hD,
        EXIT2_IR         = 4'hE,
        UPDATE_IR        = 4'hF
    } tap_state_t;

    tap_state_t tap_state, tap_next_state;

    // Instruction Register (4-bit)
    localparam int IR_WIDTH = 4;
    typedef enum logic [IR_WIDTH-1:0] {
        BYPASS       = 4'h0,
        IDCODE       = 4'h1,
        TCP_CTRL     = 4'h8,
        TCP_STATUS   = 4'h9,
        IJTAG_ACCESS = 4'hA
    } instruction_t;

    logic [IR_WIDTH-1:0] ir_shift_reg;    // Instruction shift register
    logic [IR_WIDTH-1:0] ir_reg;          // Latched instruction
    instruction_t current_instruction;

    // Data Registers
    logic        dr_bypass;               // 1-bit bypass register
    logic [31:0] dr_idcode;               // 32-bit device ID
    logic [31:0] dr_tcp_ctrl;             // 32-bit TCP control register
    logic [31:0] dr_tcp_status;           // 32-bit TCP status register (read-only)
    
    // Shift registers for selected data register
    logic [31:0] dr_shift_reg;            // Generic 32-bit shift register
    logic [5:0]  shift_count;             // Bit counter for shifts
    
    // IDCODE Definition: {version[3:0], part[15:0], manufacturer[10:0], 1'b1}
    // Using a placeholder manufacturer ID and part number
    localparam logic [31:0] IDCODE_VALUE = {
        4'h1,                   // Version 1
        16'hCAFE,              // Part number (placeholder)
        11'h05F,               // Manufacturer ID (placeholder - JEDEC continuation)
        1'b1                   // LSB must be 1 per IEEE 1149.1
    };

    // Internal control signals
    logic capture_dr;
    logic shift_dr;
    logic update_dr;
    logic capture_ir;
    logic shift_ir;
    logic update_ir;

    // Assign current instruction
    assign current_instruction = instruction_t'(ir_reg);

    // TAP State Machine (Sequential Logic)
    always_ff @(posedge TCK or negedge TRST_n) begin
        if (!TRST_n) begin
            tap_state <= TEST_LOGIC_RESET;
        end else begin
            tap_state <= tap_next_state;
        end
    end

    // TAP State Machine (Next State Logic)
    always_comb begin
        // Default: stay in current state
        tap_next_state = tap_state;

        case (tap_state)
            TEST_LOGIC_RESET: tap_next_state = TMS ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
            RUN_TEST_IDLE:    tap_next_state = TMS ? SELECT_DR_SCAN : RUN_TEST_IDLE;
            
            // DR Path
            SELECT_DR_SCAN:   tap_next_state = TMS ? SELECT_IR_SCAN : CAPTURE_DR;
            CAPTURE_DR:       tap_next_state = TMS ? EXIT1_DR : SHIFT_DR;
            SHIFT_DR:         tap_next_state = TMS ? EXIT1_DR : SHIFT_DR;
            EXIT1_DR:         tap_next_state = TMS ? UPDATE_DR : PAUSE_DR;
            PAUSE_DR:         tap_next_state = TMS ? EXIT2_DR : PAUSE_DR;
            EXIT2_DR:         tap_next_state = TMS ? UPDATE_DR : SHIFT_DR;
            UPDATE_DR:        tap_next_state = TMS ? SELECT_DR_SCAN : RUN_TEST_IDLE;
            
            // IR Path
            SELECT_IR_SCAN:   tap_next_state = TMS ? TEST_LOGIC_RESET : CAPTURE_IR;
            CAPTURE_IR:       tap_next_state = TMS ? EXIT1_IR : SHIFT_IR;
            SHIFT_IR:         tap_next_state = TMS ? EXIT1_IR : SHIFT_IR;
            EXIT1_IR:         tap_next_state = TMS ? UPDATE_IR : PAUSE_IR;
            PAUSE_IR:         tap_next_state = TMS ? EXIT2_IR : PAUSE_IR;
            EXIT2_IR:         tap_next_state = TMS ? UPDATE_IR : SHIFT_IR;
            UPDATE_IR:        tap_next_state = TMS ? SELECT_DR_SCAN : RUN_TEST_IDLE;
            
            default:          tap_next_state = TEST_LOGIC_RESET;
        endcase
    end

    // Generate control signals from state
    always_comb begin
        capture_dr = (tap_state == CAPTURE_DR);
        shift_dr   = (tap_state == SHIFT_DR);
        update_dr  = (tap_state == UPDATE_DR);
        capture_ir = (tap_state == CAPTURE_IR);
        shift_ir   = (tap_state == SHIFT_IR);
        update_ir  = (tap_state == UPDATE_IR);
    end

    // Instruction Register Logic
    always_ff @(posedge TCK or negedge TRST_n) begin
        if (!TRST_n) begin
            ir_shift_reg <= IDCODE;  // Default instruction after reset
            ir_reg       <= IDCODE;
        end else begin
            if (capture_ir) begin
                // Capture: Load fixed pattern (0b0001 per IEEE 1149.1)
                ir_shift_reg <= 4'b0001;
            end else if (shift_ir) begin
                // Shift: Shift in TDI, shift out to TDO
                ir_shift_reg <= {TDI, ir_shift_reg[IR_WIDTH-1:1]};
            end else if (update_ir) begin
                // Update: Latch the shifted instruction
                ir_reg <= ir_shift_reg;
            end
        end
    end

    // Data Register Logic
    always_ff @(posedge TCK or negedge TRST_n) begin
        if (!TRST_n) begin
            dr_bypass    <= 1'b0;
            dr_shift_reg <= 32'h0;
            dr_tcp_ctrl  <= 32'h0;
            shift_count  <= 6'h0;
        end else begin
            if (capture_dr) begin
                // Capture: Load the appropriate data register
                shift_count <= 6'h0;
                case (current_instruction)
                    BYPASS: begin
                        dr_bypass <= 1'b0;
                    end
                    IDCODE: begin
                        dr_shift_reg <= IDCODE_VALUE;
                    end
                    TCP_CTRL: begin
                        dr_shift_reg <= dr_tcp_ctrl;
                    end
                    TCP_STATUS: begin
                        dr_shift_reg <= dr_tcp_status;
                    end
                    IJTAG_ACCESS: begin
                        dr_shift_reg <= 32'h0;  // Will be driven by IJTAG network
                    end
                    default: begin
                        dr_bypass <= 1'b0;
                    end
                endcase
            end else if (shift_dr) begin
                // Shift: Shift through the selected register
                shift_count <= shift_count + 1;
                case (current_instruction)
                    BYPASS: begin
                        dr_bypass <= TDI;
                    end
                    IDCODE, TCP_CTRL, TCP_STATUS: begin
                        dr_shift_reg <= {TDI, dr_shift_reg[31:1]};
                    end
                    IJTAG_ACCESS: begin
                        dr_shift_reg <= {TDI, dr_shift_reg[31:1]};
                    end
                    default: begin
                        dr_bypass <= TDI;
                    end
                endcase
            end else if (update_dr) begin
                // Update: Write back modified values to writable registers
                case (current_instruction)
                    TCP_CTRL: begin
                        dr_tcp_ctrl <= dr_shift_reg;
                    end
                    // IDCODE and TCP_STATUS are read-only
                    // BYPASS doesn't latch
                    // IJTAG_ACCESS handled by network
                    default: begin
                        // No update for other registers
                    end
                endcase
            end
        end
    end

    // TCP Status Register (Read-only, would be driven by actual TCP logic)
    // For now, provide a placeholder value
    assign dr_tcp_status = 32'hDEAD_BEEF;

    // TDO Output Multiplexer
    always_comb begin
        if (shift_ir) begin
            // Shifting instruction register
            TDO = ir_shift_reg[0];
        end else if (shift_dr) begin
            // Shifting data register
            case (current_instruction)
                BYPASS: begin
                    TDO = dr_bypass;
                end
                IDCODE, TCP_CTRL, TCP_STATUS: begin
                    TDO = dr_shift_reg[0];
                end
                IJTAG_ACCESS: begin
                    TDO = ijtag_tdo;  // Output from IJTAG network
                end
                default: begin
                    TDO = dr_bypass;
                end
            endcase
        end else begin
            TDO = 1'b0;
        end
    end

    // IJTAG Interface Outputs
    assign ijtag_select  = (current_instruction == IJTAG_ACCESS);
    assign ijtag_capture = ijtag_select && capture_dr;
    assign ijtag_shift   = ijtag_select && shift_dr;
    assign ijtag_update  = ijtag_select && update_dr;
    assign ijtag_tdi     = TDI;

endmodule
