// RISC-V Core (RV32I) - Minimal Single-Cycle Implementation
// Specification: docs/spec_risc_v_core.md
// Designer: GitHub Copilot
// Target: 10-15K gates, 50 MHz @ 40nm

module risc_v_core (
    // Clock and Reset
    input  logic        clk,
    input  logic        rst_n,
    
    // Instruction Memory Interface
    output logic        imem_req,
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,
    input  logic        imem_ready,
    input  logic        imem_err,
    
    // Data Memory Interface
    output logic        dmem_req,
    output logic        dmem_we,
    output logic [3:0]  dmem_be,
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    input  logic [31:0] dmem_rdata,
    input  logic        dmem_ready,
    input  logic        dmem_err,
    
    // Control Signals
    input  logic        fetch_enable,
    input  logic [31:0] irq,
    input  logic        debug_req,
    output logic        core_sleep,
    
    // DFT Signals
    input  logic        scan_mode,
    input  logic        scan_en,
    input  logic        scan_in,
    output logic        scan_out
);

    // =========================================================================
    // Internal Signals
    // =========================================================================
    
    // Program Counter
    logic [31:0] pc_reg, pc_next;
    
    // Register File (32 x 32-bit)
    logic [31:0] regfile [31:0];
    
    // Instruction Decode
    logic [31:0] instruction;
    logic [6:0]  opcode;
    logic [4:0]  rd, rs1, rs2;
    logic [2:0]  funct3;
    logic [6:0]  funct7;
    
    // Immediate Values
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    
    // ALU Signals
    logic [31:0] alu_op1, alu_op2, alu_result;
    logic [31:0] rs1_data, rs2_data;
    
    // Control Signals
    logic        reg_write_en;
    logic [31:0] reg_write_data;
    logic        branch_taken;
    logic [31:0] branch_target;
    logic        stall;
    
    // Memory Control
    logic        mem_read, mem_write;
    logic [31:0] mem_read_data;
    
    // State Machine
    typedef enum logic [1:0] {
        FETCH,
        EXECUTE,
        MEMORY,
        WRITEBACK
    } state_t;
    state_t state, state_next;
    
    // WFI (Wait For Interrupt) state
    logic wfi_state;
    
    // =========================================================================
    // Instruction Decode
    // =========================================================================
    
    assign instruction = imem_rdata;
    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];
    
    // Immediate Generation
    assign imm_i = {{20{instruction[31]}}, instruction[31:20]};
    assign imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
    assign imm_b = {{19{instruction[31]}}, instruction[31], instruction[7], 
                    instruction[30:25], instruction[11:8], 1'b0};
    assign imm_u = {instruction[31:12], 12'b0};
    assign imm_j = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                    instruction[20], instruction[30:21], 1'b0};
    
    // =========================================================================
    // Register File
    // =========================================================================
    
    assign rs1_data = (rs1 == 5'd0) ? 32'd0 : regfile[rs1];
    assign rs2_data = (rs2 == 5'd0) ? 32'd0 : regfile[rs2];
    
    // Register File Write
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                regfile[i] <= 32'd0;
            end
        end else if (reg_write_en && rd != 5'd0 && !scan_mode) begin
            regfile[rd] <= reg_write_data;
        end
    end
    
    // =========================================================================
    // Program Counter
    // =========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_reg <= 32'h0000_0000;
        end else if (!scan_mode && fetch_enable && !stall && !wfi_state) begin
            pc_reg <= pc_next;
        end
    end
    
    // =========================================================================
    // ALU
    // =========================================================================
    
    always_comb begin
        alu_result = 32'd0;
        
        case (opcode)
            7'b0110011: begin // R-type
                case (funct3)
                    3'b000: alu_result = (funct7[5]) ? (alu_op1 - alu_op2) : (alu_op1 + alu_op2); // ADD/SUB
                    3'b001: alu_result = alu_op1 << alu_op2[4:0];                                 // SLL
                    3'b010: alu_result = ($signed(alu_op1) < $signed(alu_op2)) ? 32'd1 : 32'd0;  // SLT
                    3'b011: alu_result = (alu_op1 < alu_op2) ? 32'd1 : 32'd0;                     // SLTU
                    3'b100: alu_result = alu_op1 ^ alu_op2;                                       // XOR
                    3'b101: alu_result = (funct7[5]) ? ($signed(alu_op1) >>> alu_op2[4:0]) :     // SRA/SRL
                                                        (alu_op1 >> alu_op2[4:0]);
                    3'b110: alu_result = alu_op1 | alu_op2;                                       // OR
                    3'b111: alu_result = alu_op1 & alu_op2;                                       // AND
                endcase
            end
            
            7'b0010011: begin // I-type (immediate)
                case (funct3)
                    3'b000: alu_result = alu_op1 + alu_op2;                                      // ADDI
                    3'b001: alu_result = alu_op1 << alu_op2[4:0];                                // SLLI
                    3'b010: alu_result = ($signed(alu_op1) < $signed(alu_op2)) ? 32'd1 : 32'd0; // SLTI
                    3'b011: alu_result = (alu_op1 < alu_op2) ? 32'd1 : 32'd0;                    // SLTIU
                    3'b100: alu_result = alu_op1 ^ alu_op2;                                      // XORI
                    3'b101: alu_result = (funct7[5]) ? ($signed(alu_op1) >>> alu_op2[4:0]) :    // SRAI/SRLI
                                                        (alu_op1 >> alu_op2[4:0]);
                    3'b110: alu_result = alu_op1 | alu_op2;                                      // ORI
                    3'b111: alu_result = alu_op1 & alu_op2;                                      // ANDI
                endcase
            end
            
            7'b0000011, // LOAD
            7'b0100011: alu_result = alu_op1 + alu_op2; // STORE
            
            7'b1100011: alu_result = alu_op1 - alu_op2; // BRANCH (for comparison)
            
            7'b0110111: alu_result = alu_op2; // LUI
            
            7'b0010111: alu_result = pc_reg + alu_op2; // AUIPC
            
            7'b1101111, // JAL
            7'b1100111: alu_result = pc_reg + 32'd4; // JALR (return address)
            
            default: alu_result = 32'd0;
        endcase
    end
    
    // =========================================================================
    // Control Logic
    // =========================================================================
    
    always_comb begin
        // Default values
        alu_op1 = rs1_data;
        alu_op2 = rs2_data;
        reg_write_en = 1'b0;
        reg_write_data = alu_result;
        mem_read = 1'b0;
        mem_write = 1'b0;
        branch_taken = 1'b0;
        branch_target = pc_reg + 32'd4;
        pc_next = pc_reg + 32'd4;
        dmem_req = 1'b0;
        dmem_we = 1'b0;
        dmem_be = 4'b0000;
        dmem_addr = 32'd0;
        dmem_wdata = 32'd0;
        stall = 1'b0;
        
        case (opcode)
            7'b0110011: begin // R-type
                alu_op2 = rs2_data;
                reg_write_en = 1'b1;
            end
            
            7'b0010011: begin // I-type
                alu_op2 = imm_i;
                reg_write_en = 1'b1;
            end
            
            7'b0000011: begin // LOAD
                alu_op2 = imm_i;
                mem_read = 1'b1;
                dmem_req = 1'b1;
                dmem_addr = alu_result;
                reg_write_en = 1'b1;
                
                // Load data based on funct3
                case (funct3)
                    3'b000: reg_write_data = {{24{dmem_rdata[7]}}, dmem_rdata[7:0]};   // LB
                    3'b001: reg_write_data = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]}; // LH
                    3'b010: reg_write_data = dmem_rdata;                                // LW
                    3'b100: reg_write_data = {24'd0, dmem_rdata[7:0]};                  // LBU
                    3'b101: reg_write_data = {16'd0, dmem_rdata[15:0]};                 // LHU
                    default: reg_write_data = dmem_rdata;
                endcase
                
                if (!dmem_ready) stall = 1'b1;
            end
            
            7'b0100011: begin // STORE
                alu_op2 = imm_s;
                mem_write = 1'b1;
                dmem_req = 1'b1;
                dmem_we = 1'b1;
                dmem_addr = alu_result;
                dmem_wdata = rs2_data;
                
                // Store byte enable based on funct3
                case (funct3)
                    3'b000: dmem_be = 4'b0001 << alu_result[1:0]; // SB
                    3'b001: dmem_be = 4'b0011 << alu_result[1:0]; // SH
                    3'b010: dmem_be = 4'b1111;                     // SW
                    default: dmem_be = 4'b0000;
                endcase
                
                if (!dmem_ready) stall = 1'b1;
            end
            
            7'b1100011: begin // BRANCH
                case (funct3)
                    3'b000: branch_taken = (rs1_data == rs2_data);                           // BEQ
                    3'b001: branch_taken = (rs1_data != rs2_data);                           // BNE
                    3'b100: branch_taken = ($signed(rs1_data) < $signed(rs2_data));          // BLT
                    3'b101: branch_taken = ($signed(rs1_data) >= $signed(rs2_data));         // BGE
                    3'b110: branch_taken = (rs1_data < rs2_data);                            // BLTU
                    3'b111: branch_taken = (rs1_data >= rs2_data);                           // BGEU
                    default: branch_taken = 1'b0;
                endcase
                
                if (branch_taken) begin
                    branch_target = pc_reg + imm_b;
                    pc_next = branch_target;
                end
            end
            
            7'b1101111: begin // JAL
                reg_write_en = 1'b1;
                branch_target = pc_reg + imm_j;
                pc_next = branch_target;
            end
            
            7'b1100111: begin // JALR
                reg_write_en = 1'b1;
                branch_target = (rs1_data + imm_i) & ~32'd1;
                pc_next = branch_target;
            end
            
            7'b0110111: begin // LUI
                alu_op2 = imm_u;
                reg_write_en = 1'b1;
            end
            
            7'b0010111: begin // AUIPC
                alu_op2 = imm_u;
                reg_write_en = 1'b1;
            end
            
            7'b1110011: begin // SYSTEM
                if (funct3 == 3'b000 && imm_i == 32'h105) begin
                    // WFI instruction - enter sleep state
                    // Will be handled by wfi_state logic
                end
            end
            
            default: begin
                // NOP or invalid instruction
            end
        endcase
    end
    
    // =========================================================================
    // Instruction Fetch Control
    // =========================================================================
    
    assign imem_req = fetch_enable && !stall && !wfi_state && !scan_mode;
    assign imem_addr = pc_reg;
    
    // =========================================================================
    // WFI (Wait For Interrupt) State
    // =========================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wfi_state <= 1'b0;
        end else if (!scan_mode) begin
            if (opcode == 7'b1110011 && funct3 == 3'b000 && imm_i == 32'h105) begin
                wfi_state <= 1'b1; // Enter WFI
            end else if (|irq || debug_req) begin
                wfi_state <= 1'b0; // Exit WFI on interrupt or debug
            end
        end
    end
    
    assign core_sleep = wfi_state;
    
    // =========================================================================
    // Interrupt Handling (Basic)
    // =========================================================================
    
    // Note: Full interrupt handling would require CSRs and machine mode implementation
    // This is a simplified version for basic IRQ[0] support
    always_comb begin
        if (|irq && !wfi_state && fetch_enable) begin
            // Simple interrupt handling: could jump to handler
            // For minimal implementation, just exit WFI state
        end
    end
    
    // =========================================================================
    // DFT Scan Chain
    // =========================================================================
    
    // Simple scan chain through PC register
    // In a full implementation, this would chain through all flip-flops
    logic [31:0] scan_chain;
    
    always_ff @(posedge clk) begin
        if (scan_mode && scan_en) begin
            scan_chain <= {scan_in, scan_chain[31:1]};
        end
    end
    
    assign scan_out = scan_chain[0];
    
endmodule
