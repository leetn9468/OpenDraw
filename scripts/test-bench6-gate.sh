#!/bin/sh
set -eu

directory=$(mktemp -d)
trap 'rm -rf "$directory"' EXIT HUP INT TERM

# Hosted BENCH-6 timing is informational even when deterministically over target.
BENCHMARK_GATE_FIXTURE=bench6-overrun \
  scripts/run-render-benchmark-fixture.sh none "$directory/hosted-policy-timing-overrun.txt"
awk '/BENCH-6 tile-edit:/ { found = 1; if ($8 <= 8.0) exit 1 } END { if (!found) exit 1 }' \
  "$directory/hosted-policy-timing-overrun.txt"
grep -q '^BENCH-5b enforcement: bench5b_enforcement=off result=INFORMATIONAL$' \
  "$directory/hosted-policy-timing-overrun.txt"
grep -q '^BENCH-6 timing enforcement: bench6_timing_enforcement=off result=INFORMATIONAL reason=owner-decision-2026-07-18$' \
  "$directory/hosted-policy-timing-overrun.txt"
if grep -q '^BENCH_TRAP ' "$directory/hosted-policy-timing-overrun.txt"; then
  echo "Hosted-policy BENCH-6 timing fixture unexpectedly trapped" >&2
  exit 1
fi

# A decision-backed timing switch cannot disable an unrelated timing gate.
status=0
BENCHMARK_GATE_FIXTURE=bench5a-overrun \
  scripts/run-render-benchmark-fixture.sh bench5a "$directory/hosted-policy-bench5a-overrun.txt" || status=$?
test "$status" -eq 133
grep -q '^BENCH-6 timing enforcement: bench6_timing_enforcement=off result=INFORMATIONAL reason=owner-decision-2026-07-18$' \
  "$directory/hosted-policy-bench5a-overrun.txt"
grep -Eq '^BENCH_TRAP source=Sources/RenderBenchmark/main.swift:[0-9]+ gate=BENCH-5a observed_p95_ms=[0-9.]+ target_p95_ms=16.7$' \
  "$directory/hosted-policy-bench5a-overrun.txt"

# Correctness remains unconditional when every timing enforcement is OFF.
status=0
BENCHMARK_GATE_FIXTURE=bench6-overinvalidation \
  scripts/run-render-benchmark-fixture.sh none "$directory/all-timing-off-correctness-violation.txt" || status=$?
test "$status" -eq 133
grep -q '^BENCH-6 timing enforcement: bench6_timing_enforcement=off result=INFORMATIONAL reason=owner-decision-2026-07-18$' \
  "$directory/all-timing-off-correctness-violation.txt"
grep -Eq '^BENCH_TRAP source=Sources/RenderBenchmark/main.swift:[0-9]+ gate=BENCH-6-correctness-exact-damage-mapping fixture=overinvalidation$' \
  "$directory/all-timing-off-correctness-violation.txt"

printf 'hosted_policy_bench6_timing_overrun_exit=0 target_p95_ms=8.0 result=PASS\n'
printf 'hosted_policy_bench5a_overrun_exit=133 result=PASS\n'
printf 'all_timing_off_correctness_violation_exit=133 result=PASS\n'
