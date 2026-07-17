#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

# Standing policy: every wall-clock-deadline test is excluded from the main
# population and executed sequentially after it. Add future deadline tests to
# this list when they are introduced; full-suite callers must use this script.
corpus_deadline_test=deterministicNativeAndSVGMutationCorpusMeetsDeadline
geometry_deadline_test=swiftGeometryBenchmark

if [ "${1:-}" = "--coverage-main" ]; then
  shift
  swift test --enable-code-coverage "$@" \
    --skip "$corpus_deadline_test" --skip "$geometry_deadline_test"
  # Preserve the main population's coverage profile. The isolated invocations
  # use its already-built binary without replacing codecov/default.profdata.
  swift test --skip-build "$@" --filter "$corpus_deadline_test"
  swift test --skip-build "$@" --filter "$geometry_deadline_test"
  exit 0
fi

swift test "$@" --skip "$corpus_deadline_test" --skip "$geometry_deadline_test"
swift test "$@" --skip-build --filter "$corpus_deadline_test"
swift test "$@" --skip-build --filter "$geometry_deadline_test"
