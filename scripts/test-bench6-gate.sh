#!/bin/sh
set -eu

directory=$(mktemp -d)
trap 'rm -rf "$directory"' EXIT HUP INT TERM
status=0
BENCH5B_ENFORCEMENT=off BENCHMARK_GATE_FIXTURE=bench6-overrun \
  scripts/run-render-benchmark.sh "$directory/bench6-overrun.txt" || status=$?
test "$status" -eq 133
awk '/BENCH-6 tile-edit:/ { found = 1; if ($8 <= 8.0) exit 1 } END { if (!found) exit 1 }' \
  "$directory/bench6-overrun.txt"
grep -Eq '^BENCH_TRAP source=Sources/RenderBenchmark/main.swift:[0-9]+ gate=BENCH-6 observed_p95_ms=[0-9.]+ target_p95_ms=8.0$' \
  "$directory/bench6-overrun.txt"
printf 'bench6_overrun_exit=133 target_p95_ms=8.0 result=PASS\n'
