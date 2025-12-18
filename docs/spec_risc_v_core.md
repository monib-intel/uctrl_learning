# RISC-V Core Specification

**Block:** `risc_v_core`  
**Designer:** TBD  
**Reviewer:** Microarchitecture Lead  

---

## Overview

Minimal RV32I core for test sequence execution. Single-cycle or 2-stage pipeline.

---

## Interface

### Clocking & Reset
- `clk` - Core clock (10-100 MHz)
- `rst_n` - Active-low async reset

### Instruction Memory (IMem)
- `imem_req` - Fetch request
- `imem_addr[31:0]` - Instruction address
- `imem_rdata[31:0]` - Instruction data
- `imem_ready` - Memory ready
- `imem_err` - Bus error

### Data Memory (DMem)
- `dmem_req` - Data access request
- `dmem_we` - Write enable
- `dmem_be[3:0]` - Byte enable
- `dmem_addr[31:0]` - Data address
- `dmem_wdata[31:0]` - Write data
- `dmem_rdata[31:0]` - Read data
- `dmem_ready` - Memory ready
- `dmem_err` - Bus error

### Control
- `fetch_enable` - Core enable (halt when 0)
- `irq[31:0]` - Interrupt vector
- `debug_req` - Debug request
- `core_sleep` - WFI state indicator

### DFT
- `scan_mode` - Scan test mode
- `scan_en` - Scan enable
- `scan_in` - Scan chain input
- `scan_out` - Scan chain output

---

## Behavior

### Reset
- PC = 0x0000_0000
- All registers = 0
- Fetch disabled until `rst_n` released

### Execution
- Fetch from IMem on `imem_addr`
- Decode and execute RV32I instructions
- Memory access via DMem interface
- Single-cycle access (stall if `ready=0`)

### Interrupts
- Optional: Service IRQ[0] for test completion
- Jump to handler or poll status registers

### Debug
- Halt on `debug_req=1`
- Resume on `debug_req=0`

---

## Design Notes

**Recommended IP:** Ibex Core (lowRISC) or PicoRV32  
**Area Target:** 10-15K gates  
**Frequency:** 50 MHz @ 40nm  
**ISA:** RV32I only (no M/C extensions)
