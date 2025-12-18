# TCP Top-Level Specification

**Block:** `tcp_top`  
**Designer:** Integration Lead  
**Reviewer:** Microarchitecture Lead  

---

## Overview

Top-level integration of all TCP subsystems. Instantiates core, memories, interconnect, test controller, and JTAG interface.

---

## Interface

### External Clocks
- `clk_ref` - Reference clock input
- `pll_clk` - Optional PLL clock
- `tck` - JTAG clock

### External Resets
- `por_n` - Power-on reset
- `rst_ext_n` - External reset

### JTAG
- `tms` - Test mode select
- `tdi` - Test data in
- `tdo` - Test data out
- `trst_n` - Test reset

### Test Interface
- `scan_mode` - DFT scan mode
- `scan_en` - Scan enable
- `scan_in[N:0]` - Scan chain inputs
- `scan_out[N:0]` - Scan chain outputs

### Power Management
- `pd_cpu_en` - CPU domain enable
- `pd_test_en` - Test domain enable
- `iso_cpu_en` - CPU isolation
- `iso_test_en` - Test isolation

### Status/Debug
- `test_done` - Test completion flag
- `test_pass` - Test pass/fail
- `error_code[7:0]` - Error status

---

## Submodule Hierarchy

```
tcp_top
├── risc_v_core
├── rom_controller
├── flash_controller
├── sram_controller
├── apb_interconnect
├── test_mode_controller
├── clock_reset_manager
├── tap_controller
├── power_domain_controller
└── diagnostic_collector
```

---

## Integration Notes

### Clock Domains
- All submodules on `clk_cpu` except:
  - `tap_controller` on `tck`
  - `clock_reset_manager` generates clocks

### Reset Topology
- `rst_cold_n` → all modules
- `rst_cpu_n` → RISC-V core only
- Synchronizers in `clock_reset_manager`

### Memory Map
See `apb_interconnect` for address decode.

### DFT
- 4 scan chains across all modules
- Full MBIST coverage on ROM, SRAM, Flash
- ATPG patterns applied via JTAG bypass

---

## Verification Strategy

1. **Block-level:** Each submodule verified standalone
2. **Subsystem:** Memory + APB + Core integration
3. **Top-level:** Full boot sequence, mode transitions
4. **DFT:** Scan insertion, MBIST, ATPG coverage

---

## Design Notes

**Total Gates:** ~50-80K (with RISC-V core)  
**SRAM:** 40 KB (ROM + SRAM + Flash buffer)  
**Power Domains:** 4 (AON, CPU, Test, Memory)  
**Target Process:** 40nm and below
