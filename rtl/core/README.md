# RISC-V Core (RV32I) - Implementation Notes

## Overview

This is a minimal single-cycle RISC-V RV32I core implementation designed for the DFT Test Control Processor (TCP). The core is optimized for area efficiency and DFT testability rather than performance.

## Specifications

- **ISA**: RV32I (base integer instruction set only)
- **Architecture**: Single-cycle execution
- **Pipeline**: None (all instructions complete in one cycle)
- **Target Area**: 10-15K gates
- **Target Frequency**: 50 MHz @ 40nm process
- **Register File**: 32 x 32-bit general purpose registers (x0-x31)

## Supported Instructions

### R-Type (Register-Register Operations)
- ADD, SUB, AND, OR, XOR
- SLL, SRL, SRA (shift operations)
- SLT, SLTU (set less than)

### I-Type (Immediate Operations)
- ADDI, ANDI, ORI, XORI
- SLLI, SRLI, SRAI
- SLTI, SLTIU
- LOAD instructions: LB, LH, LW, LBU, LHU

### S-Type (Store Operations)
- SB, SH, SW

### B-Type (Branch Operations)
- BEQ, BNE, BLT, BGE, BLTU, BGEU

### U-Type (Upper Immediate)
- LUI (Load Upper Immediate)
- AUIPC (Add Upper Immediate to PC)

### J-Type (Jump Operations)
- JAL (Jump and Link)
- JALR (Jump and Link Register)

### System Instructions
- WFI (Wait For Interrupt) - basic support

## Interface Signals

### Clock and Reset
- `clk` - System clock (10-100 MHz)
- `rst_n` - Active-low asynchronous reset

### Instruction Memory (IMem)
- `imem_req` - Instruction fetch request
- `imem_addr[31:0]` - Instruction address (byte-aligned)
- `imem_rdata[31:0]` - Instruction data from memory
- `imem_ready` - Memory ready signal (can stall core)
- `imem_err` - Bus error indicator

### Data Memory (DMem)
- `dmem_req` - Data memory request
- `dmem_we` - Write enable (1=write, 0=read)
- `dmem_be[3:0]` - Byte enable mask for stores
- `dmem_addr[31:0]` - Data memory address
- `dmem_wdata[31:0]` - Write data
- `dmem_rdata[31:0]` - Read data from memory
- `dmem_ready` - Memory ready signal (can stall core)
- `dmem_err` - Bus error indicator

### Control Signals
- `fetch_enable` - Core enable (0=halt, 1=run)
- `irq[31:0]` - Interrupt request vector
- `debug_req` - External debug request
- `core_sleep` - WFI state indicator (output)

### DFT (Design for Test)
- `scan_mode` - Scan test mode enable
- `scan_en` - Scan shift enable
- `scan_in` - Scan chain input
- `scan_out` - Scan chain output

## Implementation Details

### Single-Cycle Execution
All instructions complete in one clock cycle. This simplifies the design and makes DFT insertion easier, at the cost of lower maximum frequency compared to pipelined implementations.

### Memory Interface
Both instruction and data memory interfaces support stalling via the `ready` signal. When `ready=0`, the core will stall until memory is ready.

### Reset Behavior
On reset (`rst_n=0`):
- Program Counter (PC) is set to 0x0000_0000
- All registers in the register file are cleared to 0
- Core enters idle state with fetch disabled

### Interrupt Handling
Basic interrupt support is provided:
- IRQ vector input for 32 interrupt sources
- WFI (Wait For Interrupt) instruction support
- Core exits WFI state when any interrupt is asserted or debug is requested
- **Note**: Full interrupt handling (CSRs, trap vectors) is not implemented in this minimal version

### DFT Scan Chain
A basic scan chain is implemented through the PC register for DFT testing. In scan mode:
- Normal operation is disabled
- Scan data is shifted through flip-flops
- `scan_out` provides the shifted data

## Area Estimation

Estimated gate count breakdown:
- Register File (32 x 32-bit): ~3,000 gates
- ALU (32-bit): ~2,000 gates
- Control Logic & Decoder: ~1,500 gates
- PC & Branch Logic: ~500 gates
- Multiplexers & Routing: ~2,000 gates
- DFT Logic: ~500 gates

**Total Estimated**: ~9,500 gates (within 10-15K target)

## Testing

A comprehensive unit testbench is provided in `tb/unit/test_risc_v_core.sv` that tests:
1. R-type ALU operations
2. I-type immediate operations
3. Load/Store instructions
4. Branch instructions
5. Jump instructions (JAL/JALR)
6. Upper immediate instructions (LUI/AUIPC)
7. IMem interface with ready/stall
8. DMem interface with ready/stall
9. Interrupt handling (WFI/IRQ)
10. DFT scan chain
11. Fetch enable control

## Known Limitations

1. **No Pipeline**: Single-cycle design limits maximum frequency
2. **No CSRs**: Machine mode CSRs not implemented
3. **Basic Interrupts**: Full trap/exception handling not implemented
4. **No Debug**: Debug interface signals present but not fully implemented
5. **No Performance Counters**: Cycle/instruction counters not included
6. **Minimal Scan**: Only basic scan chain through PC, full scan insertion would be done by synthesis tools

## Future Enhancements

For a production version, consider:
1. Adding 2-stage pipeline for better timing
2. Implementing machine mode CSRs for full interrupt support
3. Adding debug module for JTAG debug access
4. Performance counters for profiling
5. Error correction (parity/ECC) on register file
6. Full scan chain through all flip-flops

## Verification Status

- ✅ RTL implementation complete
- ✅ Unit testbench created
- ⏳ Simulation verification (pending simulator availability)
- ⏳ Gate-level synthesis (pending tool availability)
- ⏳ Timing analysis (pending tool availability)

## References

- RISC-V ISA Specification: https://riscv.org/specifications/
- Specification Document: `docs/spec_risc_v_core.md`
- Testbench: `tb/unit/test_risc_v_core.sv`
