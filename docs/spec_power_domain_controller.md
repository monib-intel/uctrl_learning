# Power Domain Controller Specification

**Block:** `power_domain_controller`  
**Designer:** TBD  
**Reviewer:** Microarchitecture Lead  

---

## Overview

Manages power domain sequencing, isolation, and retention for TCP subsystems.

---

## Interface

### Control (from Test Mode Controller)
- `pd_cpu_req` - CPU domain power request
- `pd_test_req` - Test domain power request
- `pd_mem_req` - Memory domain power request

### Power Management Unit (PMU)
Per domain:
- `pd_en` - Power enable to PMU
- `pd_ack` - Power stable from PMU
- `iso_en` - Isolation cell enable
- `ret_en` - Retention flop enable

### Status
- `pd_cpu_on` - CPU domain powered
- `pd_test_on` - Test domain powered
- `pd_mem_on` - Memory domain powered

---

## Behavior

### Power-Up Sequence
1. Assert `iso_en=1` (isolate outputs)
2. Assert `pd_en=1` (request power)
3. Wait for `pd_ack=1` (PMU confirms stable)
4. De-assert `iso_en=0` (connect domain)
5. Release reset for domain

### Power-Down Sequence
1. Assert reset for domain
2. Assert `iso_en=1` (isolate outputs)
3. Optionally `ret_en=1` (save state)
4. De-assert `pd_en=0` (remove power)
5. Wait for `pd_ack=0`

### Retention Mode
- Save critical state (SRAM contents, CPU registers)
- Enable when entering low-power test modes
- Restore on power-up

---

## Design Notes

**Domains:** 3 (CPU, Test, Memory)  
**AON Domain:** JTAG TAP, POR, RTC (always powered)  
**UPF Driven:** Power intent specified in UPF file
