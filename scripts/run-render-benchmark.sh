#!/bin/sh
set -eu

output=${1:-artifacts/r4/render-benchmark.txt}
mkdir -p "$(dirname "$output")"
swift build -c release --product RenderBenchmark >/dev/null
printf 'revision=%s model=%s chip=%s memory_bytes=%s os=%s build=%s arch=%s swift=%s\n' \
  "$(git rev-parse HEAD)" "$(sysctl -n hw.model)" "$(sysctl -n machdep.cpu.brand_string)" \
  "$(sysctl -n hw.memsize)" "$(sw_vers -productVersion)" "$(sw_vers -buildVersion)" "$(uname -m)" \
  "$(swift --version 2>&1 | head -1)" >"$output"
.build/release/RenderBenchmark | tee -a "$output"
