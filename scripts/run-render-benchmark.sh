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
  emit_timing_diagnostic() {
    gate=$1
    output_prefix=$2
    output_field=$3
    source_needle=$4
    target=$5
    metric=$6
    observed=$(awk -v prefix="$output_prefix" -v field="$output_field" \
      'index($0, prefix) == 1 { print $field; exit }' "$benchmark_log")
    if [ -z "$observed" ] \
      || ! grep -q '^BENCH-6 sequence=' "$benchmark_log" \
      || ! awk -v value="$observed" -v limit="$target" 'BEGIN { exit !(value > limit) }'; then
      return 1
    fi
    source_line=$(awk -v needle="$source_needle" 'index($0, needle) { print NR; exit }' \
      Sources/RenderBenchmark/main.swift)
    printf 'BENCH_TRAP source=Sources/RenderBenchmark/main.swift:%s gate=%s observed_%s_ms=%s target_%s_ms=%s\n' \
      "$source_line" "$gate" "$metric" "$observed" "$metric" "$target" \
      | tee -a "$output" >&2
  }

  timing_fixture_diagnostic=0
  case "$fixture" in
    bench1-overrun)
      if emit_timing_diagnostic BENCH-1 'BENCH-1 drag:' 8 'precondition(bench1.p95' 16.7 p95; then
        timing_fixture_diagnostic=1
      fi
      ;;
    bench2-overrun)
      if emit_timing_diagnostic BENCH-2 'BENCH-2 pan:' 8 'precondition(bench2.p95' 16.7 p95; then
        timing_fixture_diagnostic=1
      fi
      ;;
    bench2b-overrun)
      if emit_timing_diagnostic BENCH-2b 'BENCH-2b exposure corridor:' 9 \
        'precondition(bench2b.p95' 16.7 p95; then
        timing_fixture_diagnostic=1
      fi
      ;;
    bench3-overrun)
      if emit_timing_diagnostic BENCH-3 'BENCH-3 zoom:' 8 'precondition(bench3.p95' 33.0 p95; then
        timing_fixture_diagnostic=1
      fi
      ;;
    bench3-settle-overrun)
      if emit_timing_diagnostic BENCH-3-settle 'BENCH-3 settle:' 3 \
        'precondition(bench3Settle' 100.0 settle; then
        timing_fixture_diagnostic=1
      fi
      ;;
    bench5a-overrun)
      if emit_timing_diagnostic BENCH-5a 'BENCH-5a undo-redo:' 8 \
        'precondition(bench5a.p95' 16.7 p95; then
        timing_fixture_diagnostic=1
      fi
      ;;
    bench5b-overrun)
      if emit_timing_diagnostic BENCH-5b 'BENCH-5b record:' 8 \
        'precondition(bench5b.p95' 1.0 p95; then
        timing_fixture_diagnostic=1
      fi
      ;;
    bench6-overrun)
      if emit_timing_diagnostic BENCH-6 'BENCH-6 tile-edit:' 8 \
        'precondition(bench6.p95' 8.0 p95; then
        timing_fixture_diagnostic=1
      fi
      ;;
  esac

  if [ "$fixture" = "bench6-overinvalidation" ]; then
    bench6_correctness_line=$(awk '/BENCH-6 rendered tiles must exactly equal the frozen damage mapping/ { print NR; exit }' Sources/RenderBenchmark/main.swift)
    printf 'BENCH_TRAP source=Sources/RenderBenchmark/main.swift:%s gate=BENCH-6-correctness-exact-damage-mapping fixture=overinvalidation\n' \
      "$bench6_correctness_line" | tee -a "$output" >&2
  elif [ "$timing_fixture_diagnostic" -eq 1 ]; then
    :
  elif grep -q '^BENCH-2 pan:' "$benchmark_log" && ! grep -q '^BENCH-2b exposure corridor:' "$benchmark_log"; then
    corridor_line=$(awk '/let bench2b = try measure/ { print NR; exit }' Sources/RenderBenchmark/main.swift)
    printf 'BENCH_TRAP source=Sources/RenderBenchmark/main.swift:%s gate=BENCH-2b-exact-corridor-indices\n' "$corridor_line" \
      | tee -a "$output" >&2
  elif [ "${BENCH1_TIMING_ENFORCEMENT:-on}" != off ] \
    && emit_timing_diagnostic BENCH-1 'BENCH-1 drag:' 8 'precondition(bench1.p95' 16.7 p95; then
    :
  elif [ "${BENCH2_TIMING_ENFORCEMENT:-on}" != off ] \
    && emit_timing_diagnostic BENCH-2 'BENCH-2 pan:' 8 'precondition(bench2.p95' 16.7 p95; then
    :
  elif [ "${BENCH2B_TIMING_ENFORCEMENT:-on}" != off ] \
    && emit_timing_diagnostic BENCH-2b 'BENCH-2b exposure corridor:' 9 \
      'precondition(bench2b.p95' 16.7 p95; then
    :
  elif [ "${BENCH3_TIMING_ENFORCEMENT:-on}" != off ] \
    && emit_timing_diagnostic BENCH-3 'BENCH-3 zoom:' 8 'precondition(bench3.p95' 33.0 p95; then
    :
  elif [ "${BENCH3_TIMING_ENFORCEMENT:-on}" != off ] \
    && emit_timing_diagnostic BENCH-3-settle 'BENCH-3 settle:' 3 \
      'precondition(bench3Settle' 100.0 settle; then
    :
  elif [ "${BENCH5A_TIMING_ENFORCEMENT:-on}" != off ] \
    && emit_timing_diagnostic BENCH-5a 'BENCH-5a undo-redo:' 8 \
      'precondition(bench5a.p95' 16.7 p95; then
    :
  elif [ "${BENCH5B_ENFORCEMENT:-on}" != off ] \
    && emit_timing_diagnostic BENCH-5b 'BENCH-5b record:' 8 \
      'precondition(bench5b.p95' 1.0 p95; then
    :
  elif [ "${BENCH6_TIMING_ENFORCEMENT:-on}" != off ] \
    && emit_timing_diagnostic BENCH-6 'BENCH-6 tile-edit:' 8 \
      'precondition(bench6.p95' 8.0 p95; then
    :
  fi
fi
exit "$status"
