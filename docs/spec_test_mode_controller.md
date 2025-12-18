# Test Mode Controller Specification

**Block:** `test_mode_controller`  
**Designer:** TBD  
**Reviewer:** Microarchitecture Lead  

---

## Overview

FSM-based test orchestrator. Manages transitions between ATPG, MBIST, LBIST, and analog test modes.

---

## Interface

### Clocking & Reset
- `clk`
- `rst_n`

### Control (from CPU/JTAG)
- `mode_req[3:0]` - Requested mode (IDLE=0, ATPG=1, MBIST=2, LBIST=3, ANALOG=4)
- `mode_ack` - Mode entry acknowledged
- `mode_start` - Begin test execution
- `mode_done` - Test complete
- `mode_err` - Error encountered

### BIST Engines
Per engine N:
- `bist[N]_en` - Enable engine
- `bist[N]_done` - Engine complete
- `bist[N]_fail` - Engine failure

### Power/Clock Control
- `pd_test_en` - Test domain power enable
- `clk_gate_override` - Disable clock gating
- `scan_mode` - Enable scan mode

### JTAG Override
- `jtag_override` - ATE takes direct control
- `jtag_release` - Release back to TCP

---

## Behavior

### State Machine
```
IDLE → ENTRY → EXEC → COLLECT → EXIT → IDLE
       ↓ (error)
     ERROR (sticky until reset)
```

### Mode Transitions
1. CPU writes `mode_req`
2. FSM enters ENTRY, initializes resources
3. Assert `mode_ack`
4. CPU writes `mode_start`
5. FSM enters EXEC, enables BIST engines
6. Wait for `bist[*]_done`
7. COLLECT results, compress diagnostics
8. EXIT, restore safe state
9. Return to IDLE

### Priority Arbitration
1. ERROR (highest)
2. JTAG override
3. ATPG
4. LBIST
5. MBIST
6. ANALOG

### Watchdog
- 1M cycle timeout per state
- Transition to ERROR on timeout

---

## Design Notes

**States:** 6 (IDLE, ENTRY, EXEC, COLLECT, EXIT, ERROR)  
**Modes:** 5 (IDLE, ATPG, MBIST, LBIST, ANALOG)  
**Max BIST Engines:** 32
