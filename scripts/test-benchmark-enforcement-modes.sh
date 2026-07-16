#!/bin/sh
set -eu

directory=$(mktemp -d)
trap 'rm -rf "$directory"' EXIT HUP INT TERM
unset BENCH5B_ENFORCEMENT

status=0
BENCHMARK_GATE_FIXTURE=bench5b-overrun \
  scripts/run-render-benchmark.sh "$directory/default-bench5b-overrun.txt" || status=$?
test "$status" -eq 133
awk '/BENCH-5b record:/ { found = 1; if ($8 <= 1.0) exit 1 } END { if (!found) exit 1 }' \
  "$directory/default-bench5b-overrun.txt"
grep -q '^BENCH-5b enforcement: bench5b_enforcement=on result=BLOCKING$' \
  "$directory/default-bench5b-overrun.txt"
grep -Eq '^BENCH_TRAP source=Sources/RenderBenchmark/main.swift:[0-9]+ gate=BENCH-5b observed_p95_ms=[0-9.]+ target_p95_ms=1.0$' \
  "$directory/default-bench5b-overrun.txt"

BENCH5B_ENFORCEMENT=off BENCHMARK_GATE_FIXTURE=bench5b-overrun \
  scripts/run-render-benchmark.sh "$directory/informational-bench5b-overrun.txt"
awk '/BENCH-5b record:/ { found = 1; if ($8 <= 1.0) exit 1 } END { if (!found) exit 1 }' \
  "$directory/informational-bench5b-overrun.txt"
grep -q '^BENCH-5b enforcement: bench5b_enforcement=off result=INFORMATIONAL$' \
  "$directory/informational-bench5b-overrun.txt"
if grep -q '^BENCH_TRAP ' "$directory/informational-bench5b-overrun.txt"; then
  echo "Informational BENCH-5b fixture unexpectedly trapped" >&2
  exit 1
fi

status=0
BENCH5B_ENFORCEMENT=off BENCHMARK_GATE_FIXTURE=bench5a-and-b-overrun \
  scripts/run-render-benchmark.sh "$directory/informational-bench5a-overrun.txt" || status=$?
test "$status" -eq 133
awk '/BENCH-5a undo-redo:/ { found = 1; if ($8 <= 16.7) exit 1 } END { if (!found) exit 1 }' \
  "$directory/informational-bench5a-overrun.txt"
awk '/BENCH-5b record:/ { found = 1; if ($8 <= 1.0) exit 1 } END { if (!found) exit 1 }' \
  "$directory/informational-bench5a-overrun.txt"
grep -q '^BENCH-5b enforcement: bench5b_enforcement=off result=INFORMATIONAL$' \
  "$directory/informational-bench5a-overrun.txt"
grep -Eq '^BENCH_TRAP source=Sources/RenderBenchmark/main.swift:[0-9]+ gate=BENCH-5a observed_p95_ms=[0-9.]+ target_p95_ms=16.7$' \
  "$directory/informational-bench5a-overrun.txt"

printf 'default_bench5b_overrun_exit=133 result=PASS\n'
printf 'informational_bench5b_overrun_exit=0 result=PASS\n'
printf 'informational_mode_bench5a_overrun_exit=133 result=PASS\n'
