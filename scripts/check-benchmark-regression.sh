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
    bench2b_p95) awk '/BENCH-2b forced-exposure pan:/ { print $9 }' "$current" ;;
    bench3_p95) awk '/BENCH-3 zoom:/ { print $8 }' "$current" ;;
    bench3_settle) awk '/BENCH-3 settle:/ { print $3 }' "$current" ;;
    *) return 1 ;;
  esac
}

failed=0
while IFS="$(printf '\t')" read -r metric base allowed; do
  case "$metric" in ''|'#'*) continue ;; esac
  observed=$(extract "$metric")
  test -n "$observed"
  ratio=$(awk -v value="$observed" -v baseline="$base" 'BEGIN { printf "%.6f", value / baseline }')
  result=PASS
  awk -v ratio="$ratio" -v allowed="$allowed" 'BEGIN { exit !(ratio <= allowed) }' || {
    result=FAIL
    failed=1
  }
  printf '%s baseline_ms=%s observed_ms=%s ratio=%s allowed_ratio=%s result=%s\n' \
    "$metric" "$base" "$observed" "$ratio" "$allowed" "$result" | tee -a "$comparison"
done <"$baseline"
exit "$failed"
