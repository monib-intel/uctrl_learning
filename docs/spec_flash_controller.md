# Flash Controller Specification

**Block:** `flash_controller`  
**Designer:** TBD  
**Reviewer:** Microarchitecture Lead  

---

## Overview

Non-volatile flash for updateable test patterns. Read via CPU, write/erase via JTAG only.

---

## Interface

### Clocking & Reset
- `clk`
- `rst_n`

### Read Access (CPU)
- `flash_req` - Read request
- `flash_addr[16:0]` - Address (128KB, word-aligned)
- `flash_rdata[31:0]` - Read data
- `flash_ready` - Read complete (2-5 cycles)

### Write Access (JTAG)
- `jtag_we` - Write enable
- `jtag_addr[16:0]` - Write address
- `jtag_wdata[31:0]` - Write data
- `jtag_erase` - Block erase trigger
- `jtag_busy` - Programming in progress

### Status
- `flash_err` - Read/write error

---

## Behavior

### Read
1. Assert `flash_req=1`
2. Drive `flash_addr`
3. Wait for `flash_ready=1` (2-5 cycles)
4. Capture `flash_rdata`

### Write (JTAG only)
1. Assert `jtag_we=1`
2. Drive address and data
3. Wait for `jtag_busy=0`
4. Verify with read

### Erase
1. Assert `jtag_erase=1` with block address
2. Wait for completion (100-1000 cycles)

### Protection
- CPU has read-only access
- Write/erase gated by JTAG authentication

---

## Design Notes

**Size:** 128 KB  
**Technology:** Embedded flash macro (process-dependent)  
**Endurance:** 1K-10K erase cycles  
**Retention:** 10 years @ 125°C
