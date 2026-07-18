#!/bin/sh
set -eu

directory=$(mktemp -d)
trap 'rm -rf "$directory"' EXIT HUP INT TERM

run_forced_timing_trap() {
  selector=$1
  target=$2
  gate=$3
  output_prefix=$4
  output_field=$5
  threshold=$6
  output="$directory/$selector.txt"

  status=0
  BENCHMARK_GATE_FIXTURE="$selector" \
    scripts/run-render-benchmark-fixture.sh "$target" "$output" || status=$?
  test "$status" -eq 133
  awk -v prefix="$output_prefix" -v field="$output_field" -v threshold="$threshold" \
    'index($0, prefix) == 1 { found = 1; if ($field <= threshold) exit 1 } END { if (!found) exit 1 }' \
    "$output"
  grep -Eq "^BENCH_TRAP source=Sources/RenderBenchmark/main.swift:[0-9]+ gate=$gate observed_.*_ms=[0-9.]+ target_.*_ms=$threshold$" \
    "$output"
  printf 'fixture=%s target=%s exit=133 result=PASS\n' "$selector" "$gate"
}

# Every timing precondition is independently and deterministically falsifiable.
run_forced_timing_trap bench1-overrun bench1 BENCH-1 'BENCH-1 drag:' 8 16.7
run_forced_timing_trap bench2-overrun bench2 BENCH-2 'BENCH-2 pan:' 8 16.7
run_forced_timing_trap bench2b-overrun bench2b BENCH-2b 'BENCH-2b exposure corridor:' 9 16.7
run_forced_timing_trap bench3-overrun bench3 BENCH-3 'BENCH-3 zoom:' 8 33.0
run_forced_timing_trap bench3-settle-overrun bench3 BENCH-3-settle 'BENCH-3 settle:' 3 100.0
run_forced_timing_trap bench5a-overrun bench5a BENCH-5a 'BENCH-5a undo-redo:' 8 16.7
run_forced_timing_trap bench5b-overrun bench5b BENCH-5b 'BENCH-5b record:' 8 1.0
run_forced_timing_trap bench6-overrun bench6 BENCH-6 'BENCH-6 tile-edit:' 8 8.0

# Hosted-policy behavior is tested in an all-timing-off fixture environment.
# The workflow exactness gate separately proves production turns off only 5b/6.
BENCHMARK_GATE_FIXTURE=bench5b-overrun \
  scripts/run-render-benchmark-fixture.sh none "$directory/hosted-policy-bench5b-overrun.txt"
grep -q '^BENCH-5b enforcement: bench5b_enforcement=off result=INFORMATIONAL$' \
  "$directory/hosted-policy-bench5b-overrun.txt"
grep -q '^BENCH-6 timing enforcement: bench6_timing_enforcement=off result=INFORMATIONAL reason=owner-decision-2026-07-18$' \
  "$directory/hosted-policy-bench5b-overrun.txt"
if grep -q '^BENCH_TRAP ' "$directory/hosted-policy-bench5b-overrun.txt"; then
  echo "Hosted-policy BENCH-5b fixture unexpectedly trapped" >&2
  exit 1
fi

printf 'hosted_policy_bench5b_overrun_exit=0 result=PASS\n'
