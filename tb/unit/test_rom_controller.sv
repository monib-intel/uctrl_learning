// ROM Controller Testbench
// Designer: Copilot
//
// Unit test for ROM controller with MBIST verification

`timescale 1ns/1ps

module test_rom_controller;

    // Clock and reset
    logic        clk;
    logic        rst_n;

    // Memory access interface
    logic        rom_req;
    logic [14:0] rom_addr;
    logic [31:0] rom_rdata;
    logic        rom_ready;

    // DFT interface
    logic        mbist_en;
    logic        mbist_done;
    logic        mbist_fail;

    // Instantiate DUT
    rom_controller dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .rom_req    (rom_req),
        .rom_addr   (rom_addr),
        .rom_rdata  (rom_rdata),
        .rom_ready  (rom_ready),
        .mbist_en   (mbist_en),
        .mbist_done (mbist_done),
        .mbist_fail (mbist_fail)
    );

    // Clock generation (100 MHz = 10 ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize signals
        rst_n     = 0;
        rom_req   = 0;
        rom_addr  = 15'h0;
        mbist_en  = 0;

        // Generate waveform dump
        $dumpfile("test_rom_controller.vcd");
        $dumpvars(0, test_rom_controller);

        // Reset sequence
        #20;
        rst_n = 1;
        #10;

        $display("=== ROM Controller Test Started ===");

        // Test 1: Initialize ROM with test data
        $display("\n[Test 1] Initializing ROM with test pattern");
        for (int i = 0; i < 100; i++) begin
            dut.rom_mem[i] = 32'hDEAD_0000 + i;
        end
        $display("[Test 1] ROM initialized with test pattern");

        // Test 2: Basic read operation
        $display("\n[Test 2] Testing basic read operation");
        @(posedge clk);
        rom_req  = 1;
        rom_addr = 15'h0000;  // Word address 0 (byte address 0x0000)
        @(posedge clk);
        rom_req  = 0;
        @(posedge clk);
        
        if (rom_ready && rom_rdata == 32'hDEAD_0000) begin
            $display("[Test 2] PASS - Read address 0x0000: 0x%08h", rom_rdata);
        end else begin
            $display("[Test 2] FAIL - Expected ready=1 and data=0xDEAD0000, got ready=%b, data=0x%08h", 
                     rom_ready, rom_rdata);
        end

        // Test 3: Multiple sequential reads
        $display("\n[Test 3] Testing sequential reads");
        for (int i = 0; i < 5; i++) begin
            @(posedge clk);
            rom_req  = 1;
            rom_addr = (i * 4);  // Byte addresses: 0, 4, 8, 12, 16
            @(posedge clk);
            rom_req  = 0;
            @(posedge clk);
            
            if (rom_ready) begin
                $display("[Test 3] Read addr 0x%04h: 0x%08h (expected 0x%08h)", 
                         i*4, rom_rdata, 32'hDEAD_0000 + i);
            end else begin
                $display("[Test 3] FAIL - Ready signal not asserted for address %d", i);
            end
        end

        // Test 4: Verify 1-cycle latency
        $display("\n[Test 4] Verifying 1-cycle read latency");
        @(posedge clk);
        rom_req  = 1;
        rom_addr = 15'h0010;  // Byte address 0x0010 = word 4
        @(posedge clk);
        // At this clock edge, data should be ready
        if (rom_ready && rom_rdata == 32'hDEAD_0004) begin
            $display("[Test 4] PASS - 1-cycle latency verified");
        end else begin
            $display("[Test 4] FAIL - Latency check failed, ready=%b, data=0x%08h", 
                     rom_ready, rom_rdata);
        end
        rom_req = 0;
        @(posedge clk);

        // Test 5: Read from different addresses
        $display("\n[Test 5] Testing random address access");
        test_read_addr(15'h0000, 32'hDEAD_0000);  // Word 0
        test_read_addr(15'h0020, 32'hDEAD_0008);  // Word 8  
        test_read_addr(15'h0040, 32'hDEAD_0010);  // Word 16
        test_read_addr(15'h0100, 32'hDEAD_0040);  // Word 64

        // Test 6: MBIST functionality
        $display("\n[Test 6] Testing MBIST functionality");
        @(posedge clk);
        mbist_en = 1;
        $display("[Test 6] MBIST enabled");
        
        // Wait for MBIST to complete (with timeout)
        fork
            begin
                wait(mbist_done == 1);
                $display("[Test 6] MBIST completed");
                if (mbist_fail) begin
                    $display("[Test 6] MBIST FAIL - Errors detected");
                end else begin
                    $display("[Test 6] MBIST PASS - No errors detected");
                end
            end
            begin
                repeat(20000) @(posedge clk);
                $display("[Test 6] TIMEOUT - MBIST did not complete in time");
                $fatal(1, "MBIST timeout");
            end
        join_any
        disable fork;

        @(posedge clk);
        mbist_en = 0;
        @(posedge clk);

        // Test 7: Normal operation after MBIST
        $display("\n[Test 7] Testing normal operation after MBIST");
        test_read_addr(15'h0000, 32'h0);  // After MBIST, memory should contain test pattern
        
        $display("\n=== All Tests Completed ===");
        #100;
        $finish;
    end

    // Helper task for read operations
    task test_read_addr(input logic [14:0] addr, input logic [31:0] expected);
        @(posedge clk);
        rom_req  = 1;
        rom_addr = addr;
        @(posedge clk);
        rom_req  = 0;
        @(posedge clk);
        
        if (rom_ready && rom_rdata == expected) begin
            $display("  Read addr 0x%04h: PASS (data=0x%08h)", addr, rom_rdata);
        end else begin
            $display("  Read addr 0x%04h: FAIL (expected=0x%08h, got=0x%08h, ready=%b)", 
                     addr, expected, rom_rdata, rom_ready);
        end
    endtask

    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Test timeout!");
        $fatal(1, "Simulation timeout");
    end

endmodule
