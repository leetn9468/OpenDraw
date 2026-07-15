#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

# Keep the per-mutation 3-second and full-corpus 10-second wall-clock gates
# isolated from unrelated ASan tests. On shared runners, whole-suite scheduling
# starvation can otherwise consume those deadlines without parser work running.
deadline_test=deterministicNativeAndSVGMutationCorpusMeetsDeadline

OPENDRAW_DELTA_HISTORY=0 swift test --sanitize=address --skip "$deadline_test"
OPENDRAW_DELTA_HISTORY=0 swift test --sanitize=address --skip-build --filter "$deadline_test"
OPENDRAW_DELTA_HISTORY=1 swift test --sanitize=address --skip "$deadline_test"
OPENDRAW_DELTA_HISTORY=1 swift test --sanitize=address --skip-build --filter "$deadline_test"
