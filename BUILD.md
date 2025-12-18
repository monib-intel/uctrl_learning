# DFT Test Control Processor - Build System Guide

## Table of Contents
- [Quick Start](#quick-start)
- [Development Environment Setup](#development-environment-setup)
- [Directory Structure](#directory-structure)
- [Building Simulations](#building-simulations)
- [Running Tests](#running-tests)
- [Code Quality Tools](#code-quality-tools)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### Using Nix Flakes (Recommended)

If you have Nix with flakes enabled:

```bash
# Enter development environment
nix develop

# Or run directly
nix develop --command make help
```

### Manual Setup

Install required tools:
- Verilator (4.0+)
- Icarus Verilog
- GTKWave
- GNU Make
- RISC-V GCC toolchain
- Python 3.8+ with cocotb

---

## Development Environment Setup

### Nix Flakes Method

The `flake.nix` provides a complete development environment with all necessary tools.

**Features:**
- ✅ Verilator for fast RTL simulation
- ✅ Icarus Verilog as backup simulator
- ✅ GTKWave for waveform viewing
- ✅ RISC-V GCC cross-compiler
- ✅ Python with cocotb for verification
- ✅ Verible for linting/formatting
- ✅ WaveDrom for timing diagrams
- ✅ Build tools (make, cmake, ninja)

**Enable Nix Flakes:**

Add to `~/.config/nix/nix.conf`:
```
experimental-features = nix-command flakes
```

**Enter Development Shell:**
```bash
cd /path/to/uctrl_learning
nix develop
```

**One-liner Commands:**
```bash
# Run simulation without entering shell
nix develop --command make sim

# Run linter
nix develop --command make lint

# Run all tests
nix develop --command make test
```

### Manual Installation

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y \
  verilator \
  iverilog \
  gtkwave \
  build-essential \
  python3-pip \
  gcc-riscv64-unknown-elf

pip3 install cocotb pytest pytest-cov
```

**macOS (Homebrew):**
```bash
brew install verilator icarus-verilog gtkwave
brew tap riscv/riscv
brew install riscv-tools

pip3 install cocotb pytest pytest-cov
```

---

## Directory Structure

After running `make setup` or entering the Nix shell:

```
uctrl_learning/
├── rtl/                    # RTL source files
│   ├── core/              # RISC-V core implementation
│   ├── memory/            # Memory controllers (ROM, SRAM, Flash)
│   ├── interconnect/      # Bus interconnect (APB)
│   ├── test_control/      # Test mode controller, sequencer
│   └── jtag/              # JTAG/IJTAG interface
├── tb/                     # Testbenches
│   ├── unit/              # Unit tests (per module)
│   ├── integration/       # Integration tests
│   └── cocotb/            # Cocotb-based tests
├── sim/                    # Simulation outputs (auto-generated)
│   ├── build/             # Compiled simulation binaries
│   ├── waves/             # Waveform files (.vcd, .fst)
│   └── coverage/          # Coverage reports
├── sw/                     # Software for RISC-V core
│   ├── boot/              # Boot ROM code
│   ├── firmware/          # Test firmware
│   └── tests/             # Software tests
├── doc/                    # Documentation
│   ├── specs/             # Specifications (README, uarchitecture)
│   └── diagrams/          # Generated diagrams
├── scripts/                # Build and utility scripts
├── Makefile               # Build system
├── flake.nix              # Nix development environment
└── .gitignore             # Git ignore rules
```

---

## Building Simulations

### Verilator (Recommended)

Verilator compiles RTL to C++ for fast simulation.

**Build:**
```bash
make build
```

**Run simulation:**
```bash
make sim
```

**View waveform:**
```bash
make wave
```

**Output:**
- Binary: `sim/build/Vtcp_top`
- Waveform: `sim/waves/dump.fst` (FST format for speed)

### Icarus Verilog

Alternative simulator, useful for debugging.

**Build:**
```bash
make build-iverilog
```

**Run simulation:**
```bash
make sim-iverilog
```

**Output:**
- Binary: `sim/build/tcp_sim.vvp`
- Waveform: `sim/waves/dump.vcd`

### Cocotb (Python-based Testing)

For advanced verification with Python.

**Run cocotb tests:**
```bash
make sim-cocotb
```

**Create cocotb test:**
```python
# tb/cocotb/test_tcp_boot.py
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_boot_sequence(dut):
    """Test TCP boot from ROM"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    await Timer(100, units="ns")
    dut.rst_n.value = 1
    
    # Wait for boot
    await RisingEdge(dut.clk)
    
    # Check PC at boot address
    assert dut.pc.value == 0x0000_0000, "PC should start at 0x0"
```

---

## Running Tests

### Unit Tests

Test individual modules in isolation.

```bash
make test-unit
```

### Integration Tests

Test complete subsystems.

```bash
make test-integration
```

### All Tests

```bash
make test
```

### Coverage Analysis

```bash
make coverage
```

**Note:** Coverage requires additional Verilator flags (`--coverage`). Edit Makefile to enable.

---

## Code Quality Tools

### Linting

Check RTL code for style and potential issues using Verible.

```bash
make lint
```

**Configure linting rules:**

Create `.verible-lint.rules`:
```
# Disable specific rules
-line-length
-endif-comment

# Enforce naming conventions
+module-filename
+parameter-name-style
```

### Formatting

Auto-format RTL code to consistent style.

```bash
make format
```

**Note:** This modifies files in-place. Commit changes first!

### Combined Check

Run lint and basic checks:

```bash
make check
```

---

## WaveDrom Rendering

The microarchitecture document includes WaveDrom timing diagrams.

**View in VS Code:**

Install the WaveDrom extension:
```bash
code --install-extension wavedrom.wavedrom
```

**Render to PNG/SVG:**

```bash
make wavedrom
```

Or manually:
```bash
npx wavedrom-cli -i doc/diagram.json -o doc/diagram.svg
```

---

## Makefile Targets Reference

| Target              | Description                                |
|---------------------|--------------------------------------------|
| `make help`         | Show all available targets                 |
| `make setup`        | Create directory structure                 |
| `make info`         | Display environment information            |
| `make build`        | Build Verilator simulation                 |
| `make sim`          | Run Verilator simulation                   |
| `make build-iverilog` | Build Icarus Verilog simulation          |
| `make sim-iverilog` | Run Icarus Verilog simulation              |
| `make sim-cocotb`   | Run cocotb tests                           |
| `make wave`         | Open GTKWave with latest waveform          |
| `make test`         | Run all tests                              |
| `make test-unit`    | Run unit tests only                        |
| `make test-integration` | Run integration tests only             |
| `make coverage`     | Generate coverage report                   |
| `make lint`         | Run Verible linter                         |
| `make format`       | Format RTL with Verible                    |
| `make check`        | Run lint and checks                        |
| `make docs`         | Generate documentation                     |
| `make wavedrom`     | Render WaveDrom diagrams                   |
| `make clean`        | Remove build artifacts                     |
| `make cleanall`     | Remove all generated files                 |
| `make example-tb`   | Create example testbench template          |

---

## Troubleshooting

### Common Issues

**1. "verilator: command not found"**

Ensure Verilator is installed and in PATH:
```bash
which verilator
verilator --version
```

Or use Nix:
```bash
nix develop
```

**2. "No RTL sources defined"**

Populate `RTL_SOURCES` in Makefile as you create RTL files:
```makefile
RTL_SOURCES := $(RTL_DIR)/tcp_top.sv
RTL_SOURCES += $(RTL_DIR)/core/risc_v_core.sv
# ... add more files
```

**3. Simulation runs but no waveform**

Check that VCD/FST dumping is enabled in testbench:

For Verilog:
```verilog
initial begin
  $dumpfile("dump.vcd");
  $dumpvars(0, tcp_top_tb);
end
```

For Verilator, add `--trace-fst` flag (already in Makefile).

**4. RISC-V toolchain issues**

Check toolchain prefix:
```bash
which riscv64-unknown-elf-gcc
echo $RISCV
```

The Nix flake sets up the correct environment automatically.

**5. Permission denied on simulation binary**

```bash
chmod +x sim/build/Vtcp_top
```

---

## Advanced Usage

### Custom Verilator Flags

Edit Makefile `VFLAGS` variable:
```makefile
VFLAGS += --coverage        # Enable coverage
VFLAGS += --assert          # Enable assertions
VFLAGS += -Wno-UNUSED       # Suppress unused signal warnings
```

### Parallel Simulation

For multiple test runs:
```bash
make test -j4  # Run 4 tests in parallel
```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: RTL Simulation
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: cachix/install-nix-action@v20
        with:
          extra_nix_config: |
            experimental-features = nix-command flakes
      - run: nix develop --command make test
      - run: nix develop --command make lint
```

---

## Performance Tips

### Faster Verilator Builds

1. **Use multi-threading:**
   ```makefile
   VFLAGS += -j $(nproc)
   ```

2. **Optimize compilation:**
   ```makefile
   VFLAGS += -CFLAGS "-O3 -march=native"
   ```

3. **Disable tracing for speed:**
   Comment out `--trace-fst` when tracing not needed.

### Faster Simulation

1. **Use FST instead of VCD** (already default)
2. **Reduce trace depth:**
   ```verilog
   $dumpvars(1, tcp_top);  // Only top-level signals
   ```

3. **Conditional tracing:**
   Only dump after certain time/event.

---

## Contributing

When adding new RTL files:

1. **Update Makefile:** Add to `RTL_SOURCES`
2. **Run lint:** `make lint`
3. **Add testbench:** Create in `tb/unit/` or `tb/integration/`
4. **Run tests:** `make test`
5. **Commit:** Include both RTL and tests

---

## Resources

- [Verilator Manual](https://verilator.org/guide/latest/)
- [Icarus Verilog](http://iverilog.icarus.com/)
- [Cocotb Documentation](https://docs.cocotb.org/)
- [Verible Style Guide](https://github.com/chipsalliance/verible)
- [GTKWave Manual](http://gtkwave.sourceforge.net/)
- [WaveDrom Tutorial](https://wavedrom.com/tutorial.html)

---

**Last Updated:** December 2025  
**Maintainer:** TCP Development Team
