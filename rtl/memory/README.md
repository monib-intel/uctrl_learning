# ROM Controller

## Overview
Boot ROM controller for the DFT Test Control Processor. Stores critical test patterns and boot code with synchronous read access and 1-cycle latency.

## Specification
See [docs/spec_rom_controller.md](../../docs/spec_rom_controller.md) for detailed specification.

## Features
- **Size:** 32 KB (8K words × 32-bit)
- **Latency:** 1 cycle synchronous read
- **Addressing:** Byte-aligned addressing (rom_addr[14:0])
- **Initialization:** Supports .mem/.hex file loading via $readmemh
- **MBIST:** Built-in Memory Built-In Self-Test for accessibility verification

## Interface Signals

### Clocking & Reset
- `clk` - System clock
- `rst_n` - Active-low asynchronous reset

### Memory Access
- `rom_req` - Access request (high to initiate read)
- `rom_addr[14:0]` - Byte address (must be word-aligned, i.e., multiples of 4)
- `rom_rdata[31:0]` - Read data output
- `rom_ready` - Data valid signal (asserts 1 cycle after rom_req)

### DFT (Design for Test)
- `mbist_en` - MBIST mode enable
- `mbist_done` - MBIST completion flag
- `mbist_fail` - MBIST failure indicator

## Read Operation Timing
```
Cycle:    0         1         2
        ____      ____      ____
clk         |____|    |____|    |____

rom_req ______/‾‾‾‾‾‾‾\_____________

rom_addr XXXXX< Valid >XXXXXXXXXXXX

rom_ready __________/‾‾‾‾‾\_________

rom_rdata XXXXXXXXXXXXXXX< Data >XXX
```

## Memory Initialization
The ROM can be initialized with a .mem or .hex file:

1. Create a memory file (e.g., `rtl/memory/init/rom_boot.mem`)
2. Define `ROM_INIT_FILE` macro during compilation:
   ```
   +define+ROM_INIT_FILE="rtl/memory/init/rom_boot.mem"
   ```

### Memory File Format
```
// Comments start with //
DEADBEEF  // 32-bit hex values, one per line
CAFEBABE
12345678
```

## MBIST Operation
The MBIST (Memory Built-In Self-Test) performs a three-phase march algorithm:

1. **March Up:** Reads all addresses in ascending order (0 to 8191)
2. **March Down:** Reads all addresses in descending order (8191 to 0)
3. **Verify:** Final read pass in ascending order

The MBIST tests ROM accessibility. Since ROM is read-only, it verifies that all locations can be read without expecting specific data patterns.

### MBIST Usage
```verilog
// Enable MBIST
mbist_en = 1'b1;

// Wait for completion
wait(mbist_done == 1'b1);

// Check result
if (mbist_fail) begin
    // MBIST detected errors
end else begin
    // MBIST passed
end

// Disable MBIST to return to normal operation
mbist_en = 1'b0;
```

## Address Mapping
```
Byte Address   | Word Address | Description
---------------|--------------|---------------------------
0x0000_0000    | 0x0000       | First word (boot vector)
0x0000_0004    | 0x0001       | Second word
...            | ...          | ...
0x0000_7FFC    | 0x1FFF       | Last word (word 8191)
```

## Testing
Unit testbench: `tb/unit/test_rom_controller.sv`

Run tests with:
```bash
# Using Icarus Verilog
iverilog -g2012 -o test_rom_controller \
    rtl/memory/rom_controller.sv \
    tb/unit/test_rom_controller.sv
vvp test_rom_controller

# Using Verilator
verilator --binary --timing -Wall \
    rtl/memory/rom_controller.sv \
    tb/unit/test_rom_controller.sv
./obj_dir/Vtest_rom_controller
```

## Implementation Notes
- ROM memory array uses SystemVerilog unpacked array: `logic [31:0] rom_mem [0:ROM_DEPTH-1]`
- Read latency is implemented via registered output
- Word address extraction: `read_addr = rom_addr[ADDR_WIDTH+1:2]` (drops lower 2 bits)
- MBIST state machine uses non-blocking assignments for synthesis-friendly implementation

## Technology Options
This design is technology-independent and can be mapped to:
1. Standard cell memory compiler
2. Hard macro ROM
3. Synchronous SRAM (for FPGA prototyping)

## Synthesis Considerations
- The memory array will be inferred by synthesis tools
- For ASIC: Use memory compiler or hard macro
- For FPGA: Will map to block RAM
- MBIST logic adds ~200-300 gates overhead
