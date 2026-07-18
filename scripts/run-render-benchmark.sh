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
  fixture=$(awk -F= '/^BENCH_GATE_FIXTURE=/ { print $2; exit }' "$benchmark_log")
  bench6=$(awk '/BENCH-6 tile-edit:/ { print $8 }' "$benchmark_log")
  if [ "$fixture" = "bench6-overinvalidation" ]; then
    bench6_correctness_line=$(awk '/BENCH-6 rendered tiles must exactly equal the frozen damage mapping/ { print NR; exit }' Sources/RenderBenchmark/main.swift)
    printf 'BENCH_TRAP source=Sources/RenderBenchmark/main.swift:%s gate=BENCH-6-correctness-exact-damage-mapping fixture=overinvalidation\n' \
      "$bench6_correctness_line" | tee -a "$output" >&2
  elif [ -n "$bench6" ] \
    && awk -v value="$bench6" 'BEGIN { exit !(value > 8.0) }' \
    && ! grep -q '^BENCH-6 timing enforcement: bench6_timing_enforcement=off ' "$benchmark_log"; then
    bench6_line=$(awk '/precondition\(bench6.p95/ { print NR; exit }' Sources/RenderBenchmark/main.swift)
    printf 'BENCH_TRAP source=Sources/RenderBenchmark/main.swift:%s gate=BENCH-6 observed_p95_ms=%s target_p95_ms=8.0\n' \
      "$bench6_line" "$bench6" | tee -a "$output" >&2
  elif grep -q '^BENCH-5 mix=' "$benchmark_log"; then
    bench5a=$(awk '/BENCH-5a undo-redo:/ { print $8 }' "$benchmark_log")
    bench5b=$(awk '/BENCH-5b record:/ { print $8 }' "$benchmark_log")
    if awk -v value="$bench5a" 'BEGIN { exit !(value > 16.7) }'; then
      bench5a_line=$(awk '/precondition\(bench5a.p95/ { print NR; exit }' Sources/RenderBenchmark/main.swift)
      printf 'BENCH_TRAP source=Sources/RenderBenchmark/main.swift:%s gate=BENCH-5a observed_p95_ms=%s target_p95_ms=16.7\n' \
        "$bench5a_line" "$bench5a" | tee -a "$output" >&2
    elif awk -v value="$bench5b" 'BEGIN { exit !(value > 1.0) }'; then
      bench5b_line=$(awk '/precondition\(bench5b.p95/ { print NR; exit }' Sources/RenderBenchmark/main.swift)
      printf 'BENCH_TRAP source=Sources/RenderBenchmark/main.swift:%s gate=BENCH-5b observed_p95_ms=%s target_p95_ms=1.0\n' \
        "$bench5b_line" "$bench5b" | tee -a "$output" >&2
    fi
  elif grep -q '^BENCH-2 pan:' "$benchmark_log" && ! grep -q '^BENCH-2b exposure corridor:' "$benchmark_log"; then
    corridor_line=$(awk '/let bench2b = try measure/ { print NR; exit }' Sources/RenderBenchmark/main.swift)
    printf 'BENCH_TRAP source=Sources/RenderBenchmark/main.swift:%s gate=BENCH-2b-exact-corridor-indices\n' "$corridor_line" \
      | tee -a "$output" >&2
  fi
fi
exit "$status"
