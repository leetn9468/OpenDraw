#!/bin/sh
set -eu
threshold="${1:-55}"
binary=$(find .build -path '*debug*' -name VectorFoundryPackageTests -type f | head -1)
profile=$(find .build -name default.profdata -type f | head -1)
test -n "$binary" -a -n "$profile"
percent=$(xcrun llvm-cov report "$binary" -instr-profile="$profile" -ignore-filename-regex='Tests|runner.swift' | tail -1 | awk '{gsub("%", "", $10); print $10}')
awk -v actual="$percent" -v required="$threshold" 'BEGIN { if (actual+0 < required+0) exit 1 }'
echo "Coverage ${percent}% (minimum ${threshold}%)"
