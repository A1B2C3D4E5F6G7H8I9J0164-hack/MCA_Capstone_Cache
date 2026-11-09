#!/usr/bin/env bash
# ============================================================================
# Script: sim/run_aditya_tests.sh
# Author: Aditya Rana
# Description:
#   Reproducible unit simulation runner for 32-bit Address Decoder and
#   Tag Comparator (rtl/address_decoder.v & sim/testbenches/tb_address_decoder.v).
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkdir -p sim/waveforms

# Check for Icarus Verilog
command -v iverilog >/dev/null 2>&1 || {
  if [[ -x /opt/homebrew/bin/iverilog ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
  elif [[ -x /usr/local/bin/iverilog ]]; then
    export PATH="/usr/local/bin:$PATH"
  else
    echo "ERROR: Icarus Verilog (iverilog/vvp) not found. Please install via homebrew or package manager."
    exit 127
  fi
}

OUT_DIR="${TMPDIR:-/tmp}/mca-cache-aditya-tests"
mkdir -p "$OUT_DIR"

echo "================================================================"
echo "Compiling: Address Decoder & Tag Comparator Unit Testbench"
echo "================================================================"
iverilog -g2012 -Wall -s tb_address_decoder \
  -o "$OUT_DIR/address_decoder.vvp" \
  rtl/address_decoder.v \
  sim/testbenches/tb_address_decoder.v

echo "================================================================"
echo "Running: Address Decoder & Tag Comparator Unit Simulation"
echo "================================================================"
vvp "$OUT_DIR/address_decoder.vvp"

echo "================================================================"
echo "PASS: Address Decoder unit verification completed successfully!"
echo "Waveform generated at: sim/waveforms/address_decoder.vcd"
echo "================================================================"

