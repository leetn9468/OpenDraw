#!/bin/sh
set -eu

output=${1:-artifacts/r4/peak-memory-failure-fixture.txt}
extra_bytes=$((550 * 1024 * 1024))
if R4_MEMORY_EXTRA_BYTES="$extra_bytes" scripts/check-peak-memory.sh "$output"; then
  echo "Expected forced over-allocation scenario to fail" >&2
  exit 1
fi
grep -Eq 'settle .*result=FAIL' "$output"
