#!/bin/sh
set -eu

directory=$(mktemp -d)
trap 'rm -rf "$directory"' EXIT HUP INT TERM
unset BENCH6_TIMING_ENFORCEMENT

status=0
BENCH5B_ENFORCEMENT=off BENCHMARK_GATE_FIXTURE=bench6-overrun \
  scripts/run-render-benchmark.sh "$directory/default-timing-overrun.txt" || status=$?
test "$status" -eq 133
awk '/BENCH-6 tile-edit:/ { found = 1; if ($8 <= 8.0) exit 1 } END { if (!found) exit 1 }' \
  "$directory/default-timing-overrun.txt"
grep -Eq '^BENCH_TRAP source=Sources/RenderBenchmark/main.swift:[0-9]+ gate=BENCH-6 observed_p95_ms=[0-9.]+ target_p95_ms=8.0$' \
  "$directory/default-timing-overrun.txt"
if grep -q '^BENCH-6 timing enforcement:' "$directory/default-timing-overrun.txt"; then
  echo "Default BENCH-6 timing output unexpectedly changed" >&2
  exit 1
fi

BENCH5B_ENFORCEMENT=off BENCH6_TIMING_ENFORCEMENT=off BENCHMARK_GATE_FIXTURE=bench6-overrun \
  scripts/run-render-benchmark.sh "$directory/informational-timing-overrun.txt"
awk '/BENCH-6 tile-edit:/ { found = 1; if ($8 <= 8.0) exit 1 } END { if (!found) exit 1 }' \
  "$directory/informational-timing-overrun.txt"
grep -q '^BENCH-6 timing enforcement: bench6_timing_enforcement=off result=INFORMATIONAL reason=owner-decision-2026-07-18$' \
  "$directory/informational-timing-overrun.txt"
if grep -q '^BENCH_TRAP ' "$directory/informational-timing-overrun.txt"; then
  echo "Informational BENCH-6 timing fixture unexpectedly trapped" >&2
  exit 1
fi

status=0
BENCH5B_ENFORCEMENT=off BENCH6_TIMING_ENFORCEMENT=off BENCHMARK_GATE_FIXTURE=bench5a-overrun \
  scripts/run-render-benchmark.sh "$directory/informational-timing-bench5a-overrun.txt" || status=$?
test "$status" -eq 133
grep -q '^BENCH-6 timing enforcement: bench6_timing_enforcement=off result=INFORMATIONAL reason=owner-decision-2026-07-18$' \
  "$directory/informational-timing-bench5a-overrun.txt"
grep -Eq '^BENCH_TRAP source=Sources/RenderBenchmark/main.swift:[0-9]+ gate=BENCH-5a observed_p95_ms=[0-9.]+ target_p95_ms=16.7$' \
  "$directory/informational-timing-bench5a-overrun.txt"

status=0
BENCH5B_ENFORCEMENT=off BENCH6_TIMING_ENFORCEMENT=off BENCHMARK_GATE_FIXTURE=bench6-overinvalidation \
  scripts/run-render-benchmark.sh "$directory/informational-timing-correctness-violation.txt" || status=$?
test "$status" -eq 133
grep -q '^BENCH-6 timing enforcement: bench6_timing_enforcement=off result=INFORMATIONAL reason=owner-decision-2026-07-18$' \
  "$directory/informational-timing-correctness-violation.txt"
grep -Eq '^BENCH_TRAP source=Sources/RenderBenchmark/main.swift:[0-9]+ gate=BENCH-6-correctness-exact-damage-mapping fixture=overinvalidation$' \
  "$directory/informational-timing-correctness-violation.txt"

printf 'bench6_default_timing_overrun_exit=133 target_p95_ms=8.0 result=PASS\n'
printf 'bench6_informational_timing_overrun_exit=0 target_p95_ms=8.0 result=PASS\n'
printf 'bench6_informational_mode_bench5a_overrun_exit=133 result=PASS\n'
printf 'bench6_informational_mode_correctness_violation_exit=133 result=PASS\n'
