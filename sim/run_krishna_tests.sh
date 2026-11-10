#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p sim/waveforms
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
command -v iverilog >/dev/null 2>&1 || { echo "ERROR: install Icarus Verilog (iverilog/vvp)"; exit 127; }
command -v vvp >/dev/null 2>&1 || { echo "ERROR: vvp not found"; exit 127; }
OUT_DIR="${TMPDIR:-/tmp}/mca-cache-phase1-tests"
mkdir -p "$OUT_DIR"
run_test() {
  local top="$1" output="$2"; shift 2
  echo "=== Compile: $top ==="
  iverilog -g2012 -Wall -s "$top" -o "$OUT_DIR/$output" "$@"
  echo "=== Run: $top ==="
  vvp "$OUT_DIR/$output"
}
if [[ -f rtl/address_decoder.v && -f sim/testbenches/tb_address_decoder.v ]]; then
  run_test tb_address_decoder address_decoder.vvp rtl/address_decoder.v sim/testbenches/tb_address_decoder.v
fi
run_test tb_cache_controller controller.vvp rtl/cache_controller.v rtl/performance_monitor.v sim/testbenches/tb_cache_controller.v
run_test tb_main_memory main_memory.vvp memory/main_memory_model.v sim/testbenches/tb_main_memory.v
if [[ -f sim/testbenches/tb_memory_init.v ]]; then
  run_test tb_memory_init memory_init.vvp memory/main_memory_model.v sim/testbenches/tb_memory_init.v
fi
run_test tb_performance_monitor performance_monitor.vvp rtl/performance_monitor.v sim/testbenches/tb_performance_monitor.v
if [[ -f rtl/address_decoder.v && -f rtl/cache_storage.v ]]; then
  echo "=== Elaborate integrated cache_top ==="
  iverilog -g2012 -Wall -s cache_top -o "$OUT_DIR/cache_top.vvp" rtl/address_decoder.v rtl/cache_storage.v rtl/cache_controller.v rtl/performance_monitor.v memory/main_memory_model.v rtl/cache_top.v
  echo "PASS: cache_top elaborated"
else
  echo "SKIP: cache_top elaboration — waiting for rtl/address_decoder.v and rtl/cache_storage.v"
fi
echo "ALL AVAILABLE PHASE I TESTS COMPLETED"
