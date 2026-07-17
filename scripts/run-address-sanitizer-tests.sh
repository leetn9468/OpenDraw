#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

scripts/run-tests-with-isolated-deadlines.sh --sanitize=address
