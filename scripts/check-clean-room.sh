#!/bin/sh
set -eu

fail=0
restricted_name='AI10'".c"
restricted_location='Desktop/'"AI10"

if git ls-files -z | tr '\0' '\n' | rg -n "(^|/)${restricted_name}$"; then
  echo "Restricted research artifact is tracked" >&2
  fail=1
fi

if rg -n "${restricted_name}|${restricted_location}" \
  Sources Tests resources Package.swift 2>/dev/null; then
  echo "Restricted research artifact is referenced by build inputs" >&2
  fail=1
fi

exit "$fail"
