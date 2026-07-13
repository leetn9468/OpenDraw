#!/bin/sh
set -eu

samples=${1:-20}
output=${2:-artifacts/r4/startup-p95.txt}
target_ms=2000
test "$samples" -ge 20
mkdir -p "$(dirname "$output")"
swift build -c release --product VectorFoundry >/dev/null
values=$(mktemp)
trap 'rm -f "$values"' EXIT HUP INT TERM
: >"$output"
printf 'revision=%s model=%s chip=%s memory_bytes=%s os=%s build=%s arch=%s swift=%s policy=clean-process-cold-app-state-warm-os-caches start=static-initializer stop=window-ready\n' \
  "$(git rev-parse HEAD)" "$(sysctl -n hw.model)" "$(sysctl -n machdep.cpu.brand_string)" \
  "$(sysctl -n hw.memsize)" "$(sw_vers -productVersion)" "$(sw_vers -buildVersion)" "$(uname -m)" \
  "$(swift --version 2>&1 | head -1)" >>"$output"

i=1
while [ "$i" -le "$samples" ]; do
  home=$(mktemp -d)
  line=$(HOME="$home" .build/release/VectorFoundry --startup-probe)
  rm -rf "$home"
  value=$(printf '%s\n' "$line" | awk -F= '/STARTUP_READY_MS/ { print $2; exit }')
  test -n "$value"
  printf 'sample=%s startup_ready_ms=%s\n' "$i" "$value" >>"$output"
  printf '%s\n' "$value" >>"$values"
  i=$((i + 1))
done

sorted=$(mktemp)
trap 'rm -f "$values" "$sorted"' EXIT HUP INT TERM
sort -n "$values" >"$sorted"
p50_index=$(((50 * samples + 99) / 100))
p95_index=$(((95 * samples + 99) / 100))
p50=$(sed -n "${p50_index}p" "$sorted")
p95=$(sed -n "${p95_index}p" "$sorted")
maximum=$(tail -1 "$sorted")
result=PASS
awk -v observed="$p95" -v target="$target_ms" 'BEGIN { exit !(observed <= target) }' || result=FAIL
printf 'summary samples=%s p50_ms=%s p95_ms=%s max_ms=%s target_ms=%s result=%s\n' \
  "$samples" "$p50" "$p95" "$maximum" "$target_ms" "$result" | tee -a "$output"
test "$result" = PASS
