# JTAG TAP Controller Specification

**Block:** `tap_controller`  
**Designer:** TBD  
**Reviewer:** Microarchitecture Lead  

---

## Overview

IEEE 1149.1 compliant Test Access Port. Provides external JTAG interface for ATE and debug.

---

## Interface

### JTAG Pins
- `TCK` - Test clock (async to system clocks)
- `TMS` - Test mode select
- `TDI` - Test data in
- `TDO` - Test data out
- `TRST_n` - Test reset (optional)

### Internal Registers
- `dr_bypass[0]` - 1-bit bypass
- `dr_idcode[31:0]` - Device ID code
- `dr_tcp_ctrl[31:0]` - TCP control register
- `dr_tcp_status[31:0]` - TCP status register

### IJTAG Interface
- `ijtag_select` - Instrument select
- `ijtag_capture` - Capture trigger
- `ijtag_shift` - Shift enable
- `ijtag_update` - Update trigger
- `ijtag_tdi` - Scan data to instruments
- `ijtag_tdo` - Scan data from instruments

---

## Behavior

### TAP State Machine
Standard IEEE 1149.1 16-state FSM driven by TMS.

### Instruction Register
- `BYPASS` (0x0) - 1-bit bypass
- `IDCODE` (0x1) - Read device ID
- `TCP_CTRL` (0x8) - Access TCP control
- `TCP_STATUS` (0x9) - Read TCP status
- `IJTAG_ACCESS` (0xA) - IJTAG network access

### Data Registers
- **BYPASS:** Pass TDI → TDO
- **IDCODE:** `{version[3:0], part[15:0], manufacturer[10:0], 1'b1}`
- **TCP_CTRL:** Mode select, start, reset
- **TCP_STATUS:** Current state, error flags

### IJTAG Access
- Select IJTAG_ACCESS instruction
- Shift data through internal IJTAG network
- Update on UPDATE-DR state

---

## Design Notes

**Protocol:** IEEE 1149.1-2001  
**TCK Max:** 10 MHz  
**ID Code:** TBD (assign manufacturer ID)  
**IR Length:** 4 bits
