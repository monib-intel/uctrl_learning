// =============================================================================
// SRAM Controller Testbench
// =============================================================================
// Module: test_sram_controller
// Designer: Copilot
// 
// Description:
//   Unit testbench for SRAM controller. Verifies:
//   - Single-cycle read/write operations
//   - Byte enable functionality
//   - MBIST (March C+) algorithm
//   - Power domain control
//
// =============================================================================

`timescale 1ns/1ps

module test_sram_controller;

    // =========================================================================
    // Clock and Reset
    // =========================================================================
    logic clk;
    logic rst_n;

    // Clock generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period
    end

    // =========================================================================
    // DUT Signals
    // =========================================================================
    logic        sram_req;
    logic        sram_we;
    logic [3:0]  sram_be;
    logic [12:0] sram_addr;
    logic [31:0] sram_wdata;
    logic [31:0] sram_rdata;
    logic        sram_ready;
    logic        mbist_en;
    logic        mbist_done;
    logic        mbist_fail;
    logic [12:0] mbist_fail_addr;
    logic        ret_en;
    logic        pd_en;

    // =========================================================================
    // DUT Instantiation
    // =========================================================================
    sram_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .sram_req(sram_req),
        .sram_we(sram_we),
        .sram_be(sram_be),
        .sram_addr(sram_addr),
        .sram_wdata(sram_wdata),
        .sram_rdata(sram_rdata),
        .sram_ready(sram_ready),
        .mbist_en(mbist_en),
        .mbist_done(mbist_done),
        .mbist_fail(mbist_fail),
        .mbist_fail_addr(mbist_fail_addr),
        .ret_en(ret_en),
        .pd_en(pd_en)
    );

    // =========================================================================
    // Test Variables
    // =========================================================================
    int errors;
    int tests_passed;
    int tests_failed;
    logic [31:0] read_data;

    // =========================================================================
    // Helper Tasks
    // =========================================================================
    
    // Reset task
    task automatic reset_dut();
        rst_n = 0;
        sram_req = 0;
        sram_we = 0;
        sram_be = 4'b0000;
        sram_addr = 13'h0;
        sram_wdata = 32'h0;
        mbist_en = 0;
        ret_en = 0;
        pd_en = 1;  // Power domain enabled by default
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
    endtask

    // Write to SRAM
    task automatic write_sram(input logic [12:0] addr, 
                              input logic [31:0] data,
                              input logic [3:0] be);
        @(posedge clk);
        sram_req = 1;
        sram_we = 1;
        sram_addr = addr;
        sram_wdata = data;
        sram_be = be;
        @(posedge clk);
        sram_req = 0;
        sram_we = 0;
    endtask

    // Read from SRAM
    task automatic read_sram(input logic [12:0] addr, 
                             output logic [31:0] data);
        @(posedge clk);
        sram_req = 1;
        sram_we = 0;
        sram_addr = addr;
        @(posedge clk);
        data = sram_rdata;
        sram_req = 0;
    endtask

    // Check read data
    task automatic check_data(input logic [31:0] expected, 
                              input logic [31:0] actual,
                              input string test_name);
        if (expected === actual) begin
            $display("[PASS] %s: Expected=0x%h, Actual=0x%h", 
                     test_name, expected, actual);
            tests_passed++;
        end else begin
            $display("[FAIL] %s: Expected=0x%h, Actual=0x%h", 
                     test_name, expected, actual);
            tests_failed++;
            errors++;
        end
    endtask

    // =========================================================================
    // Test Procedures
    // =========================================================================

    // Test 1: Basic Write/Read
    task automatic test_basic_write_read();
        logic [31:0] test_data, read_data;
        
        $display("\n=== Test 1: Basic Write/Read ===");
        
        // Test word-aligned writes and reads
        test_data = 32'hDEADBEEF;
        write_sram(13'h0000, test_data, 4'b1111);  // Write to address 0
        read_sram(13'h0000, read_data);
        check_data(test_data, read_data, "Basic Write/Read @ 0x0000");
        
        test_data = 32'hCAFEBABE;
        write_sram(13'h0004, test_data, 4'b1111);  // Write to address 4
        read_sram(13'h0004, read_data);
        check_data(test_data, read_data, "Basic Write/Read @ 0x0004");
        
        test_data = 32'h12345678;
        write_sram(13'h1FFC, test_data, 4'b1111);  // Write to last address (8191)
        read_sram(13'h1FFC, read_data);
        check_data(test_data, read_data, "Basic Write/Read @ 0x1FFC (end)");
    endtask

    // Test 2: Byte Enable Logic
    task automatic test_byte_enables();
        logic [31:0] initial_data, read_data;
        
        $display("\n=== Test 2: Byte Enable Logic ===");
        
        // Initialize with known data
        initial_data = 32'h00000000;
        write_sram(13'h0100, initial_data, 4'b1111);
        
        // Write byte 0 only
        write_sram(13'h0100, 32'h000000AA, 4'b0001);
        read_sram(13'h0100, read_data);
        check_data(32'h000000AA, read_data, "Byte Enable [0]");
        
        // Write byte 1 only
        write_sram(13'h0100, 32'h0000BB00, 4'b0010);
        read_sram(13'h0100, read_data);
        check_data(32'h0000BBAA, read_data, "Byte Enable [1]");
        
        // Write byte 2 only
        write_sram(13'h0100, 32'h00CC0000, 4'b0100);
        read_sram(13'h0100, read_data);
        check_data(32'h00CCBBAA, read_data, "Byte Enable [2]");
        
        // Write byte 3 only
        write_sram(13'h0100, 32'hDD000000, 4'b1000);
        read_sram(13'h0100, read_data);
        check_data(32'hDDCCBBAA, read_data, "Byte Enable [3]");
        
        // Test partial byte enables
        write_sram(13'h0200, 32'h00000000, 4'b1111);
        write_sram(13'h0200, 32'h12345678, 4'b0011);  // Write lower half-word
        read_sram(13'h0200, read_data);
        check_data(32'h00005678, read_data, "Byte Enable [1:0]");
        
        write_sram(13'h0200, 32'h12345678, 4'b1100);  // Write upper half-word
        read_sram(13'h0200, read_data);
        check_data(32'h12345678, read_data, "Byte Enable [3:2]");
    endtask

    // Test 3: Single-Cycle Operation
    task automatic test_single_cycle();
        $display("\n=== Test 3: Single-Cycle Operation ===");
        
        // Verify ready is always asserted
        if (sram_ready !== 1'b1) begin
            $display("[FAIL] Ready signal not asserted");
            tests_failed++;
            errors++;
        end else begin
            $display("[PASS] Ready signal always asserted");
            tests_passed++;
        end
        
        // Back-to-back write operations
        @(posedge clk);
        sram_req = 1; sram_we = 1; sram_addr = 13'h0300; 
        sram_wdata = 32'hAAAAAAAA; sram_be = 4'b1111;
        
        @(posedge clk);
        sram_addr = 13'h0304; sram_wdata = 32'hBBBBBBBB;
        
        @(posedge clk);
        sram_addr = 13'h0308; sram_wdata = 32'hCCCCCCCC;
        
        @(posedge clk);
        sram_req = 0; sram_we = 0;
        
        // Verify back-to-back writes
        read_sram(13'h0300, read_data);
        check_data(32'hAAAAAAAA, read_data, "Back-to-back Write 1");
        
        read_sram(13'h0304, read_data);
        check_data(32'hBBBBBBBB, read_data, "Back-to-back Write 2");
        
        read_sram(13'h0308, read_data);
        check_data(32'hCCCCCCCC, read_data, "Back-to-back Write 3");
    endtask

    // Test 4: MBIST Functionality
    task automatic test_mbist();
        int timeout;
        
        $display("\n=== Test 4: MBIST (March C+) ===");
        
        // Write some initial data to memory
        write_sram(13'h0000, 32'h12345678, 4'b1111);
        write_sram(13'h0100, 32'hABCDEF00, 4'b1111);
        
        // Start MBIST
        @(posedge clk);
        mbist_en = 1;
        
        // Wait for MBIST to complete (with timeout)
        timeout = 0;
        while (!mbist_done && timeout < 10000) begin
            @(posedge clk);
            timeout++;
        end
        
        if (timeout >= 10000) begin
            $display("[FAIL] MBIST timeout");
            tests_failed++;
            errors++;
        end else if (mbist_fail) begin
            $display("[FAIL] MBIST detected failure at address 0x%h", mbist_fail_addr);
            tests_failed++;
            errors++;
        end else begin
            $display("[PASS] MBIST completed successfully in %0d cycles", timeout);
            tests_passed++;
        end
        
        // Deassert MBIST
        @(posedge clk);
        mbist_en = 0;
        @(posedge clk);
        
        // Verify MBIST cleared the done flag
        if (mbist_done === 1'b0) begin
            $display("[PASS] MBIST done flag cleared");
            tests_passed++;
        end else begin
            $display("[FAIL] MBIST done flag not cleared");
            tests_failed++;
            errors++;
        end
    endtask

    // Test 5: Power Domain Control
    task automatic test_power_domain();
        logic [31:0] test_data, read_data;
        
        $display("\n=== Test 5: Power Domain Control ===");
        
        // Write data with power domain enabled
        test_data = 32'h55555555;
        write_sram(13'h0400, test_data, 4'b1111);
        read_sram(13'h0400, read_data);
        check_data(test_data, read_data, "Write with pd_en=1");
        
        // Enable retention mode
        @(posedge clk);
        ret_en = 1;
        @(posedge clk);
        
        // Try to write in retention mode (should not write)
        write_sram(13'h0400, 32'hAAAAAAAA, 4'b1111);
        
        // Disable retention
        @(posedge clk);
        ret_en = 0;
        @(posedge clk);
        
        // Read back - should still have original data
        read_sram(13'h0400, read_data);
        check_data(test_data, read_data, "Data retained during retention mode");
        
        // Test power domain disable
        @(posedge clk);
        pd_en = 0;
        @(posedge clk);
        
        // Try to write with power domain disabled
        write_sram(13'h0400, 32'h99999999, 4'b1111);
        
        // Re-enable power domain
        @(posedge clk);
        pd_en = 1;
        @(posedge clk);
        
        // Data should be preserved when pd_en disabled
        read_sram(13'h0400, read_data);
        check_data(test_data, read_data, "Data preserved with pd_en=0");
    endtask

    // Test 6: Address Range Test
    task automatic test_address_range();
        logic [31:0] test_data, read_data;
        
        $display("\n=== Test 6: Address Range ===");
        
        // Test minimum address
        test_data = 32'h11111111;
        write_sram(13'h0000, test_data, 4'b1111);
        read_sram(13'h0000, read_data);
        check_data(test_data, read_data, "Address 0x0000 (min)");
        
        // Test maximum address (8KB = 8192 bytes, max word addr = 8188)
        test_data = 32'h22222222;
        write_sram(13'h1FFC, test_data, 4'b1111);
        read_sram(13'h1FFC, read_data);
        check_data(test_data, read_data, "Address 0x1FFC (max)");
        
        // Test mid-range addresses
        test_data = 32'h33333333;
        write_sram(13'h0800, test_data, 4'b1111);
        read_sram(13'h0800, read_data);
        check_data(test_data, read_data, "Address 0x0800 (mid)");
    endtask

    // =========================================================================
    // Main Test Sequence
    // =========================================================================
    initial begin
        // Initialize
        errors = 0;
        tests_passed = 0;
        tests_failed = 0;
        
        $display("\n");
        $display("========================================");
        $display("  SRAM Controller Testbench");
        $display("========================================");
        
        // Reset
        reset_dut();
        
        // Run tests
        test_basic_write_read();
        test_byte_enables();
        test_single_cycle();
        test_mbist();
        test_power_domain();
        test_address_range();
        
        // Summary
        $display("\n========================================");
        $display("  Test Summary");
        $display("========================================");
        $display("  Tests Passed: %0d", tests_passed);
        $display("  Tests Failed: %0d", tests_failed);
        $display("  Total Errors: %0d", errors);
        
        if (errors == 0) begin
            $display("\n  *** ALL TESTS PASSED ***\n");
        end else begin
            $display("\n  *** TESTS FAILED ***\n");
        end
        
        $display("========================================\n");
        
        // Finish simulation
        #100;
        $finish;
    end

    // =========================================================================
    // Waveform Dumping
    // =========================================================================
    initial begin
        $dumpfile("sram_controller_tb.vcd");
        $dumpvars(0, test_sram_controller);
    end

    // =========================================================================
    // Timeout Watchdog
    // =========================================================================
    initial begin
        #1000000;  // 1ms timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

endmodule
