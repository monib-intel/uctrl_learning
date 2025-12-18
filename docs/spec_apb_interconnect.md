# APB Interconnect Specification

**Block:** `apb_interconnect`  
**Designer:** TBD  
**Reviewer:** Microarchitecture Lead  

---

## Overview

Simple peripheral bus interconnect. 1 master (CPU), N slaves (memories + MMIO).

---

## Interface

### Master Port (from CPU)
- `pclk`
- `preset_n`
- `m_paddr[31:0]` - Address
- `m_psel` - Select
- `m_penable` - Enable
- `m_pwrite` - Write (1) or Read (0)
- `m_pwdata[31:0]` - Write data
- `m_pstrb[3:0]` - Byte strobe
- `m_pready` - Transfer complete
- `m_prdata[31:0]` - Read data
- `m_pslverr` - Slave error

### Slave Ports (to peripherals)
Per slave N:
- `s[N]_paddr[31:0]`
- `s[N]_psel`
- `s[N]_penable`
- `s[N]_pwrite`
- `s[N]_pwdata[31:0]`
- `s[N]_pstrb[3:0]`
- `s[N]_pready`
- `s[N]_prdata[31:0]`
- `s[N]_pslverr`

---

## Behavior

### Address Decode
| Address Range        | Slave         |
|---------------------|---------------|
| 0x0000_0000 - 0x0000_7FFF | ROM (32KB)   |
| 0x0000_8000 - 0x0002_7FFF | Flash (128KB)|
| 0x0002_8000 - 0x0002_9FFF | SRAM (8KB)   |
| 0x0002_A000 - 0x0002_AFFF | Control Regs |
| 0x0002_B000 - 0x0002_BFFF | Diag Buffer  |

### Transaction
1. Master drives address, selects slave via `s[N]_psel=1`
2. Next cycle: `s[N]_penable=1` (ACCESS phase)
3. Slave responds with `pready=1` and data/error
4. Transaction completes

### Error Handling
- Unmapped addresses → `pslverr=1`, `prdata=0`
- No timeout (slaves must respond)

---

## Design Notes

**Protocol:** APB4 compatible  
**Slaves:** 5 (ROM, Flash, SRAM, CTRL, DIAG)  
**Arbitration:** None (single master)
