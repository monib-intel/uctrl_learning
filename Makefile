# DFT Test Control Processor - Simulation Makefile
# =================================================

# Directories
RTL_DIR     := rtl
TB_DIR      := tb
SIM_DIR     := sim
BUILD_DIR   := $(SIM_DIR)/build
WAVE_DIR    := $(SIM_DIR)/waves
DOC_DIR     := doc

# Tools
VERILATOR   := verilator
IVERILOG    := iverilog
VVP         := vvp
GTKWAVE     := gtkwave
PYTHON      := python3
VERIBLE_LINT := verible-verilog-lint
VERIBLE_FMT  := verible-verilog-format

# Compiler flags
VFLAGS      := --binary --timing -Wall -Wno-fatal
VFLAGS      += --trace-fst --trace-structs
VFLAGS      += -CFLAGS "-O3 -march=native"
VFLAGS      += --top-module tcp_top

# Icarus Verilog flags
IVFLAGS     := -g2012 -Wall
IVFLAGS     += -I$(RTL_DIR)

# Include paths
VFLAGS      += -I$(RTL_DIR)
VFLAGS      += -I$(RTL_DIR)/core
VFLAGS      += -I$(RTL_DIR)/memory
VFLAGS      += -I$(RTL_DIR)/interconnect
VFLAGS      += -I$(RTL_DIR)/test_control
VFLAGS      += -I$(RTL_DIR)/jtag

# RTL source files (to be populated)
RTL_SOURCES := 
# RTL_SOURCES += $(RTL_DIR)/core/risc_v_core.sv
# RTL_SOURCES += $(RTL_DIR)/memory/rom_controller.sv
# RTL_SOURCES += $(RTL_DIR)/memory/sram_controller.sv
# RTL_SOURCES += $(RTL_DIR)/interconnect/apb_bus.sv
# RTL_SOURCES += $(RTL_DIR)/test_control/test_mode_controller.sv
# RTL_SOURCES += $(RTL_DIR)/jtag/tap_controller.sv
# RTL_SOURCES += $(RTL_DIR)/tcp_top.sv

# Testbench files
TB_SOURCES :=
# TB_SOURCES += $(TB_DIR)/tcp_top_tb.sv

# Colors for output
RED     := \033[0;31m
GREEN   := \033[0;32m
YELLOW  := \033[0;33m
BLUE    := \033[0;34m
RESET   := \033[0m

# Default target
.PHONY: all
all: help

# Help target
.PHONY: help
help:
	@echo "$(BLUE)DFT Test Control Processor - Makefile Targets$(RESET)"
	@echo ""
	@echo "$(GREEN)Simulation:$(RESET)"
	@echo "  make sim                - Run Verilator simulation"
	@echo "  make sim-iverilog       - Run Icarus Verilog simulation"
	@echo "  make sim-cocotb         - Run cocotb testbench"
	@echo "  make wave               - Open waveform viewer (GTKWave)"
	@echo ""
	@echo "$(GREEN)Building:$(RESET)"
	@echo "  make build              - Build Verilator simulation binary"
	@echo "  make build-iverilog     - Build Icarus Verilog simulation"
	@echo ""
	@echo "$(GREEN)Testing:$(RESET)"
	@echo "  make test               - Run all tests"
	@echo "  make test-unit          - Run unit tests"
	@echo "  make test-integration   - Run integration tests"
	@echo "  make coverage           - Generate coverage report"
	@echo ""
	@echo "$(GREEN)Code Quality:$(RESET)"
	@echo "  make lint               - Run Verible linter"
	@echo "  make format             - Format RTL code with Verible"
	@echo "  make check              - Run lint and basic checks"
	@echo ""
	@echo "$(GREEN)Documentation:$(RESET)"
	@echo "  make docs               - Generate documentation"
	@echo "  make wavedrom           - Render WaveDrom diagrams"
	@echo ""
	@echo "$(GREEN)Utilities:$(RESET)"
	@echo "  make clean              - Remove build artifacts"
	@echo "  make cleanall           - Remove all generated files"
	@echo "  make setup              - Create directory structure"
	@echo "  make info               - Display environment info"
	@echo ""

# Setup directories
.PHONY: setup
setup:
	@echo "$(BLUE)Creating directory structure...$(RESET)"
	@mkdir -p $(RTL_DIR)/{core,memory,interconnect,test_control,jtag}
	@mkdir -p $(TB_DIR)/{unit,integration}
	@mkdir -p $(SIM_DIR)/{verilator,iverilog,cocotb}
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(WAVE_DIR)
	@mkdir -p $(DOC_DIR)/{specs,diagrams}
	@mkdir -p sw/{boot,firmware,tests}
	@mkdir -p scripts
	@echo "$(GREEN)✓ Directory structure created$(RESET)"

# Environment info
.PHONY: info
info:
	@echo "$(BLUE)Environment Information:$(RESET)"
	@echo "  Verilator:    $$(verilator --version | head -n1)"
	@echo "  Iverilog:     $$(iverilog -V 2>&1 | head -n1)"
	@echo "  Python:       $$(python3 --version)"
	@echo "  Make:         $$(make --version | head -n1)"
	@echo "  RTL dir:      $(RTL_DIR)"
	@echo "  TB dir:       $(TB_DIR)"
	@echo "  Sim dir:      $(SIM_DIR)"

# Verilator simulation
.PHONY: build
build: $(BUILD_DIR)/Vtcp_top
	@echo "$(GREEN)✓ Verilator build complete$(RESET)"

$(BUILD_DIR)/Vtcp_top: $(RTL_SOURCES) $(TB_SOURCES) | $(BUILD_DIR)
	@echo "$(BLUE)Building Verilator simulation...$(RESET)"
	@if [ -z "$(RTL_SOURCES)" ]; then \
		echo "$(YELLOW)⚠ No RTL sources defined yet$(RESET)"; \
		echo "$(YELLOW)⚠ Add RTL files to RTL_SOURCES in Makefile$(RESET)"; \
		exit 1; \
	fi
	$(VERILATOR) $(VFLAGS) $(RTL_SOURCES) $(TB_SOURCES) -o $(BUILD_DIR)/Vtcp_top

.PHONY: sim
sim: build
	@echo "$(BLUE)Running Verilator simulation...$(RESET)"
	@cd $(BUILD_DIR) && ./Vtcp_top
	@echo "$(GREEN)✓ Simulation complete$(RESET)"
	@if [ -f $(BUILD_DIR)/dump.fst ]; then \
		mv $(BUILD_DIR)/dump.fst $(WAVE_DIR)/; \
		echo "$(GREEN)✓ Waveform saved to $(WAVE_DIR)/dump.fst$(RESET)"; \
	fi

# Icarus Verilog simulation
.PHONY: build-iverilog
build-iverilog: $(BUILD_DIR)/tcp_sim.vvp

$(BUILD_DIR)/tcp_sim.vvp: $(RTL_SOURCES) $(TB_SOURCES) | $(BUILD_DIR)
	@echo "$(BLUE)Building Icarus Verilog simulation...$(RESET)"
	@if [ -z "$(RTL_SOURCES)" ]; then \
		echo "$(YELLOW)⚠ No RTL sources defined yet$(RESET)"; \
		exit 1; \
	fi
	$(IVERILOG) $(IVFLAGS) -o $@ $(RTL_SOURCES) $(TB_SOURCES)
	@echo "$(GREEN)✓ Icarus Verilog build complete$(RESET)"

.PHONY: sim-iverilog
sim-iverilog: build-iverilog
	@echo "$(BLUE)Running Icarus Verilog simulation...$(RESET)"
	$(VVP) $(BUILD_DIR)/tcp_sim.vvp
	@echo "$(GREEN)✓ Simulation complete$(RESET)"
	@if [ -f dump.vcd ]; then \
		mv dump.vcd $(WAVE_DIR)/; \
		echo "$(GREEN)✓ Waveform saved to $(WAVE_DIR)/dump.vcd$(RESET)"; \
	fi

# Cocotb simulation
.PHONY: sim-cocotb
sim-cocotb:
	@echo "$(BLUE)Running cocotb testbench...$(RESET)"
	@if [ -d $(TB_DIR)/cocotb ]; then \
		cd $(TB_DIR)/cocotb && $(PYTHON) -m pytest -v; \
	else \
		echo "$(YELLOW)⚠ No cocotb testbench found in $(TB_DIR)/cocotb$(RESET)"; \
	fi

# Waveform viewer
.PHONY: wave
wave:
	@echo "$(BLUE)Opening waveform viewer...$(RESET)"
	@if [ -f $(WAVE_DIR)/dump.fst ]; then \
		$(GTKWAVE) $(WAVE_DIR)/dump.fst; \
	elif [ -f $(WAVE_DIR)/dump.vcd ]; then \
		$(GTKWAVE) $(WAVE_DIR)/dump.vcd; \
	else \
		echo "$(RED)✗ No waveform file found$(RESET)"; \
		echo "$(YELLOW)  Run 'make sim' or 'make sim-iverilog' first$(RESET)"; \
	fi

# Testing
.PHONY: test
test: test-unit test-integration

.PHONY: test-unit
test-unit:
	@echo "$(BLUE)Running unit tests...$(RESET)"
	@if [ -d $(TB_DIR)/unit ]; then \
		cd $(TB_DIR)/unit && $(PYTHON) -m pytest -v; \
	else \
		echo "$(YELLOW)⚠ No unit tests found$(RESET)"; \
	fi

.PHONY: test-integration
test-integration:
	@echo "$(BLUE)Running integration tests...$(RESET)"
	@if [ -d $(TB_DIR)/integration ]; then \
		cd $(TB_DIR)/integration && $(PYTHON) -m pytest -v; \
	else \
		echo "$(YELLOW)⚠ No integration tests found$(RESET)"; \
	fi

.PHONY: coverage
coverage:
	@echo "$(BLUE)Generating coverage report...$(RESET)"
	@echo "$(YELLOW)⚠ Coverage analysis requires additional setup$(RESET)"
	@echo "$(YELLOW)  Consider using Verilator --coverage or covered tool$(RESET)"

# Code quality
.PHONY: lint
lint:
	@echo "$(BLUE)Running Verible linter...$(RESET)"
	@if [ -n "$(RTL_SOURCES)" ]; then \
		$(VERIBLE_LINT) $(RTL_SOURCES) || echo "$(YELLOW)⚠ Lint warnings found$(RESET)"; \
	else \
		echo "$(YELLOW)⚠ No RTL sources to lint$(RESET)"; \
	fi

.PHONY: format
format:
	@echo "$(BLUE)Formatting RTL code...$(RESET)"
	@if [ -n "$(RTL_SOURCES)" ]; then \
		$(VERIBLE_FMT) --inplace $(RTL_SOURCES); \
		echo "$(GREEN)✓ Formatting complete$(RESET)"; \
	else \
		echo "$(YELLOW)⚠ No RTL sources to format$(RESET)"; \
	fi

.PHONY: check
check: lint
	@echo "$(GREEN)✓ Basic checks complete$(RESET)"

# Documentation
.PHONY: docs
docs:
	@echo "$(BLUE)Generating documentation...$(RESET)"
	@echo "$(YELLOW)⚠ Documentation generation not yet implemented$(RESET)"
	@echo "$(YELLOW)  Consider adding Doxygen or Sphinx support$(RESET)"

.PHONY: wavedrom
wavedrom:
	@echo "$(BLUE)Rendering WaveDrom diagrams...$(RESET)"
	@if command -v npx >/dev/null 2>&1; then \
		mkdir -p $(DOC_DIR)/diagrams; \
		if [ -f uarchitecture.md ]; then \
			echo "$(GREEN)✓ WaveDrom diagrams embedded in markdown$(RESET)"; \
			echo "$(YELLOW)  View in VS Code with WaveDrom extension or render with wavedrom-cli$(RESET)"; \
		fi; \
	else \
		echo "$(YELLOW)⚠ npx not found, install Node.js$(RESET)"; \
	fi

# Clean targets
.PHONY: clean
clean:
	@echo "$(BLUE)Cleaning build artifacts...$(RESET)"
	@rm -rf $(BUILD_DIR)/*
	@rm -f *.vcd *.fst *.log
	@echo "$(GREEN)✓ Clean complete$(RESET)"

.PHONY: cleanall
cleanall: clean
	@echo "$(BLUE)Removing all generated files...$(RESET)"
	@rm -rf $(SIM_DIR)
	@rm -rf $(WAVE_DIR)
	@rm -rf __pycache__ .pytest_cache
	@find . -name "*.pyc" -delete
	@find . -name "*.pyo" -delete
	@echo "$(GREEN)✓ All generated files removed$(RESET)"

# Create necessary directories
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(WAVE_DIR):
	@mkdir -p $(WAVE_DIR)

# Example target for creating a simple testbench template
.PHONY: example-tb
example-tb:
	@echo "$(BLUE)Creating example testbench template...$(RESET)"
	@mkdir -p $(TB_DIR)
	@cat > $(TB_DIR)/tcp_top_tb.sv <<'EOF'
// Simple TCP Top Testbench Template
module tcp_top_tb;
  
  // Clock and reset
  logic clk;
  logic rst_n;
  
  // Instantiate DUT
  // tcp_top dut (
  //   .clk(clk),
  //   .rst_n(rst_n),
  //   ...
  // );
  
  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100MHz clock
  end
  
  // Reset generation
  initial begin
    rst_n = 0;
    #100;
    rst_n = 1;
  end
  
  // Test stimulus
  initial begin
    $$display("TCP Testbench Starting...");
    
    // Wait for reset
    @(posedge rst_n);
    @(posedge clk);
    
    // Add test stimulus here
    
    #1000;
    $$display("TCP Testbench Complete");
    $$finish;
  end
  
  // Waveform dumping
  initial begin
    $$dumpfile("dump.vcd");
    $$dumpvars(0, tcp_top_tb);
  end
  
endmodule
EOF
	@echo "$(GREEN)✓ Example testbench created at $(TB_DIR)/tcp_top_tb.sv$(RESET)"

.PHONY: .SILENT
.SILENT: help info
