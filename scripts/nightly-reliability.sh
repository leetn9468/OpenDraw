#!/bin/sh
set -eu

output=${1:-artifacts/r4/reliability-100x100.txt}
mkdir -p "$(dirname "$output")"
swift build -c release --product VectorFoundry >/dev/null
: >"$output"
printf 'revision=%s model=%s chip=%s memory_bytes=%s os=%s build=%s arch=%s swift=%s timeout_seconds=30\n' \
  "$(git rev-parse HEAD)" "$(sysctl -n hw.model)" "$(sysctl -n machdep.cpu.brand_string)" \
  "$(sysctl -n hw.memsize)" "$(sw_vers -productVersion)" "$(sw_vers -buildVersion)" "$(uname -m)" \
  "$(swift --version 2>&1 | head -1)" >>"$output"
printf 'execution=sequential smoke_path=codec-only ui_initialized=false wall_clock=aggregate-loop-elapsed\n' >>"$output"
start=$(date +%s)
launches=0
round_trips=0
crashes=0
nonzero_exits=0
timeouts=0
corruption_failures=0
seen_pids=$(mktemp)
trap 'rm -f "$seen_pids"' EXIT HUP INT TERM

while [ "$launches" -lt 100 ]; do
  launch=$((launches + 1))
  launch_start=$(python3 -c 'import time; print(time.monotonic_ns())')
  set +e
  line=$(perl -e '$SIG{ALRM}=sub{exit 124}; alarm shift; exec @ARGV' 30 .build/release/VectorFoundry --smoke 2>&1)
  status=$?
  set -e
  launch_end=$(python3 -c 'import time; print(time.monotonic_ns())')
  duration_ms=$(( (launch_end - launch_start) / 1000000 ))
  pid=$(printf '%s\n' "$line" | sed -n 's/.*pid=\([0-9][0-9]*\).*/\1/p')
  smoke_ms=$(printf '%s\n' "$line" | sed -n 's/.*duration_ms=\([0-9.][0-9.]*\).*/\1/p')
  pid_is_unique=true
  if [ -n "$pid" ] && rg -qx "$pid" "$seen_pids"; then pid_is_unique=false; fi
  if [ "$status" -eq 0 ] && [ -n "$pid" ] && [ -n "$smoke_ms" ] \
    && [ "$pid_is_unique" = true ] && printf '%s' "$line" | rg -q '100 native round trips passed'; then
    round_trips=$((round_trips + 100))
    printf '%s\n' "$pid" >>"$seen_pids"
  else
    nonzero_exits=$((nonzero_exits + 1))
    if [ "$status" -eq 124 ]; then timeouts=$((timeouts + 1)); fi
    if [ "$status" -ge 128 ]; then crashes=$((crashes + 1)); fi
    if [ "$status" -ne 124 ] && [ "$status" -lt 128 ]; then corruption_failures=$((corruption_failures + 1)); fi
  fi
  printf 'launch=%s pid=%s process_wall_ms=%s smoke_ms=%s exit=%s round_trips=%s\n' \
    "$launch" "${pid:-missing}" "$duration_ms" "${smoke_ms:-missing}" "$status" "$round_trips" >>"$output"
  launches=$launch
done

duration=$(( $(date +%s) - start ))
printf 'summary launches=%s distinct_pids=%s round_trips=%s crashes=%s nonzero_exits=%s timeouts=%s corruption_failures=%s wall_clock_seconds=%s result=' \
  "$launches" "$(wc -l <"$seen_pids" | tr -d ' ')" "$round_trips" "$crashes" "$nonzero_exits" "$timeouts" \
  "$corruption_failures" "$duration" | tee -a "$output"
if [ "$launches" -eq 100 ] && [ "$round_trips" -eq 10000 ] && [ "$nonzero_exits" -eq 0 ]; then
  printf 'PASS\n' | tee -a "$output"
else
  printf 'FAIL\n' | tee -a "$output"
  exit 1
fi
