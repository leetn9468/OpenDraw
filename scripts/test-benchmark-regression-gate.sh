#!/bin/sh
set -eu

directory=$(mktemp -d)
trap 'rm -rf "$directory"' EXIT HUP INT TERM
scripts/check-benchmark-regression.sh \
  benchmarks/owner-reference-macos15-arm64-baseline.tsv scripts/fixtures/benchmark-regression-pass.txt "$directory/pass.txt"
scripts/check-benchmark-regression.sh \
  benchmarks/owner-reference-macos15-arm64-baseline.tsv scripts/fixtures/benchmark-regression-boundary.txt "$directory/boundary.txt"
if scripts/check-benchmark-regression.sh \
  benchmarks/owner-reference-macos15-arm64-baseline.tsv scripts/fixtures/benchmark-regression-fail.txt "$directory/fail.txt"; then
  echo "Expected regression fixture to fail" >&2
  exit 1
fi
rg -q 'bench1_p95 .*result=FAIL' "$directory/fail.txt"
