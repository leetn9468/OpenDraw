#!/bin/sh
set -eu

output=${1:-artifacts/r4/peak-memory.txt}
settle_limit=$((500 * 1024 * 1024))
export_limit=$((650 * 1024 * 1024))
mkdir -p "$(dirname "$output")"
swift build -c release --product R4GateHarness >/dev/null

record_environment() {
  printf 'revision=%s model=%s chip=%s memory_bytes=%s os=%s build=%s arch=%s swift=%s\n' \
    "$(git rev-parse HEAD)" "$(sysctl -n hw.model)" "$(sysctl -n machdep.cpu.brand_string)" \
    "$(sysctl -n hw.memsize)" "$(sw_vers -productVersion)" "$(sw_vers -buildVersion)" "$(uname -m)" \
    "$(swift --version 2>&1 | head -1)" >>"$output"
}

measure() {
  scenario=$1
  limit=$2
  timing=$(mktemp)
  trap 'rm -f "$timing"' EXIT HUP INT TERM
  /usr/bin/time -l .build/release/R4GateHarness "$scenario" 2>"$timing"
  peak=$(awk '/maximum resident set size/ { print $1; exit }' "$timing")
  test -n "$peak"
  printf '%s peak_bytes=%s limit_bytes=%s result=' "$scenario" "$peak" "$limit" | tee -a "$output"
  if [ "$peak" -le "$limit" ]; then
    printf 'PASS\n' | tee -a "$output"
  else
    printf 'FAIL\n' | tee -a "$output"
    exit 1
  fi
  rm -f "$timing"
  trap - EXIT HUP INT TERM
}

: >"$output"
record_environment
measure settle "$settle_limit"
measure export "$export_limit"
