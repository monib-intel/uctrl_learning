# DFT Test Control Processor - Microarchitecture Specification

## 1. RTL Design Overview

This document describes the microarchitectural implementation details of the TCP, focusing on reusable RTL blocks, interfaces, and timing/reset domains. This specification supports both the RISC-V core option and the FSM-based sequencer alternative.

---

## 2. RISC-V Core Microarchitecture

### 2.1 Core Selection Rationale

**Target:** RV32I base ISA (no compressed, no multiply/divide)
- **Area:** ~10-15K gates for minimal implementation
- **Performance:** Single-cycle or 2-stage pipeline (no caching needed)
- **Justification:** Test sequences are inherently low-throughput; simplicity favored over performance

**Recommended IP Reuse Options:**
1. **Ibex Core** (lowRISC) - 2-stage pipeline, open-source, proven in OpenTitan
2. **PicoRV32** - Minimal footprint, configurable pipeline depth
3. **VexRiscv** - Scala-generated, highly parameterizable
4. **Custom Minimal Core** - For maximum DFT control (scan insertion, clock gating)

### 2.2 Core Interface Specification

**Instruction Memory Interface (IMem)**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
imem_req             | 1     | Output    | Instruction fetch request
imem_addr            | 32    | Output    | Instruction address (byte)
imem_rdata           | 32    | Input     | Instruction read data
imem_ready           | 1     | Input     | Memory ready signal
imem_err             | 1     | Input     | Bus error indicator
```

**Data Memory Interface (DMem)**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
dmem_req             | 1     | Output    | Data access request
dmem_we              | 1     | Output    | Write enable (1=write)
dmem_be              | 4     | Output    | Byte enable mask
dmem_addr            | 32    | Output    | Data address (byte)
dmem_wdata           | 32    | Output    | Write data
dmem_rdata           | 32    | Input     | Read data
dmem_ready           | 1     | Input     | Memory ready signal
dmem_err             | 1     | Input     | Bus error indicator
```

**Control & Status**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
irq                  | 32    | Input     | Interrupt request vector
debug_req            | 1     | Input     | External debug request
fetch_enable         | 1     | Input     | Core enable (0=halt)
core_sleep           | 1     | Output    | Core in WFI state
```

### 2.3 Register File Considerations

**Architecture:** 32 x 32-bit general purpose registers (x0-x31)

**DFT Requirements:**
- Full scan insertion on all flip-flops
- Shadow scan chain optional (for non-invasive observation)
- Register retention power domain (for low-power test modes)

**Area vs. Power Tradeoff:**
- Multi-ported register file (2R1W) vs. banked implementation
- Recommendation: Single-ported with stall logic (area-efficient)

### 2.4 Pipeline Structure

**Option A: Single-Cycle (No Pipeline)**
- All operations complete in one clock cycle
- Slow clock required (~10-50 MHz for typical process)
- Simplest DFT insertion, no hazard logic

**Option B: 2-Stage Pipeline (Fetch-Execute)**
```
Stage 1 (IF):  Instruction Fetch
Stage 2 (EX):  Decode + Execute + Memory + Writeback (combined)
```
- Minimal control hazards (1-cycle branch penalty)
- Clock can run faster (~50-100 MHz)
- Requires pipeline flush logic for DFT

**Recommendation:** Start with single-cycle, upgrade to 2-stage if timing closure fails

---

## 3. Memory Subsystem

### 3.1 Memory Map

```
Address Range        | Size    | Type      | Purpose
---------------------|---------|-----------|----------------------------
0x0000_0000          | 32 KB   | ROM       | Boot code + critical patterns
0x0000_8000          | 128 KB  | Flash     | Updateable test programs
0x0002_8000          | 8 KB    | SRAM      | Scratch RAM (data/stack)
0x0002_A000          | 4 KB    | MMIO      | Control registers
0x0002_B000          | 4 KB    | MMIO      | Diagnostic buffers
0x0002_C000          | -       | Reserved  | Future expansion
```

### 3.2 ROM (Pattern Storage)

**Interface:**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
rom_addr             | 15    | Input     | Address (word-aligned)
rom_rdata            | 32    | Output    | Read data
rom_ready            | 1     | Output    | Data valid
```

**Implementation Notes:**
- Synchronous read (1-cycle latency)
- Initialized via synthesis memory initialization file (.mem, .hex)
- Not scannable (read-only content assumed correct-by-construction)

**DFT Handling:**
- MBIST coverage via March algorithms (optional, depends on process node)
- Physical implementation: Standard cell memory compiler or custom array

### 3.3 Flash (Updateable Patterns)

**Interface:**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
flash_req            | 1     | Input     | Access request
flash_we             | 1     | Input     | Write enable (JTAG only)
flash_addr           | 17    | Input     | Address (word-aligned)
flash_wdata          | 32    | Input     | Write data
flash_rdata          | 32    | Output    | Read data
flash_ready          | 1     | Output    | Operation complete
flash_erase          | 1     | Input     | Block erase trigger
```

**Behavioral Requirements:**
- Read access: 2-5 clock cycles (buffered)
- Write/erase access: JTAG-initiated only (not from core)
- Endurance: 1K-10K cycles (sufficient for rare updates)

**DFT Considerations:**
- Flash macro typically has built-in BIST controller
- Scan chain insertion: Minimal (control FSM only, not data array)
- Retention: Non-volatile, maintains content during power-down

### 3.4 SRAM (Scratch Memory)

**Interface:**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
sram_req             | 1     | Input     | Access request
sram_we              | 1     | Input     | Write enable
sram_be              | 4     | Input     | Byte enable
sram_addr            | 13    | Input     | Address (byte-aligned)
sram_wdata           | 32    | Input     | Write data
sram_rdata           | 32    | Output    | Read data
sram_ready           | 1     | Output    | Always 1 (single-cycle)
```

**DFT Requirements:**
- Mandatory MBIST coverage (March C+ or equivalent)
- Scan multiplexers on address/data inputs for external test mode
- Optional parity/ECC (recommended for in-field diagnostics)

**Power Domain:**
- Always-on domain (retains stack/data during test mode transitions)
- Optional retention flops for ultra-low-power states

---

## 4. Clocking Architecture

### 4.1 Clock Domains

**Primary Clock Domains:**

| Domain Name      | Frequency  | Source         | Function                          |
|------------------|------------|--------------- |-----------------------------------|
| clk_cpu          | 10-100 MHz | PLL or Osc     | RISC-V core execution             |
| clk_test         | 1-50 MHz   | Divided/Async  | JTAG/IJTAG test operations        |
| clk_ref          | Fixed      | Crystal/Tester | Timestamp/counters (PVT monitors) |

**Clock Domain Crossing (CDC):**
- `clk_cpu` ↔ `clk_test`: Synchronizers on JTAG interface
- `clk_cpu` ↔ `clk_ref`: Async FIFO for monitor data capture

### 4.2 Clock Gating Strategy

**Functional Clock Gating:**
- Core: Gate when `fetch_enable = 0` or in WFI state
- Flash: Gate when no pending request
- SRAM: Gate per bank based on address decode

**DFT Override:**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
scan_mode            | 1     | Input     | Disable all clock gating
test_mode            | 1     | Input     | Force clocks on
```

**Gating Implementation:**
- Integrated clock gating (ICG) cells with glitch-free enable
- Placement: One level before leaf clock buffers
- Validation: CDC and RDC checks in synthesis/STA

### 4.3 Clock Generation

**PLL Requirements (if used):**
- Input: External reference (12-50 MHz crystal)
- Output: `clk_cpu` with programmable divider (÷1, ÷2, ÷4, ÷8)
- Lock detection: Status signal to TCP for reliable boot

**Bypass Mode:**
- Direct reference clock to all domains (for slow-speed ATPG)
- Multiplexer select controlled by `test_mode` pin

**JTAG Clock:**
- Fully asynchronous to `clk_cpu` (meets IEEE 1149.1 spec)
- Optional internal divider to generate `clk_test` from JTAG TCK

---

## 5. Reset Architecture

### 5.1 Reset Domains

**Reset Types:**

| Reset Name       | Scope       | Assertion           | De-assertion        |
|------------------|-------------|---------------------|---------------------|
| POR_n            | Chip-wide   | Power-on            | After supplies stable |
| rst_cold_n       | TCP + DUT   | External pin/JTAG   | Controlled release  |
| rst_cpu_n        | CPU only    | Software/mode ctrl  | Software sequence   |
| rst_debug_n      | Debug logic | Independent         | JTAG command        |

**Reset Tree Structure:**
```
POR_n ────┬──→ rst_cold_n ───┬──→ rst_cpu_n ──→ RISC-V Core
          │                   ├──→ Arbiter/Sequencer
          │                   └──→ Memory Controllers
          │
          └──→ PLL/Osc (always-on analog)
```

### 5.2 Reset Synchronization

**Asynchronous Assertion, Synchronous De-assertion:**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
rst_async_n          | 1     | Input     | Async reset input
rst_sync_n           | 1     | Output    | Synchronized to clk_cpu
```

**Implementation:**
- 2-stage synchronizer for de-assertion
- Reset assertion bypasses synchronizer (immediate)
- Per clock domain (rst_sync_cpu_n, rst_sync_test_n)

### 5.3 Reset Sequencing

**Power-On Reset Sequence:**
1. All supplies reach nominal voltage
2. POR_n de-asserts (analog circuit)
3. Wait for PLL lock (if applicable)
4. Release rst_cold_n after 256 clk_ref cycles (debounce)
5. CPU fetches from boot ROM address 0x0000_0000

**Power-On Reset Timing (WaveDrom):**
```wavedrom
{
  signal: [
    {name: 'VDD', wave: '0.1........', node: '..a'},
    {name: 'POR_n', wave: '0..1......', node: '...b'},
    {name: 'PLL_LOCK', wave: '0...1.....', node: '....c'},
    {name: 'clk_ref', wave: 'n........n', period: 0.5},
    {name: 'rst_cold_n', wave: '0.....1...', node: '......d'},
    {name: 'rst_cpu_n', wave: '0......1..', node: '.......e'},
    {name: 'PC', wave: 'x.......2.', data: ['0x0000_0000'], node: '.......f'},
    {name: 'State', wave: 'x.......2.', data: ['BOOT'], node: '.......g'}
  ],
  edge: [
    'a~>b Supply stable',
    'b~>c Analog POR release',
    'c~>d PLL locks',
    'd~>e Debounce delay (256 cycles)',
    'e~>f Reset release',
    'f->g CPU starts fetching'
  ],
  config: { hscale: 2 }
}
```

**Boot Sequence from ROM (WaveDrom):**
```wavedrom
{
  signal: [
    {name: 'clk_cpu', wave: 'p........'},
    {name: 'rst_cpu_n', wave: '01.......'},
    {name: 'PC', wave: 'x.2.3.4.5', data: ['0x000', '0x004', '0x008', '0x00C']},
    {name: 'imem_req', wave: '0.1.0.1.0', node: '..a...c'},
    {name: 'imem_addr', wave: 'x.2.x.3.x', data: ['0x000', '0x004'], node: '..b...d'},
    {name: 'imem_rdata', wave: 'x..2.x.3.', data: ['INSTR0', 'INSTR1']},
    {name: 'State', wave: 'x.2.3.4.5', data: ['FETCH', 'DECODE', 'EXEC', 'FETCH']}
  ],
  edge: [
    'a->b Fetch instruction 0',
    'c->d Fetch instruction 1'
  ],
  config: { hscale: 2 }
}
```

**Software-Initiated Reset:**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
sw_reset_req         | 1     | MMIO Reg  | Write 1 to trigger reset
sw_reset_ack         | 1     | MMIO Reg  | Read for completion status
```

---

## 6. Bus Interconnect

### 6.1 Bus Protocol Selection

**Recommended:** Simple peripheral bus (no burst, no cache coherency)

**Options:**
- **APB (AMBA Peripheral Bus):** Minimal complexity, wide tool support
- **Wishbone:** Open-source, similar complexity to APB
- **Custom:** Justified only if avoiding licensing concerns

**Interface Signals (APB-like):**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
paddr                | 32    | Master→Slave | Address
psel                 | 1     | Master→Slave | Slave select
penable              | 1     | Master→Slave | Enable (2nd cycle)
pwrite               | 1     | Master→Slave | Write (1) or Read (0)
pwdata               | 32    | Master→Slave | Write data
pstrb                | 4     | Master→Slave | Byte enable
pready               | 1     | Slave→Master | Transfer complete
prdata               | 32    | Slave→Master | Read data
pslverr              | 1     | Slave→Master | Error response
```

**APB Read Transaction (WaveDrom):**
```wavedrom
{
  signal: [
    {name: 'pclk', wave: 'p......'},
    {name: 'paddr', wave: 'x.2...x', data: ['0x2A000'], node: '..a'},
    {name: 'psel', wave: '0.1...0', node: '..b'},
    {name: 'penable', wave: '0..1.0.', node: '...c'},
    {name: 'pwrite', wave: '0......'},
    {name: 'pready', wave: '0...10.', node: '....d'},
    {name: 'prdata', wave: 'x....2x', data: ['0xDEAD'], node: '....e'},
    {},
    {name: 'State', wave: 'x.2.3.x', data: ['SETUP', 'ACCESS']}
  ],
  edge: [
    'a->b Address stable',
    'b->c Select asserted',
    'c->d Enable for access phase',
    'd->e Data valid when ready'
  ],
  config: { hscale: 2 }
}
```

**APB Write Transaction (WaveDrom):**
```wavedrom
{
  signal: [
    {name: 'pclk', wave: 'p......'},
    {name: 'paddr', wave: 'x.2...x', data: ['0x2A004']},
    {name: 'psel', wave: '0.1...0'},
    {name: 'penable', wave: '0..1.0.'},
    {name: 'pwrite', wave: '0.1...0', node: '..a'},
    {name: 'pwdata', wave: 'x.2...x', data: ['0xBEEF'], node: '..b'},
    {name: 'pstrb', wave: 'x.2...x', data: ['0xF']},
    {name: 'pready', wave: '0...10.'},
    {},
    {name: 'State', wave: 'x.2.3.x', data: ['SETUP', 'ACCESS']}
  ],
  edge: [
    'a~b Write with data'
  ],
  config: { hscale: 2 }
}
```

### 6.2 Address Decoder

**Functionality:**
- Decode CPU data address to select memory/MMIO block
- Generate per-slave `psel` signals
- Arbiter if multiple masters (CPU + JTAG)

**Error Handling:**
- Unmapped addresses return `pslverr = 1`
- CPU exception handler (if implemented) or ignore

---

## 7. MMIO Register Blocks

### 7.1 Control Register Space (0x0002_A000 - 0x0002_AFFF)

**Registers Overview:**

| Offset  | Name              | Access | Description                          |
|---------|-------------------|--------|--------------------------------------|
| 0x000   | TCP_CTRL          | RW     | Global control (enable, mode select) |
| 0x004   | TCP_STATUS        | RO     | Current state, error flags           |
| 0x008   | TCP_IRQ_EN        | RW     | Interrupt enable mask                |
| 0x00C   | TCP_IRQ_STATUS    | RW1C   | Interrupt pending (write 1 to clear) |
| 0x010   | MODE_CONFIG       | RW     | Test mode parameters (ATPG/MBIST)    |
| 0x014   | SEQUENCE_CTRL     | RW     | Pattern execution control            |
| 0x018   | SSN_CONFIG        | RW     | SSN budget, phasing control          |
| 0x01C   | TIMER_CONFIG      | RW     | Timeout/delay values                 |
| 0x100   | BIST_STATUS[0]    | RO     | MBIST engine 0 result                |
| ...     | ...               | ...    | ...                                  |
| 0x17C   | BIST_STATUS[31]   | RO     | MBIST engine 31 result               |
| 0x200   | SCAN_CTRL         | RW     | Scan chain select, shift count       |
| 0x204   | SCAN_DATA_IN      | WO     | Scan input data register             |
| 0x208   | SCAN_DATA_OUT     | RO     | Scan output data capture             |

### 7.2 Diagnostic Buffer (0x0002_B000 - 0x0002_BFFF)

**Structure:**
- Circular buffer for fail logs (1K entries × 32-bit)
- Writes: Automatic from BIST engines via hardware
- Reads: CPU or JTAG for external analysis
- Pointer registers: `DIAG_WR_PTR`, `DIAG_RD_PTR`

**Compression:**
- Failing address + signature (not full pattern)
- Example: `{fail_type[3:0], bist_id[7:0], addr[19:0]}`

---

## 8. Test Mode Controller FSM

### 8.1 State Machine

**States:**
```
IDLE        → Waiting for test command
ENTRY       → Mode-specific initialization (power, clocks)
EXEC        → Running test patterns/sequences
COLLECT     → Reading results, compressing diagnostics
EXIT        → Restore safe state, release resources
ERROR       → Fault detected, await external recovery
```

**Transitions:**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
mode_req             | 4     | Input     | Requested mode (ATPG/MBIST/etc)
mode_ack             | 1     | Output    | Mode entry complete
mode_done            | 1     | Input     | Test execution finished
mode_err             | 1     | Output    | Error encountered
```

**Test Mode Transition Timing (WaveDrom):**
```wavedrom
{
  signal: [
    {name: 'clk', wave: 'p...........'},
    {name: 'mode_req', wave: '0.1.0.......', data: ['MBIST']},
    {name: 'State', wave: '2.3.4..5.6.2', data: ['IDLE', 'ENTRY', 'EXEC', 'COLLECT', 'EXIT', 'IDLE'], node: '..a.b..c.d'},
    {name: 'mode_ack', wave: '0..10.......', node: '...e'},
    {name: 'bist_en', wave: '0...10....0.', node: '....f....g'},
    {name: 'bist_done', wave: '0.....10....', node: '......h'},
    {name: 'mode_done', wave: '0.......10..', node: '.......i'},
    {name: 'result', wave: 'x.......2.x.', data: ['PASS']}
  ],
  edge: [
    'a->e Request acknowledged',
    'b->f BIST engine enabled',
    'h->c Test completes',
    'c->i Results collected',
    'd~>a Return to idle'
  ],
  config: { hscale: 2 }
}
```

**JTAG Override Sequence (WaveDrom):**
```wavedrom
{
  signal: [
    {name: 'TCK', wave: 'p...........', period: 2},
    {name: 'TMS', wave: '01.0.1.0....', node: '.a...b'},
    {name: 'TDI', wave: 'x..2.3......', data: ['CMD', 'DATA']},
    {name: 'State', wave: '2.3.4.5.6...', data: ['IDLE', 'SELECT', 'SHIFT', 'EXIT', 'UPDATE']},
    {name: 'TCP_State', wave: '2......3..2.', data: ['NORMAL', 'BYPASS', 'NORMAL'], node: '......c...d'},
    {name: 'ate_control', wave: '0......1..0.', node: '......e...f'}
  ],
  edge: [
    'a~>b JTAG state machine',
    'c->e ATE takes control',
    'd->f Release to TCP'
  ],
  config: { hscale: 1.5 }
}
```

### 8.2 Mode Arbitration

**Priority (Highest to Lowest):**
1. ERROR (sticky until external clear)
2. JTAG override (direct ATE control)
3. ATPG (structural test)
4. LBIST (logic self-test)
5. MBIST (memory test)
6. Analog test
7. IDLE

**Resource Locking:**
- Mutex per shared resource (scan chains, power domains)
- Lock acquisition in ENTRY state, release in EXIT
- Timeout watchdog (1M cycles) to prevent deadlock

---

## 9. Power Management Integration

### 9.1 Power Domains

**Domain Definitions:**

| Domain Name  | Always-On | Contents                    | Control Signal    |
|--------------|-----------|----------------------------|-------------------|
| AON          | Yes       | POR, RTC, JTAG TAP         | N/A               |
| CPU          | No        | RISC-V core, SRAM          | pd_cpu_en         |
| TEST         | No        | Sequencer, BIST engines    | pd_test_en        |
| MEM          | No        | Flash controller           | pd_mem_en         |

### 9.2 Power Domain Interface

**Signals Per Domain:**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
pd_<domain>_en       | 1     | Output    | Power domain enable request
pd_<domain>_ack      | 1     | Input     | Power domain stable
iso_<domain>_en      | 1     | Output    | Isolation cell enable
ret_<domain>_en      | 1     | Output    | Retention enable
```

**Sequencing (Power-Up Example):**
1. Assert `iso_cpu_en = 1` (isolate outputs)
2. Assert `pd_cpu_en = 1` (request power)
3. Wait for `pd_cpu_ack = 1`
4. De-assert `iso_cpu_en = 0`
5. Release `rst_cpu_n`

---

## 10. JTAG/IJTAG Integration

### 10.1 TAP Controller Interface

**Standard JTAG Signals:**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
TCK                  | 1     | Input     | Test clock
TMS                  | 1     | Input     | Test mode select
TDI                  | 1     | Input     | Test data in
TDO                  | 1     | Output    | Test data out
TRST_n               | 1     | Input     | Test reset (optional)
```

**Internal JTAG Registers (IEEE 1149.1):**
- BYPASS: 1-bit pass-through
- IDCODE: 32-bit device identifier
- DTMCS: Debug transport module control (if debug supported)
- Custom: TCP_CONTROL, TCP_STATUS, FLASH_PROG

### 10.2 IJTAG Instrument Interface

**TCP as Instrument Manager:**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
ijtag_select         | 1     | Input     | Instrument selected
ijtag_si             | 1     | Input     | Scan data in
ijtag_so             | 1     | Output    | Scan data out
ijtag_capture        | 1     | Input     | Capture trigger
ijtag_shift          | 1     | Input     | Shift enable
ijtag_update         | 1     | Input     | Update trigger
```

**Segment Insertion Bits (SIB):**
- Each BIST engine represented as IJTAG segment
- TCP dynamically routes scan path based on mode

---

## 11. Timing Constraints Summary

### 11.1 Critical Paths

**Expected Critical Paths:**
1. CPU datapath: Register file → ALU → Register file
2. Memory access: Address decode → SRAM read → CPU
3. JTAG: TCK domain crossing to clk_cpu

**Target Frequencies:**
- `clk_cpu`: 50 MHz (20 ns period) for 40nm process
- `clk_test`: 10 MHz (100 ns period)
- TCK: 10 MHz max (per IEEE 1149.1)

### 11.2 CDC Constraints

**Synchronizer Requirements:**
- Min 2-stage for single-bit control signals
- Async FIFO for multi-bit data (>4 bits)
- Gray code for counters/pointers crossing domains

**Setup/Hold Analysis:**
- MTBF target: <1 failure per 1000 years of operation
- Conservative synchronizer depth: 3 stages for critical paths

---

## 12. DFT Insertion Guidelines

### 12.1 Scan Chain Structure

**Recommended Topology:**
- 4-8 scan chains (balanced length ~2K-5K flip-flops each)
- Chain partition: Isolate clock domains for easier timing closure
- Observation points: Critical state machines, error flags

**Scan Multiplexer Insertion:**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
scan_en              | 1     | Input     | Scan mode enable
scan_in[N-1:0]       | N     | Input     | Scan input per chain
scan_out[N-1:0]      | N     | Output    | Scan output per chain
```

### 12.2 MBIST Wrappers

**Per Memory Instance:**
- Wrapper includes BIST controller FSM
- Algorithm: March C+ (13N complexity for N words)
- Interface: Start, done, pass/fail signals to TCP

**Collar Signals:**
```
Signal Name          | Width | Direction | Description
---------------------|-------|-----------|---------------------------
bist_en              | 1     | Input     | BIST mode enable
bist_done            | 1     | Output    | Test complete
bist_fail            | 1     | Output    | Failure detected
bist_fail_addr       | A     | Output    | First failing address
```

---

## 13. Reusable RTL Blocks Summary

### 13.1 Core Blocks to Develop/Reuse

| Block Name              | Source           | Complexity | Notes                          |
|-------------------------|------------------|------------|--------------------------------|
| RISC-V Core (RV32I)     | Ibex/PicoRV32    | High       | Reuse recommended              |
| ROM Controller          | Custom           | Low        | Simple address decoder         |
| SRAM Controller         | Custom           | Low        | Single-cycle wrapper           |
| Flash Controller        | Vendor IP        | Medium     | Process-specific               |
| APB Interconnect        | ARM/Custom       | Low        | Standard protocol              |
| Clock Gating Cells      | Library          | Low        | Use foundry ICG cells          |
| Synchronizers (2FF)     | Custom           | Low        | Reusable across projects       |
| JTAG TAP Controller     | OpenCores/Custom | Medium     | IEEE 1149.1 compliant          |
| IJTAG Network           | Custom/Tool Gen  | Medium     | IEEE 1687 PDL-driven           |
| Test Mode FSM           | Custom           | Medium     | Project-specific               |
| Power Domain Ctrl       | Custom           | Medium     | UPF-driven synthesis           |
| MBIST Engine            | Vendor/Arteris   | High       | Reuse IP if available          |

### 13.2 Interface Standardization

**All memory-mapped blocks shall expose:**
- Standard bus protocol interface (APB recommended)
- Reset synchronization per clock domain
- Scan insertion hookup (scan_en, scan_in, scan_out)
- Power domain awareness (isolation, retention)

**All test blocks shall expose:**
- Enable/start control signal
- Done/status indication
- Pass/fail result
- Optional diagnostic data port

---

## 14. Verification Strategy (Non-RTL)

### 14.1 Block-Level Testing

**Per Module:**
- Directed tests for FSM coverage
- Random constrained tests for datapath
- Corner case testing (reset during operation, etc.)

**Interfaces:**
- Protocol checkers (APB compliance)
- Assertion-based verification (SVA)
- Coverage metrics: 100% toggle, >95% FSM state/transition

### 14.2 Integration Testing

**CPU + Memory:**
- Boot sequence from ROM
- Read/write to all memory regions
- Bus error injection

**TCP + JTAG:**
- IDCODE read
- Mode transitions via JTAG commands
- Flash programming sequence

**Full System:**
- Production test flow simulation
- Multi-mode sequencing (ATPG → MBIST → LBIST)
- Power domain transitions under test execution

---

## 15. Open Implementation Questions

1. **RISC-V vs. FSM:** Final decision requires area/power analysis post-synthesis
2. **Flash Technology:** Embedded flash availability per process node (alternatives: OTP, SRAM with battery)
3. **MBIST IP:** Build custom or license? Cost vs. development time tradeoff
4. **IJTAG Tooling:** Availability of IEEE 1687 PDL compilers for target EDA flow
5. **Power Gating:** Deep power-down support needed? Or clock gating sufficient?
6. **Multi-die:** Chiplet-specific extensions to JTAG/IJTAG for die-to-die communication

---

**Document Version:** 1.0
**Last Updated:** December 2025
**Owner:** RTL Design Team
**Status:** Initial Draft - Pending Architecture Review
