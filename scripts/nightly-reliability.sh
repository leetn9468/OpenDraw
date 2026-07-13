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
start=$(date +%s)
launches=0
round_trips=0
crashes=0
nonzero_exits=0
timeouts=0
corruption_failures=0

while [ "$launches" -lt 100 ]; do
  launch=$((launches + 1))
  set +e
  line=$(perl -e '$SIG{ALRM}=sub{exit 124}; alarm shift; exec @ARGV' 30 .build/release/VectorFoundry --smoke 2>&1)
  status=$?
  set -e
  if [ "$status" -eq 0 ] && printf '%s' "$line" | rg -q '100 native round trips passed'; then
    round_trips=$((round_trips + 100))
  else
    nonzero_exits=$((nonzero_exits + 1))
    if [ "$status" -eq 124 ]; then timeouts=$((timeouts + 1)); fi
    if [ "$status" -ge 128 ]; then crashes=$((crashes + 1)); fi
    if [ "$status" -ne 124 ] && [ "$status" -lt 128 ]; then corruption_failures=$((corruption_failures + 1)); fi
  fi
  printf 'launch=%s exit=%s round_trips=%s\n' "$launch" "$status" "$round_trips" >>"$output"
  launches=$launch
done

duration=$(( $(date +%s) - start ))
printf 'summary launches=%s round_trips=%s crashes=%s nonzero_exits=%s timeouts=%s corruption_failures=%s duration_seconds=%s result=' \
  "$launches" "$round_trips" "$crashes" "$nonzero_exits" "$timeouts" "$corruption_failures" "$duration" | tee -a "$output"
if [ "$launches" -eq 100 ] && [ "$round_trips" -eq 10000 ] && [ "$nonzero_exits" -eq 0 ]; then
  printf 'PASS\n' | tee -a "$output"
else
  printf 'FAIL\n' | tee -a "$output"
  exit 1
fi
