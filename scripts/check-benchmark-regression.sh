#!/bin/sh
set -eu

baseline=${1:?baseline TSV required}
current=${2:?benchmark output required}
comparison=${3:-artifacts/r4/benchmark-comparison.txt}
test -s "$baseline"
test -s "$current"
valid_until=$(awk -F= '/^# valid_until=/ { print $2; exit }' "$baseline")
test -n "$valid_until"
today=$(date +%Y-%m-%d)
if [ "$today" \> "$valid_until" ]; then
  echo "Benchmark baseline is stale: $valid_until" >&2
  exit 1
fi
mkdir -p "$(dirname "$comparison")"
: >"$comparison"

extract() {
  metric=$1
  case "$metric" in
    bench1_p95) awk '/BENCH-1 drag:/ { print $8 }' "$current" ;;
    bench2_p95) awk '/BENCH-2 pan:/ { print $8 }' "$current" ;;
    bench2b_p95) awk '/BENCH-2b exposure corridor:/ { print $9 }' "$current" ;;
    bench3_p95) awk '/BENCH-3 zoom:/ { print $8 }' "$current" ;;
    bench3_settle) awk '/BENCH-3 settle:/ { print $3 }' "$current" ;;
    bench5a_p95) awk '/BENCH-5a undo-redo:/ { print $8 }' "$current" ;;
    bench5b_p95) awk '/BENCH-5b record:/ { print $8 }' "$current" ;;
    bench6_p95) awk '/BENCH-6 tile-edit:/ { print $8 }' "$current" ;;
    *) return 1 ;;
  esac
}

failed=0
while IFS="$(printf '\t')" read -r metric base allowed; do
  case "$metric" in ''|'#'*) continue ;; esac
  observed=$(extract "$metric")
  test -n "$observed"
  # Gate/test-side numeric policy: compare the parsed decimal strings exactly
  # and inclusively at observed <= baseline * allowed. The six-decimal ratio is
  # display only and never participates in the pass/fail decision.
  ratio=$(awk -v value="$observed" -v baseline="$base" 'BEGIN { printf "%.6f", value / baseline }')
  result=PASS
  python3 - "$observed" "$base" "$allowed" <<'PY' || {
from decimal import Decimal
import sys
observed, baseline, allowed = map(Decimal, sys.argv[1:])
raise SystemExit(0 if observed <= baseline * allowed else 1)
PY
    result=FAIL
    failed=1
  }
  printf '%s baseline_ms=%s observed_ms=%s ratio=%s allowed_ratio=%s result=%s\n' \
    "$metric" "$base" "$observed" "$ratio" "$allowed" "$result" | tee -a "$comparison"
done <"$baseline"
exit "$failed"
