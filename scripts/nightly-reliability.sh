#!/bin/sh
set -eu
swift build -c release
i=0
while [ "$i" -lt 100 ]; do
  .build/release/VectorFoundry --smoke >/dev/null
  i=$((i+1))
done
swift test -c release
swift run -c release RenderBenchmark | tee nightly-benchmark.txt
