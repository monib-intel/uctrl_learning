# Clock & Reset Manager Specification

**Block:** `clock_reset_manager`  
**Designer:** TBD  
**Reviewer:** Microarchitecture Lead  

---

## Overview

Manages clock domains, gating, and reset synchronization across TCP.

---

## Interface

### External Inputs
- `clk_ref` - Reference clock (crystal)
- `pll_clk` - PLL output (optional)
- `por_n` - Power-on reset
- `rst_ext_n` - External reset pin

### Clock Outputs
- `clk_cpu` - CPU domain clock
- `clk_test` - Test/JTAG domain clock

### Reset Outputs
- `rst_cold_n` - Cold reset (all domains)
- `rst_cpu_n` - CPU reset
- `rst_test_n` - Test logic reset

### Control
- `clk_gate_en` - Enable clock gating
- `clk_div_sel[2:0]` - Clock divider (÷1, ÷2, ÷4, ÷8)
- `test_mode` - Force clocks on

### Status
- `pll_locked` - PLL lock indicator
- `rst_done` - Reset sequence complete

---

## Behavior

### Clock Generation
- `clk_cpu` = `pll_clk` ÷ `clk_div_sel` (or `clk_ref` in test mode)
- `clk_test` = async from JTAG TCK or divided `clk_ref`

### Clock Gating
- Gate when `clk_gate_en=1` AND not in `test_mode`
- Use ICG cells (glitch-free)

### Reset Sequence
1. Assert all resets on `por_n=0`
2. Wait for VDD stable and `pll_locked=1`
3. Hold `rst_cold_n=0` for 256 `clk_ref` cycles (debounce)
4. Release `rst_cold_n`
5. After 16 cycles, release `rst_cpu_n`, `rst_test_n`
6. Assert `rst_done=1`

### Reset Synchronization
- Async assertion
- Sync de-assertion (2-stage synchronizer per domain)

---

## Design Notes

**Clock Domains:** 3 (CPU, Test, Reference)  
**Reset Domains:** 3 (Cold, CPU, Test)  
**Max Frequency:** 100 MHz (clk_cpu)
