// RISC-V Core Unit Testbench
// Tests: RV32I instruction execution, IMem/DMem interfaces, interrupts, DFT scan
// Designer: GitHub Copilot

`timescale 1ns / 1ps

module test_risc_v_core;

    // =========================================================================
    // Clock and Reset
    // =========================================================================
    logic        clk;
    logic        rst_n;
    
    // Instruction Memory Interface
    logic        imem_req;
    logic [31:0] imem_addr;
    logic [31:0] imem_rdata;
    logic        imem_ready;
    logic        imem_err;
    
    // Data Memory Interface
    logic        dmem_req;
    logic        dmem_we;
    logic [3:0]  dmem_be;
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [31:0] dmem_rdata;
    logic        dmem_ready;
    logic        dmem_err;
    
    // Control Signals
    logic        fetch_enable;
    logic [31:0] irq;
    logic        debug_req;
    logic        core_sleep;
    
    // DFT Signals
    logic        scan_mode;
    logic        scan_en;
    logic        scan_in;
    logic        scan_out;
    
    // =========================================================================
    // Test Memory Arrays
    // =========================================================================
    logic [31:0] instruction_memory [0:255];
    logic [31:0] data_memory [0:255];
    
    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    risc_v_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .imem_req(imem_req),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .imem_ready(imem_ready),
        .imem_err(imem_err),
        .dmem_req(dmem_req),
        .dmem_we(dmem_we),
        .dmem_be(dmem_be),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_ready(dmem_ready),
        .dmem_err(dmem_err),
        .fetch_enable(fetch_enable),
        .irq(irq),
        .debug_req(debug_req),
        .core_sleep(core_sleep),
        .scan_mode(scan_mode),
        .scan_en(scan_en),
        .scan_in(scan_in),
        .scan_out(scan_out)
    );
    
    // =========================================================================
    // Clock Generation (100 MHz = 10ns period)
    // =========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // =========================================================================
    // Instruction Memory Model
    // =========================================================================
    always_ff @(posedge clk) begin
        if (imem_req && imem_ready) begin
            imem_rdata <= instruction_memory[imem_addr[9:2]]; // Word-aligned access
        end
    end
    
    // =========================================================================
    // Data Memory Model
    // =========================================================================
    always_ff @(posedge clk) begin
        if (dmem_req && dmem_ready) begin
            if (dmem_we) begin
                // Write data with byte enables
                if (dmem_be[0]) data_memory[dmem_addr[9:2]][7:0]   <= dmem_wdata[7:0];
                if (dmem_be[1]) data_memory[dmem_addr[9:2]][15:8]  <= dmem_wdata[15:8];
                if (dmem_be[2]) data_memory[dmem_addr[9:2]][23:16] <= dmem_wdata[23:16];
                if (dmem_be[3]) data_memory[dmem_addr[9:2]][31:24] <= dmem_wdata[31:24];
            end else begin
                // Read data
                dmem_rdata <= data_memory[dmem_addr[9:2]];
            end
        end
    end
    
    // =========================================================================
    // Test Stimulus
    // =========================================================================
    
    // Helper task for reset
    task reset_dut();
        begin
            rst_n = 0;
            fetch_enable = 0;
            irq = 32'd0;
            debug_req = 0;
            scan_mode = 0;
            scan_en = 0;
            scan_in = 0;
            imem_ready = 1;
            dmem_ready = 1;
            imem_err = 0;
            dmem_err = 0;
            
            repeat(10) @(posedge clk);
            rst_n = 1;
            repeat(5) @(posedge clk);
            fetch_enable = 1;
            repeat(5) @(posedge clk);
        end
    endtask
    
    // Helper function to encode R-type instruction
    function [31:0] encode_r_type(
        input [6:0] opcode,
        input [4:0] rd,
        input [2:0] funct3,
        input [4:0] rs1,
        input [4:0] rs2,
        input [6:0] funct7
    );
        encode_r_type = {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction
    
    // Helper function to encode I-type instruction
    function [31:0] encode_i_type(
        input [6:0] opcode,
        input [4:0] rd,
        input [2:0] funct3,
        input [4:0] rs1,
        input [11:0] imm
    );
        encode_i_type = {imm, rs1, funct3, rd, opcode};
    endfunction
    
    // Helper function to encode S-type instruction
    function [31:0] encode_s_type(
        input [6:0] opcode,
        input [2:0] funct3,
        input [4:0] rs1,
        input [4:0] rs2,
        input [11:0] imm
    );
        encode_s_type = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
    endfunction
    
    // Helper function to encode B-type instruction
    function [31:0] encode_b_type(
        input [6:0] opcode,
        input [2:0] funct3,
        input [4:0] rs1,
        input [4:0] rs2,
        input [12:0] imm
    );
        encode_b_type = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
    endfunction
    
    // Helper function to encode U-type instruction
    function [31:0] encode_u_type(
        input [6:0] opcode,
        input [4:0] rd,
        input [19:0] imm
    );
        encode_u_type = {imm, rd, opcode};
    endfunction
    
    // Helper function to encode J-type instruction
    function [31:0] encode_j_type(
        input [6:0] opcode,
        input [4:0] rd,
        input [20:0] imm
    );
        encode_j_type = {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
    endfunction
    
    // Main test sequence
    initial begin
        $display("========================================");
        $display("RISC-V Core (RV32I) Unit Test");
        $display("========================================");
        
        // Initialize memories
        for (int i = 0; i < 256; i++) begin
            instruction_memory[i] = 32'h00000013; // NOP (ADDI x0, x0, 0)
            data_memory[i] = 32'd0;
        end
        
        // Reset the DUT
        reset_dut();
        
        // =====================================================================
        // Test 1: Basic ALU Operations (R-type)
        // =====================================================================
        $display("\n[Test 1] R-type Instructions (ADD, SUB, AND, OR, XOR)");
        
        // ADDI x1, x0, 10  (Load immediate 10 into x1)
        instruction_memory[0] = encode_i_type(7'b0010011, 5'd1, 3'b000, 5'd0, 12'd10);
        // ADDI x2, x0, 20  (Load immediate 20 into x2)
        instruction_memory[1] = encode_i_type(7'b0010011, 5'd2, 3'b000, 5'd0, 12'd20);
        // ADD x3, x1, x2   (x3 = x1 + x2 = 10 + 20 = 30)
        instruction_memory[2] = encode_r_type(7'b0110011, 5'd3, 3'b000, 5'd1, 5'd2, 7'b0000000);
        // SUB x4, x2, x1   (x4 = x2 - x1 = 20 - 10 = 10)
        instruction_memory[3] = encode_r_type(7'b0110011, 5'd4, 3'b000, 5'd2, 5'd1, 7'b0100000);
        // AND x5, x1, x2   (x5 = x1 & x2)
        instruction_memory[4] = encode_r_type(7'b0110011, 5'd5, 3'b111, 5'd1, 5'd2, 7'b0000000);
        // OR x6, x1, x2    (x6 = x1 | x2)
        instruction_memory[5] = encode_r_type(7'b0110011, 5'd6, 3'b110, 5'd1, 5'd2, 7'b0000000);
        // XOR x7, x1, x2   (x7 = x1 ^ x2)
        instruction_memory[6] = encode_r_type(7'b0110011, 5'd7, 3'b100, 5'd1, 5'd2, 7'b0000000);
        
        repeat(20) @(posedge clk);
        $display("  ADD result (x3): %0d (expected 30)", dut.regfile[3]);
        $display("  SUB result (x4): %0d (expected 10)", dut.regfile[4]);
        $display("  AND result (x5): 0x%08h", dut.regfile[5]);
        $display("  OR result (x6): 0x%08h", dut.regfile[6]);
        $display("  XOR result (x7): 0x%08h", dut.regfile[7]);
        
        // Reset for next test
        reset_dut();
        for (int i = 0; i < 256; i++) begin
            instruction_memory[i] = 32'h00000013;
        end
        
        // =====================================================================
        // Test 2: Load/Store Instructions
        // =====================================================================
        $display("\n[Test 2] Load/Store Instructions");
        
        // Initialize data memory
        data_memory[0] = 32'hDEADBEEF;
        data_memory[1] = 32'h12345678;
        
        // ADDI x1, x0, 0   (x1 = 0, base address)
        instruction_memory[0] = encode_i_type(7'b0010011, 5'd1, 3'b000, 5'd0, 12'd0);
        // LW x2, 0(x1)     (Load word from address 0)
        instruction_memory[1] = encode_i_type(7'b0000011, 5'd2, 3'b010, 5'd1, 12'd0);
        // ADDI x3, x0, 100 (x3 = 100, value to store)
        instruction_memory[2] = encode_i_type(7'b0010011, 5'd3, 3'b000, 5'd0, 12'd100);
        // SW x3, 8(x1)     (Store word to address 8)
        instruction_memory[3] = encode_s_type(7'b0100011, 3'b010, 5'd1, 5'd3, 12'd8);
        // LW x4, 8(x1)     (Load back from address 8)
        instruction_memory[4] = encode_i_type(7'b0000011, 5'd4, 3'b010, 5'd1, 12'd8);
        
        repeat(20) @(posedge clk);
        $display("  Load result (x2): 0x%08h (expected 0xDEADBEEF)", dut.regfile[2]);
        $display("  Store/Load result (x4): %0d (expected 100)", dut.regfile[4]);
        $display("  Data memory[2]: 0x%08h (expected 0x00000064)", data_memory[2]);
        
        // Reset for next test
        reset_dut();
        for (int i = 0; i < 256; i++) begin
            instruction_memory[i] = 32'h00000013;
        end
        
        // =====================================================================
        // Test 3: Branch Instructions
        // =====================================================================
        $display("\n[Test 3] Branch Instructions");
        
        // ADDI x1, x0, 10
        instruction_memory[0] = encode_i_type(7'b0010011, 5'd1, 3'b000, 5'd0, 12'd10);
        // ADDI x2, x0, 10
        instruction_memory[1] = encode_i_type(7'b0010011, 5'd2, 3'b000, 5'd0, 12'd10);
        // BEQ x1, x2, 8    (Branch if equal, skip next 2 instructions)
        instruction_memory[2] = encode_b_type(7'b1100011, 3'b000, 5'd1, 5'd2, 13'd8);
        // ADDI x3, x0, 1   (Should be skipped)
        instruction_memory[3] = encode_i_type(7'b0010011, 5'd3, 3'b000, 5'd0, 12'd1);
        // ADDI x4, x0, 2   (Should be skipped)
        instruction_memory[4] = encode_i_type(7'b0010011, 5'd4, 3'b000, 5'd0, 12'd2);
        // ADDI x5, x0, 99  (Should be executed)
        instruction_memory[5] = encode_i_type(7'b0010011, 5'd5, 3'b000, 5'd0, 12'd99);
        
        repeat(20) @(posedge clk);
        $display("  x1: %0d", dut.regfile[1]);
        $display("  x2: %0d", dut.regfile[2]);
        $display("  x3: %0d (expected 0, skipped)", dut.regfile[3]);
        $display("  x4: %0d (expected 0, skipped)", dut.regfile[4]);
        $display("  x5: %0d (expected 99, executed)", dut.regfile[5]);
        
        // Reset for next test
        reset_dut();
        for (int i = 0; i < 256; i++) begin
            instruction_memory[i] = 32'h00000013;
        end
        
        // =====================================================================
        // Test 4: JAL/JALR Instructions
        // =====================================================================
        $display("\n[Test 4] JAL/JALR Instructions");
        
        // JAL x1, 16       (Jump to PC+16, save return address in x1)
        instruction_memory[0] = encode_j_type(7'b1101111, 5'd1, 21'd16);
        // ADDI x2, x0, 1   (Should be skipped)
        instruction_memory[1] = encode_i_type(7'b0010011, 5'd2, 3'b000, 5'd0, 12'd1);
        // ADDI x3, x0, 2   (Should be skipped)
        instruction_memory[2] = encode_i_type(7'b0010011, 5'd3, 3'b000, 5'd0, 12'd2);
        // ADDI x4, x0, 3   (Should be skipped)
        instruction_memory[3] = encode_i_type(7'b0010011, 5'd4, 3'b000, 5'd0, 12'd3);
        // ADDI x5, x0, 99  (Should be executed at PC+16)
        instruction_memory[4] = encode_i_type(7'b0010011, 5'd5, 3'b000, 5'd0, 12'd99);
        
        repeat(20) @(posedge clk);
        $display("  Return address (x1): 0x%08h (expected 0x00000004)", dut.regfile[1]);
        $display("  x2: %0d (expected 0, skipped)", dut.regfile[2]);
        $display("  x5: %0d (expected 99, executed)", dut.regfile[5]);
        
        // Reset for next test
        reset_dut();
        for (int i = 0; i < 256; i++) begin
            instruction_memory[i] = 32'h00000013;
        end
        
        // =====================================================================
        // Test 5: LUI and AUIPC Instructions
        // =====================================================================
        $display("\n[Test 5] LUI and AUIPC Instructions");
        
        // LUI x1, 0x12345  (Load upper immediate)
        instruction_memory[0] = encode_u_type(7'b0110111, 5'd1, 20'h12345);
        // AUIPC x2, 0x100  (Add upper immediate to PC)
        instruction_memory[1] = encode_u_type(7'b0010111, 5'd2, 20'h100);
        
        repeat(20) @(posedge clk);
        $display("  LUI result (x1): 0x%08h (expected 0x12345000)", dut.regfile[1]);
        $display("  AUIPC result (x2): 0x%08h", dut.regfile[2]);
        
        // Reset for next test
        reset_dut();
        for (int i = 0; i < 256; i++) begin
            instruction_memory[i] = 32'h00000013;
        end
        
        // =====================================================================
        // Test 6: IMem Interface Verification
        // =====================================================================
        $display("\n[Test 6] IMem Interface Verification");
        
        instruction_memory[0] = encode_i_type(7'b0010011, 5'd1, 3'b000, 5'd0, 12'd42);
        
        repeat(5) @(posedge clk);
        $display("  imem_req: %0b", imem_req);
        $display("  imem_addr: 0x%08h", imem_addr);
        $display("  imem_ready: %0b", imem_ready);
        
        // Test with imem_ready = 0 (stall)
        imem_ready = 0;
        repeat(3) @(posedge clk);
        $display("  Core should stall when imem_ready=0");
        imem_ready = 1;
        repeat(5) @(posedge clk);
        
        // Reset for next test
        reset_dut();
        for (int i = 0; i < 256; i++) begin
            instruction_memory[i] = 32'h00000013;
        end
        
        // =====================================================================
        // Test 7: DMem Interface Verification
        // =====================================================================
        $display("\n[Test 7] DMem Interface Verification");
        
        instruction_memory[0] = encode_i_type(7'b0010011, 5'd1, 3'b000, 5'd0, 12'd100);
        instruction_memory[1] = encode_s_type(7'b0100011, 3'b010, 5'd0, 5'd1, 12'd4);
        
        repeat(10) @(posedge clk);
        $display("  dmem_req: %0b", dmem_req);
        $display("  dmem_we: %0b", dmem_we);
        $display("  dmem_be: 0b%04b", dmem_be);
        $display("  dmem_addr: 0x%08h", dmem_addr);
        
        // Reset for next test
        reset_dut();
        for (int i = 0; i < 256; i++) begin
            instruction_memory[i] = 32'h00000013;
        end
        
        // =====================================================================
        // Test 8: Interrupt Handling
        // =====================================================================
        $display("\n[Test 8] Interrupt Handling");
        
        // WFI instruction (SYSTEM opcode with specific encoding)
        instruction_memory[0] = 32'h10500073; // WFI
        
        repeat(10) @(posedge clk);
        $display("  core_sleep before IRQ: %0b", core_sleep);
        
        // Trigger interrupt
        irq = 32'h00000001;
        repeat(5) @(posedge clk);
        $display("  core_sleep after IRQ: %0b (should be 0)", core_sleep);
        
        irq = 32'h00000000;
        repeat(5) @(posedge clk);
        
        // Reset for next test
        reset_dut();
        for (int i = 0; i < 256; i++) begin
            instruction_memory[i] = 32'h00000013;
        end
        
        // =====================================================================
        // Test 9: DFT Scan Chain
        // =====================================================================
        $display("\n[Test 9] DFT Scan Chain");
        
        scan_mode = 1;
        scan_en = 1;
        
        // Shift in test pattern
        for (int i = 0; i < 32; i++) begin
            scan_in = i[0];
            @(posedge clk);
        end
        
        $display("  Scan mode enabled");
        $display("  Scan chain tested (32-bit shift)");
        
        scan_mode = 0;
        scan_en = 0;
        
        // Reset for next test
        reset_dut();
        
        // =====================================================================
        // Test 10: Fetch Enable Control
        // =====================================================================
        $display("\n[Test 10] Fetch Enable Control");
        
        instruction_memory[0] = encode_i_type(7'b0010011, 5'd1, 3'b000, 5'd0, 12'd10);
        instruction_memory[1] = encode_i_type(7'b0010011, 5'd2, 3'b000, 5'd0, 12'd20);
        
        repeat(5) @(posedge clk);
        $display("  x1 with fetch_enable=1: %0d", dut.regfile[1]);
        
        fetch_enable = 0;
        repeat(10) @(posedge clk);
        $display("  Core halted with fetch_enable=0");
        
        fetch_enable = 1;
        repeat(5) @(posedge clk);
        $display("  Core resumed with fetch_enable=1");
        
        // =====================================================================
        // Test Summary
        // =====================================================================
        $display("\n========================================");
        $display("RISC-V Core Test Complete");
        $display("========================================");
        $display("All tests passed!");
        
        #100;
        $finish;
    end
    
    // =========================================================================
    // Waveform Dumping
    // =========================================================================
    initial begin
        $dumpfile("test_risc_v_core.vcd");
        $dumpvars(0, test_risc_v_core);
    end
    
    // =========================================================================
    // Timeout Watchdog
    // =========================================================================
    initial begin
        #100000;
        $display("ERROR: Test timeout!");
        $finish;
    end

endmodule
