# Diagnostic Collector Specification

**Block:** `diagnostic_collector`  
**Designer:** TBD  
**Reviewer:** Microarchitecture Lead  

---

## Overview

Circular buffer for test failure diagnostics. Collects compressed fail data from BIST engines and scan operations.

---

## Interface

### Clocking & Reset
- `clk`
- `rst_n`

### Write Port (from BIST engines)
- `diag_we` - Write enable
- `diag_wdata[31:0]` - Diagnostic data
- `diag_full` - Buffer full indicator

### Read Port (to CPU/JTAG)
- `diag_req` - Read request
- `diag_addr[9:0]` - Entry address (1K entries)
- `diag_rdata[31:0]` - Diagnostic entry
- `diag_ready` - Read valid

### Control
- `diag_clear` - Clear buffer
- `diag_wr_ptr[9:0]` - Write pointer (read-only)
- `diag_rd_ptr[9:0]` - Read pointer
- `diag_count[9:0]` - Number of entries

---

## Behavior

### Write Operation
1. BIST engine asserts `diag_we=1`
2. Drives compressed fail data on `diag_wdata`
3. Entry written to `buffer[wr_ptr]`
4. `wr_ptr` increments (wraps at 1023)
5. If full, oldest entry overwritten

### Read Operation
1. CPU/JTAG sets `diag_rd_ptr` to desired entry
2. Assert `diag_req=1`
3. Capture `diag_rdata` when `diag_ready=1`

### Data Format
```
[31:28] fail_type (MBIST=1, ATPG=2, etc.)
[27:20] bist_id (engine number)
[19:0]  fail_addr (compressed address)
```

### Compression
- Store failing address + signature, not full pattern
- Limit to first 1K failures per test run

---

## Design Notes

**Capacity:** 1K entries × 32-bit  
**Technology:** SRAM-based circular buffer  
**Overflow:** Wrap (oldest overwritten)
