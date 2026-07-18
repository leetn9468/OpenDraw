#!/bin/sh
set -eu

target_gate=${1:?usage: run-render-benchmark-fixture.sh TARGET_GATE OUTPUT}
output=${2:?usage: run-render-benchmark-fixture.sh TARGET_GATE OUTPUT}

# Fixture invariant: runner speed can never select the exit status. Disable every
# timing precondition, then enable only the deterministically forced target. The
# production frame counts and all speed-independent correctness checks remain live.
BENCH1_TIMING_ENFORCEMENT=off
BENCH2_TIMING_ENFORCEMENT=off
BENCH2B_TIMING_ENFORCEMENT=off
BENCH3_TIMING_ENFORCEMENT=off
BENCH5A_TIMING_ENFORCEMENT=off
BENCH5B_ENFORCEMENT=off
BENCH6_TIMING_ENFORCEMENT=off

case "$target_gate" in
  bench1) BENCH1_TIMING_ENFORCEMENT=on ;;
  bench2) BENCH2_TIMING_ENFORCEMENT=on ;;
  bench2b) BENCH2B_TIMING_ENFORCEMENT=on ;;
  bench3) BENCH3_TIMING_ENFORCEMENT=on ;;
  bench5a) BENCH5A_TIMING_ENFORCEMENT=on ;;
  bench5b) BENCH5B_ENFORCEMENT=on ;;
  bench6) BENCH6_TIMING_ENFORCEMENT=on ;;
  none) ;;
  *)
    printf 'unknown fixture timing target: %s\n' "$target_gate" >&2
    exit 64
    ;;
esac

export BENCH1_TIMING_ENFORCEMENT BENCH2_TIMING_ENFORCEMENT
export BENCH2B_TIMING_ENFORCEMENT BENCH3_TIMING_ENFORCEMENT
export BENCH5A_TIMING_ENFORCEMENT BENCH5B_ENFORCEMENT
export BENCH6_TIMING_ENFORCEMENT

exec scripts/run-render-benchmark.sh "$output"
