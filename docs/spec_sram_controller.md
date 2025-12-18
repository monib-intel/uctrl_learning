# SRAM Controller Specification

**Block:** `sram_controller`  
**Designer:** TBD  
**Reviewer:** Microarchitecture Lead  

---

## Overview

Scratchpad SRAM for stack and data. Single-cycle read/write with byte enables.

---

## Interface

### Clocking & Reset
- `clk`
- `rst_n`

### Memory Access
- `sram_req` - Access request
- `sram_we` - Write enable (1=write, 0=read)
- `sram_be[3:0]` - Byte enable mask
- `sram_addr[12:0]` - Address (8KB, byte-aligned)
- `sram_wdata[31:0]` - Write data
- `sram_rdata[31:0]` - Read data
- `sram_ready` - Always 1 (single-cycle)

### DFT
- `mbist_en` - MBIST mode
- `mbist_done` - MBIST complete
- `mbist_fail` - MBIST failure
- `mbist_fail_addr[12:0]` - First failing address

### Power
- `ret_en` - Retention mode
- `pd_en` - Power domain enable

---

## Behavior

### Write
- Assert `sram_req=1`, `sram_we=1`
- Drive address, data, byte enables
- Data written on rising edge of `clk`

### Read
- Assert `sram_req=1`, `sram_we=0`
- Drive address
- Capture `sram_rdata` on next rising edge

### Byte Enables
- `be[0]` = byte 0 (bits 7:0)
- `be[1]` = byte 1 (bits 15:8)
- `be[2]` = byte 2 (bits 23:16)
- `be[3]` = byte 3 (bits 31:24)

### MBIST
- March C+ algorithm
- Report first failing address

---

## Design Notes

**Size:** 8 KB (2K words × 32-bit)  
**Latency:** 1 cycle (combinational read)  
**ECC:** Optional parity/ECC for in-field diagnostics
