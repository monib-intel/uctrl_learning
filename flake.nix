{
  description = "DFT Test Control Processor (TCP) Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        # Python environment for testing and scripting
        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          pytest
          pytest-cov
          cocotb
          pytest-xdist
          pyyaml
          jinja2
          matplotlib
          numpy
        ]);

        # Custom wavedrom-cli wrapper
        wavedrom-cli = pkgs.writeShellScriptBin "wavedrom-cli" ''
          ${pkgs.nodejs}/bin/npx wavedrom-cli "$@"
        '';

      in
      {
        devShells.default = pkgs.mkShell {
          name = "tcp-rtl-dev";
          
          buildInputs = with pkgs; [
            # HDL Simulation & Verification
            verilator              # Fast Verilog/SystemVerilog simulator
            gtkwave                # Waveform viewer
            iverilog               # Icarus Verilog simulator (backup)
            
            # Build Tools
            gnumake                # Build automation
            cmake                  # Alternative build system
            ninja                  # Fast build tool
            
            # RISC-V Toolchain
            gcc-riscv64-embedded   # RISC-V GCC compiler
            
            # Python environment for cocotb and testing
            pythonEnv
            
            # Version Control & Documentation
            git                    # Version control
            graphviz               # Diagram generation (dot)
            pandoc                 # Document conversion
            wavedrom-cli           # Timing diagram rendering
            
            # SystemVerilog/UVM tools (optional, commented out if not needed)
            # sv2v                 # SystemVerilog to Verilog converter
            
            # Linting & Formatting
            verible                # SystemVerilog linter/formatter
            
            # Utilities
            ripgrep                # Fast grep
            fd                     # Fast find
            bat                    # Better cat
            jq                     # JSON processor
            yq                     # YAML processor
            
            # Documentation
            nodejs                 # For wavedrom and other JS tools
            
            # Optional: For FPGA synthesis
            # yosys                # Open synthesis suite
            # nextpnr              # FPGA place and route
            # icestorm             # iCE40 FPGA tools
          ];

          shellHook = ''
            echo "🚀 DFT Test Control Processor (TCP) Development Environment"
            echo ""
            echo "Available Tools:"
            echo "  • Verilator $(verilator --version | head -n1 | cut -d' ' -f2)"
            echo "  • GTKWave $(gtkwave --version 2>&1 | head -n1 || echo 'installed')"
            echo "  • Icarus Verilog $(iverilog -V 2>&1 | head -n1 | cut -d' ' -f4)"
            echo "  • GNU Make $(make --version | head -n1 | cut -d' ' -f3)"
            echo "  • RISC-V GCC $(riscv64-unknown-elf-gcc --version | head -n1 | cut -d' ' -f3)"
            echo "  • Python $(python --version | cut -d' ' -f2) with cocotb"
            echo "  • Verible (linter/formatter)"
            echo ""
            echo "Directory Structure:"
            echo "  rtl/          - RTL source files"
            echo "  tb/           - Testbenches"
            echo "  sim/          - Simulation outputs"
            echo "  doc/          - Documentation"
            echo "  scripts/      - Build and utility scripts"
            echo ""
            echo "Quick Start:"
            echo "  make help     - Show available make targets"
            echo "  make sim      - Run default simulation"
            echo "  make lint     - Run Verible linter"
            echo "  make wave     - Open waveform viewer"
            echo ""
            
            # Set up environment variables
            export RTL_ROOT="$PWD/rtl"
            export TB_ROOT="$PWD/tb"
            export SIM_ROOT="$PWD/sim"
            export RISCV="$(dirname $(dirname $(which riscv64-unknown-elf-gcc)))"
            
            # Create directory structure if it doesn't exist
            mkdir -p rtl/{core,memory,interconnect,test_control,jtag}
            mkdir -p tb/{unit,integration}
            mkdir -p sim/{verilator,iverilog,cocotb}
            mkdir -p doc/{specs,diagrams}
            mkdir -p scripts
            mkdir -p sw/{boot,firmware,tests}
            
            # Set Python path for cocotb
            export PYTHONPATH="$PWD/tb:$PYTHONPATH"
            
            echo "Environment ready! ✨"
          '';

          # Environment variables
          VERILATOR_ROOT = "${pkgs.verilator}";
          RISCV_PREFIX = "riscv64-unknown-elf-";
        };

        # Package definitions (optional: for CI/CD)
        packages = {
          # Example: Build a specific simulation
          sim-tcp = pkgs.stdenv.mkDerivation {
            name = "tcp-simulation";
            src = ./.;
            buildInputs = [ pkgs.verilator pkgs.gnumake ];
            buildPhase = ''
              make -C sim/verilator tcp_top
            '';
            installPhase = ''
              mkdir -p $out/bin
              cp sim/verilator/Vtcp_top $out/bin/
            '';
          };
        };

        # Apps (optional: for running tools)
        apps = {
          lint = {
            type = "app";
            program = toString (pkgs.writeShellScript "lint-rtl" ''
              ${pkgs.verible}/bin/verible-verilog-lint \
                --rules_config .verible-lint.rules \
                rtl/**/*.sv rtl/**/*.v
            '');
          };
          
          format = {
            type = "app";
            program = toString (pkgs.writeShellScript "format-rtl" ''
              ${pkgs.verible}/bin/verible-verilog-format \
                --inplace \
                rtl/**/*.sv rtl/**/*.v
            '');
          };
        };
      }
    );
}
