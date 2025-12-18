// =============================================================================
// APB Interconnect Testbench
// =============================================================================
// Module: test_apb_interconnect
// Designer: Copilot
//
// Description:
//   Unit testbench for APB interconnect. Verifies:
//   - Address decoding for 5 slaves
//   - APB4 protocol transactions
//   - Error handling for unmapped addresses
//   - Response multiplexing
//
// =============================================================================

`timescale 1ns/1ps

module test_apb_interconnect;

    // =========================================================================
    // Clock and Reset
    // =========================================================================
    logic pclk;
    logic preset_n;

    // Clock generation (100 MHz)
    initial begin
        pclk = 0;
        forever #5 pclk = ~pclk;  // 10ns period
    end

    // =========================================================================
    // DUT Signals - Master Port
    // =========================================================================
    logic [31:0] m_paddr;
    logic        m_psel;
    logic        m_penable;
    logic        m_pwrite;
    logic [31:0] m_pwdata;
    logic [3:0]  m_pstrb;
    logic        m_pready;
    logic [31:0] m_prdata;
    logic        m_pslverr;

    // =========================================================================
    // DUT Signals - Slave Ports
    // =========================================================================
    // Slave 0: ROM
    logic [31:0] s0_paddr;
    logic        s0_psel;
    logic        s0_penable;
    logic        s0_pwrite;
    logic [31:0] s0_pwdata;
    logic [3:0]  s0_pstrb;
    logic        s0_pready;
    logic [31:0] s0_prdata;
    logic        s0_pslverr;

    // Slave 1: Flash
    logic [31:0] s1_paddr;
    logic        s1_psel;
    logic        s1_penable;
    logic        s1_pwrite;
    logic [31:0] s1_pwdata;
    logic [3:0]  s1_pstrb;
    logic        s1_pready;
    logic [31:0] s1_prdata;
    logic        s1_pslverr;

    // Slave 2: SRAM
    logic [31:0] s2_paddr;
    logic        s2_psel;
    logic        s2_penable;
    logic        s2_pwrite;
    logic [31:0] s2_pwdata;
    logic [3:0]  s2_pstrb;
    logic        s2_pready;
    logic [31:0] s2_prdata;
    logic        s2_pslverr;

    // Slave 3: Control Registers
    logic [31:0] s3_paddr;
    logic        s3_psel;
    logic        s3_penable;
    logic        s3_pwrite;
    logic [31:0] s3_pwdata;
    logic [3:0]  s3_pstrb;
    logic        s3_pready;
    logic [31:0] s3_prdata;
    logic        s3_pslverr;

    // Slave 4: Diagnostic Buffer
    logic [31:0] s4_paddr;
    logic        s4_psel;
    logic        s4_penable;
    logic        s4_pwrite;
    logic [31:0] s4_pwdata;
    logic [3:0]  s4_pstrb;
    logic        s4_pready;
    logic [31:0] s4_prdata;
    logic        s4_pslverr;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    apb_interconnect dut (
        .pclk(pclk),
        .preset_n(preset_n),
        // Master port
        .m_paddr(m_paddr),
        .m_psel(m_psel),
        .m_penable(m_penable),
        .m_pwrite(m_pwrite),
        .m_pwdata(m_pwdata),
        .m_pstrb(m_pstrb),
        .m_pready(m_pready),
        .m_prdata(m_prdata),
        .m_pslverr(m_pslverr),
        // Slave 0: ROM
        .s0_paddr(s0_paddr),
        .s0_psel(s0_psel),
        .s0_penable(s0_penable),
        .s0_pwrite(s0_pwrite),
        .s0_pwdata(s0_pwdata),
        .s0_pstrb(s0_pstrb),
        .s0_pready(s0_pready),
        .s0_prdata(s0_prdata),
        .s0_pslverr(s0_pslverr),
        // Slave 1: Flash
        .s1_paddr(s1_paddr),
        .s1_psel(s1_psel),
        .s1_penable(s1_penable),
        .s1_pwrite(s1_pwrite),
        .s1_pwdata(s1_pwdata),
        .s1_pstrb(s1_pstrb),
        .s1_pready(s1_pready),
        .s1_prdata(s1_prdata),
        .s1_pslverr(s1_pslverr),
        // Slave 2: SRAM
        .s2_paddr(s2_paddr),
        .s2_psel(s2_psel),
        .s2_penable(s2_penable),
        .s2_pwrite(s2_pwrite),
        .s2_pwdata(s2_pwdata),
        .s2_pstrb(s2_pstrb),
        .s2_pready(s2_pready),
        .s2_prdata(s2_prdata),
        .s2_pslverr(s2_pslverr),
        // Slave 3: Control Registers
        .s3_paddr(s3_paddr),
        .s3_psel(s3_psel),
        .s3_penable(s3_penable),
        .s3_pwrite(s3_pwrite),
        .s3_pwdata(s3_pwdata),
        .s3_pstrb(s3_pstrb),
        .s3_pready(s3_pready),
        .s3_prdata(s3_prdata),
        .s3_pslverr(s3_pslverr),
        // Slave 4: Diagnostic Buffer
        .s4_paddr(s4_paddr),
        .s4_psel(s4_psel),
        .s4_penable(s4_penable),
        .s4_pwrite(s4_pwrite),
        .s4_pwdata(s4_pwdata),
        .s4_pstrb(s4_pstrb),
        .s4_pready(s4_pready),
        .s4_prdata(s4_prdata),
        .s4_pslverr(s4_pslverr)
    );

    // =========================================================================
    // Test Variables
    // =========================================================================
    int errors;
    int tests_passed;
    int tests_failed;
    
    // Slave address width parameters (for test data pattern generation)
    localparam int ROM_ADDR_WIDTH  = 15;  // 32KB = 2^15 bytes
    localparam int FLASH_ADDR_WIDTH = 17; // 128KB = 2^17 bytes
    localparam int SRAM_ADDR_WIDTH  = 13; // 8KB = 2^13 bytes
    localparam int CTRL_ADDR_WIDTH  = 12; // 4KB = 2^12 bytes
    localparam int DIAG_ADDR_WIDTH  = 12; // 4KB = 2^12 bytes
    
    // Simulation timeout
    localparam int SIMULATION_TIMEOUT = 100000; // ns

    // =========================================================================
    // Slave Mockups (Simple Responders)
    // =========================================================================
    // These simulate slave behavior for testing
    // Each slave returns a unique pattern with address bits to verify routing
    
    // Slave 0: ROM - responds with address pattern
    // Address width: 15 bits (32KB = 0x8000 bytes)
    always_ff @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
            s0_pready  <= 1'b0;
            s0_prdata  <= 32'h0;
            s0_pslverr <= 1'b0;
        end else begin
            if (s0_psel && s0_penable) begin
                s0_pready  <= 1'b1;
                s0_prdata  <= 32'hA000_0000 | s0_paddr[ROM_ADDR_WIDTH-1:0];
                s0_pslverr <= 1'b0;
            end else begin
                s0_pready  <= 1'b0;
                s0_prdata  <= 32'h0;
                s0_pslverr <= 1'b0;
            end
        end
    end

    // Slave 1: Flash - responds with address pattern
    // Address width: 17 bits (128KB = 0x20000 bytes)
    always_ff @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
            s1_pready  <= 1'b0;
            s1_prdata  <= 32'h0;
            s1_pslverr <= 1'b0;
        end else begin
            if (s1_psel && s1_penable) begin
                s1_pready  <= 1'b1;
                s1_prdata  <= 32'hB000_0000 | s1_paddr[FLASH_ADDR_WIDTH-1:0];
                s1_pslverr <= 1'b0;
            end else begin
                s1_pready  <= 1'b0;
                s1_prdata  <= 32'h0;
                s1_pslverr <= 1'b0;
            end
        end
    end

    // Slave 2: SRAM - responds with address pattern
    // Address width: 13 bits (8KB = 0x2000 bytes)
    always_ff @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
            s2_pready  <= 1'b0;
            s2_prdata  <= 32'h0;
            s2_pslverr <= 1'b0;
        end else begin
            if (s2_psel && s2_penable) begin
                s2_pready  <= 1'b1;
                s2_prdata  <= 32'hC000_0000 | s2_paddr[SRAM_ADDR_WIDTH-1:0];
                s2_pslverr <= 1'b0;
            end else begin
                s2_pready  <= 1'b0;
                s2_prdata  <= 32'h0;
                s2_pslverr <= 1'b0;
            end
        end
    end

    // Slave 3: Control Registers - responds with address pattern
    // Address width: 12 bits (4KB = 0x1000 bytes)
    always_ff @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
            s3_pready  <= 1'b0;
            s3_prdata  <= 32'h0;
            s3_pslverr <= 1'b0;
        end else begin
            if (s3_psel && s3_penable) begin
                s3_pready  <= 1'b1;
                s3_prdata  <= 32'hD000_0000 | s3_paddr[CTRL_ADDR_WIDTH-1:0];
                s3_pslverr <= 1'b0;
            end else begin
                s3_pready  <= 1'b0;
                s3_prdata  <= 32'h0;
                s3_pslverr <= 1'b0;
            end
        end
    end

    // Slave 4: Diagnostic Buffer - responds with address pattern
    // Address width: 12 bits (4KB = 0x1000 bytes)
    always_ff @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
            s4_pready  <= 1'b0;
            s4_prdata  <= 32'h0;
            s4_pslverr <= 1'b0;
        end else begin
            if (s4_psel && s4_penable) begin
                s4_pready  <= 1'b1;
                s4_prdata  <= 32'hE000_0000 | s4_paddr[DIAG_ADDR_WIDTH-1:0];
                s4_pslverr <= 1'b0;
            end else begin
                s4_pready  <= 1'b0;
                s4_prdata  <= 32'h0;
                s4_pslverr <= 1'b0;
            end
        end
    end

    // =========================================================================
    // Helper Tasks
    // =========================================================================
    
    // Reset task
    task automatic reset_dut();
        preset_n = 0;
        m_paddr = 32'h0;
        m_psel = 0;
        m_penable = 0;
        m_pwrite = 0;
        m_pwdata = 32'h0;
        m_pstrb = 4'b0000;
        
        repeat(5) @(posedge pclk);
        preset_n = 1;
        repeat(2) @(posedge pclk);
        $display("[INFO] Reset complete");
    endtask

    // APB Read Transaction
    task automatic apb_read(
        input logic [31:0] addr,
        output logic [31:0] data,
        output logic error
    );
        // SETUP phase
        @(posedge pclk);
        m_paddr = addr;
        m_psel = 1'b1;
        m_penable = 1'b0;
        m_pwrite = 1'b0;
        
        // ACCESS phase
        @(posedge pclk);
        m_penable = 1'b1;
        
        // Wait for ready and sample outputs
        do @(posedge pclk); while (!m_pready);
        
        data = m_prdata;
        error = m_pslverr;
        
        // Return to IDLE
        m_psel = 1'b0;
        m_penable = 1'b0;
        @(posedge pclk);
    endtask

    // APB Write Transaction
    task automatic apb_write(
        input logic [31:0] addr,
        input logic [31:0] data,
        input logic [3:0] strb,
        output logic error
    );
        // SETUP phase
        @(posedge pclk);
        m_paddr = addr;
        m_psel = 1'b1;
        m_penable = 1'b0;
        m_pwrite = 1'b1;
        m_pwdata = data;
        m_pstrb = strb;
        
        // ACCESS phase
        @(posedge pclk);
        m_penable = 1'b1;
        
        // Wait for ready and sample outputs
        do @(posedge pclk); while (!m_pready);
        
        error = m_pslverr;
        
        // Return to IDLE
        m_psel = 1'b0;
        m_penable = 1'b0;
        m_pwrite = 1'b0;
        @(posedge pclk);
    endtask

    // =========================================================================
    // Test Stimulus
    // =========================================================================
    initial begin
        errors = 0;
        tests_passed = 0;
        tests_failed = 0;

        // Generate waveform dump
        $dumpfile("test_apb_interconnect.vcd");
        $dumpvars(0, test_apb_interconnect);

        $display("=== APB Interconnect Test Started ===");
        $display("");

        // Initialize and reset
        reset_dut();

        // =====================================================================
        // Test 1: ROM Address Decode (0x0000_0000 - 0x0000_7FFF)
        // =====================================================================
        $display("[Test 1] ROM Address Decode Test");
        test_slave_access(32'h0000_0000, 32'hA000_0000, "ROM - Base");
        test_slave_access(32'h0000_1000, 32'hA000_1000, "ROM - Mid");
        test_slave_access(32'h0000_7FFC, 32'hA000_7FFC, "ROM - Limit");

        // =====================================================================
        // Test 2: Flash Address Decode (0x0000_8000 - 0x0002_7FFF)
        // =====================================================================
        $display("");
        $display("[Test 2] Flash Address Decode Test");
        test_slave_access(32'h0000_8000, 32'hB000_8000, "Flash - Base");
        test_slave_access(32'h0001_0000, 32'hB001_0000, "Flash - Mid");
        test_slave_access(32'h0002_7FFC, 32'hB002_7FFC, "Flash - Limit");

        // =====================================================================
        // Test 3: SRAM Address Decode (0x0002_8000 - 0x0002_9FFF)
        // =====================================================================
        $display("");
        $display("[Test 3] SRAM Address Decode Test");
        test_slave_access(32'h0002_8000, 32'hC000_0000, "SRAM - Base");
        test_slave_access(32'h0002_9000, 32'hC000_1000, "SRAM - Mid");
        test_slave_access(32'h0002_9FFC, 32'hC000_1FFC, "SRAM - Limit");

        // =====================================================================
        // Test 4: Control Registers Decode (0x0002_A000 - 0x0002_AFFF)
        // =====================================================================
        $display("");
        $display("[Test 4] Control Registers Address Decode Test");
        test_slave_access(32'h0002_A000, 32'hD000_0000, "CTRL - Base");
        test_slave_access(32'h0002_A800, 32'hD000_0800, "CTRL - Mid");
        test_slave_access(32'h0002_AFFC, 32'hD000_0FFC, "CTRL - Limit");

        // =====================================================================
        // Test 5: Diagnostic Buffer Decode (0x0002_B000 - 0x0002_BFFF)
        // =====================================================================
        $display("");
        $display("[Test 5] Diagnostic Buffer Address Decode Test");
        test_slave_access(32'h0002_B000, 32'hE000_0000, "DIAG - Base");
        test_slave_access(32'h0002_B800, 32'hE000_0800, "DIAG - Mid");
        test_slave_access(32'h0002_BFFC, 32'hE000_0FFC, "DIAG - Limit");

        // =====================================================================
        // Test 6: Unmapped Address Error Handling
        // =====================================================================
        $display("");
        $display("[Test 6] Unmapped Address Error Handling Test");
        test_unmapped_address(32'h0002_C000, "After DIAG");
        test_unmapped_address(32'h0003_0000, "High address");
        test_unmapped_address(32'hFFFF_FFFC, "Very high address");

        // =====================================================================
        // Test 7: APB Write Transaction
        // =====================================================================
        $display("");
        $display("[Test 7] APB Write Transaction Test");
        test_write_transaction(32'h0002_8000, 32'hDEADBEEF, 4'b1111, "SRAM - Full word");
        test_write_transaction(32'h0002_A000, 32'h12345678, 4'b0011, "CTRL - Half word");

        // =====================================================================
        // Test 8: Sequential Accesses to Different Slaves
        // =====================================================================
        $display("");
        $display("[Test 8] Sequential Multi-Slave Access Test");
        test_slave_access(32'h0000_0000, 32'hA000_0000, "Sequential - ROM");
        test_slave_access(32'h0000_8000, 32'hB000_8000, "Sequential - Flash");
        test_slave_access(32'h0002_8000, 32'hC000_0000, "Sequential - SRAM");
        test_slave_access(32'h0002_A000, 32'hD000_0000, "Sequential - CTRL");
        test_slave_access(32'h0002_B000, 32'hE000_0000, "Sequential - DIAG");

        // =====================================================================
        // Test Summary
        // =====================================================================
        $display("");
        $display("=== Test Summary ===");
        $display("Tests Passed: %0d", tests_passed);
        $display("Tests Failed: %0d", tests_failed);
        $display("Total Errors: %0d", errors);
        
        if (errors == 0) begin
            $display("=== ALL TESTS PASSED ===");
        end else begin
            $display("=== SOME TESTS FAILED ===");
        end

        #100;
        $finish;
    end

    // =========================================================================
    // Test Helper Functions
    // =========================================================================
    
    // Test slave access with expected data
    task automatic test_slave_access(
        input logic [31:0] addr,
        input logic [31:0] expected_data,
        input string test_name
    );
        logic [31:0] read_data;
        logic error;
        
        apb_read(addr, read_data, error);
        
        if (error) begin
            $display("  [FAIL] %s - Unexpected error at addr 0x%08h", test_name, addr);
            errors++;
            tests_failed++;
        end else if (read_data != expected_data) begin
            $display("  [FAIL] %s - Data mismatch at addr 0x%08h: expected 0x%08h, got 0x%08h",
                     test_name, addr, expected_data, read_data);
            errors++;
            tests_failed++;
        end else begin
            $display("  [PASS] %s - addr 0x%08h, data 0x%08h", test_name, addr, read_data);
            tests_passed++;
        end
    endtask

    // Test unmapped address error
    task automatic test_unmapped_address(
        input logic [31:0] addr,
        input string test_name
    );
        logic [31:0] read_data;
        logic error;
        
        apb_read(addr, read_data, error);
        
        if (!error) begin
            $display("  [FAIL] %s - Expected error at addr 0x%08h but got none", test_name, addr);
            errors++;
            tests_failed++;
        end else if (read_data != 32'h0) begin
            $display("  [FAIL] %s - Expected data 0x00000000 on error, got 0x%08h",
                     test_name, read_data);
            errors++;
            tests_failed++;
        end else begin
            $display("  [PASS] %s - Error correctly reported at addr 0x%08h", test_name, addr);
            tests_passed++;
        end
    endtask

    // Test write transaction
    task automatic test_write_transaction(
        input logic [31:0] addr,
        input logic [31:0] wdata,
        input logic [3:0] strb,
        input string test_name
    );
        logic error;
        
        apb_write(addr, wdata, strb, error);
        
        if (error) begin
            $display("  [FAIL] %s - Unexpected error during write to addr 0x%08h",
                     test_name, addr);
            errors++;
            tests_failed++;
        end else begin
            $display("  [PASS] %s - Write successful to addr 0x%08h, data 0x%08h, strb 0b%04b",
                     test_name, addr, wdata, strb);
            tests_passed++;
        end
    endtask

    // =========================================================================
    // Timeout Watchdog
    // =========================================================================
    initial begin
        #SIMULATION_TIMEOUT;
        $display("ERROR: Test timeout!");
        $error("Simulation exceeded maximum time limit");
        $finish;
    end

endmodule
