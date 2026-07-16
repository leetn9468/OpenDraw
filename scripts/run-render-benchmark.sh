#!/bin/sh
set -eu

output=${1:-artifacts/r4/render-benchmark.txt}
mkdir -p "$(dirname "$output")"
swift build -c release --product RenderBenchmark >/dev/null
benchmark_log=$(mktemp)
trap 'rm -f "$benchmark_log"' EXIT HUP INT TERM
printf 'revision=%s model=%s chip=%s memory_bytes=%s os=%s build=%s arch=%s swift=%s\n' \
  "$(git rev-parse HEAD)" "$(sysctl -n hw.model)" "$(sysctl -n machdep.cpu.brand_string)" \
  "$(sysctl -n hw.memsize)" "$(sw_vers -productVersion)" "$(sw_vers -buildVersion)" "$(uname -m)" \
  "$(swift --version 2>&1 | head -1)" >"$output"
status=0
# Swift's stdout is block-buffered when redirected on hosted runners. Keep it
# unbuffered so an intentional release-mode gate trap cannot discard every
# completed BENCH line and the observation that triggered the gate.
NSUnbufferedIO=YES .build/release/RenderBenchmark >"$benchmark_log" 2>&1 || status=$?
cat "$benchmark_log" | tee -a "$output"
if [ "$status" -eq 133 ]; then
  last_completed=$(awk '/^BENCH-/ { line = $0 } END { print line }' "$benchmark_log")
  printf 'BENCH_TRAP exit=133 last_completed=%s\n' "${last_completed:-none}" | tee -a "$output" >&2
  if grep -q '^BENCH-5 mix=' "$benchmark_log"; then
    bench5a=$(awk '/BENCH-5a undo-redo:/ { print $8 }' "$benchmark_log")
    bench5b=$(awk '/BENCH-5b record:/ { print $8 }' "$benchmark_log")
    if awk -v value="$bench5a" 'BEGIN { exit !(value > 16.7) }'; then
      printf 'BENCH_TRAP source=Sources/RenderBenchmark/main.swift:216 gate=BENCH-5a observed_p95_ms=%s target_p95_ms=16.7\n' \
        "$bench5a" | tee -a "$output" >&2
    elif awk -v value="$bench5b" 'BEGIN { exit !(value > 1.0) }'; then
      printf 'BENCH_TRAP source=Sources/RenderBenchmark/main.swift:218 gate=BENCH-5b observed_p95_ms=%s target_p95_ms=1.0\n' \
        "$bench5b" | tee -a "$output" >&2
    fi
  elif grep -q '^BENCH-2 pan:' "$benchmark_log" && ! grep -q '^BENCH-2b forced-exposure pan:' "$benchmark_log"; then
    printf 'BENCH_TRAP source=Sources/RenderBenchmark/main.swift:134 gate=BENCH-2b-nonzero-strip\n' \
      | tee -a "$output" >&2
  fi
fi
exit "$status"
