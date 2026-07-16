#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

# Keep the per-mutation 3-second and full-corpus 10-second wall-clock gates
# isolated from unrelated ASan tests. On shared runners, whole-suite scheduling
# starvation can otherwise consume those deadlines without parser work running.
deadline_test=deterministicNativeAndSVGMutationCorpusMeetsDeadline

swift test --sanitize=address --skip "$deadline_test"
swift test --sanitize=address --skip-build --filter "$deadline_test"
