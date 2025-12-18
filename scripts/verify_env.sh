#!/usr/bin/env bash
# Quick verification script for development environment setup

set -e

echo "🔍 Verifying DFT TCP Development Environment..."
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check function
check_tool() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 found: $(command -v $1)"
        return 0
    else
        echo -e "${RED}✗${NC} $1 not found"
        return 1
    fi
}

# Check for required tools
echo "Checking required tools..."
check_tool verilator
check_tool iverilog
check_tool gtkwave
check_tool make
check_tool python3

echo ""
echo "Checking RISC-V toolchain..."
check_tool riscv64-unknown-elf-gcc || echo -e "${YELLOW}⚠${NC} RISC-V GCC not found (optional)"

echo ""
echo "Checking Python packages..."
if python3 -c "import cocotb" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} cocotb installed"
else
    echo -e "${YELLOW}⚠${NC} cocotb not found (optional)"
fi

if python3 -c "import pytest" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} pytest installed"
else
    echo -e "${YELLOW}⚠${NC} pytest not found (optional)"
fi

echo ""
echo "Checking directory structure..."
for dir in rtl tb sim doc scripts sw; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $dir/ exists"
    else
        echo -e "${YELLOW}⚠${NC} $dir/ not found (run 'make setup')"
    fi
done

echo ""
echo "Checking files..."
for file in Makefile flake.nix README.md uarchitecture.md BUILD.md; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file exists"
    else
        echo -e "${RED}✗${NC} $file missing"
    fi
done

echo ""
echo "Environment verification complete!"
echo ""
echo "Next steps:"
echo "  1. Run 'make setup' to create directory structure"
echo "  2. Run 'make help' to see available targets"
echo "  3. Start developing RTL in rtl/ directory"
echo ""
echo "For Nix users:"
echo "  • Run 'nix develop' to enter development shell"
echo "  • All tools will be automatically available"
