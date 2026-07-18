#!/bin/sh
set -eu

directory=$(mktemp -d)
trap 'rm -rf "$directory"' EXIT HUP INT TERM

scripts/check-benchmark-production-env.sh >"$directory/exact.txt"
grep -q '^production_benchmark_timing_env=BENCH5B_ENFORCEMENT=off,BENCH6_TIMING_ENFORCEMENT=off result=PASS$' \
  "$directory/exact.txt"

status=0
BENCHMARK_PRODUCTION_ENV_EXTRA_OFF=BENCH1_TIMING_ENFORCEMENT \
  scripts/check-benchmark-production-env.sh >"$directory/injected-extra.txt" 2>&1 || status=$?
test "$status" -ne 0
grep -q 'production_benchmark_timing_env_exactness=FAIL' "$directory/injected-extra.txt"
grep -q 'BENCH1_TIMING_ENFORCEMENT=off' "$directory/injected-extra.txt"

cat "$directory/exact.txt"
printf 'production_benchmark_extra_off_injection_exit=%s result=PASS\n' "$status"
