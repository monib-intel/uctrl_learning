# ROM Controller Specification

**Block:** `rom_controller`  
**Designer:** TBD  
**Reviewer:** Microarchitecture Lead  

---

## Overview

Boot ROM controller. Stores critical test patterns and boot code. Synchronous read, 1-cycle latency.

---

## Interface

### Clocking & Reset
- `clk`
- `rst_n`

### Memory Access
- `rom_req` - Access request
- `rom_addr[14:0]` - Address (32KB, word-aligned)
- `rom_rdata[31:0]` - Read data
- `rom_ready` - Data valid (typically 1-cycle after req)

### DFT
- `mbist_en` - MBIST mode enable
- `mbist_done` - MBIST complete
- `mbist_fail` - MBIST failure flag

---

## Behavior

### Read Operation
1. Assert `rom_req=1`
2. Drive `rom_addr`
3. Wait 1 cycle
4. Capture `rom_rdata` when `rom_ready=1`

### Initialization
- ROM contents loaded via synthesis `.mem` file
- Address range: 0x0000_0000 - 0x0000_7FFF

### MBIST
- March algorithm when `mbist_en=1`
- Assert `mbist_done` on completion
- Set `mbist_fail` if errors detected

---

## Design Notes

**Size:** 32 KB (8K words × 32-bit)  
**Latency:** 1 cycle  
**Technology:** Standard cell memory compiler or hard macro
