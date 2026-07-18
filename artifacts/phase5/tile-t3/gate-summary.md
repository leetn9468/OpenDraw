# Tile caching T3 local gate summary

Gate input revision: `3d17a17182711c8bc754f6df9a877b53ae32d7d7`
Production build-input revision: `a7c5b9f18781f6f94180c4e4476bef7d3a640983`

| Gate | Result | Evidence |
|---|---|---|
| Format | PASS | `format.txt` |
| Debug/release/macOS 15 builds | PASS | `debug-build.txt`, `release-build.txt`, `macos15-deployment-build.txt` |
| Debug tests | PASS — 138/138 | `debug-tests.txt`, `test-counts.txt` |
| Release tests | PASS — 138/138 | `release-tests.txt`, `test-counts.txt` |
| ASan | PASS — 136+1+1=138 | `asan-tests.txt` |
| Coverage | PASS — 90.69% ≥55% | `coverage-tests.txt`, `coverage-summary.txt` |
| Dependency/clean-room/symbol graph | PASS | `module-dependencies.txt`, `clean-room.txt`, `symbol-graph.txt` |
| Adversarial/golden/UI journey | PASS — 4/4 | `adversarial-golden-ui-journey.txt` |
| Release assembly/signature/arm64 | PASS | `release-integrity.txt` |
| BENCH-1/2/2b/3/5/6 absolute targets | PASS | `render-benchmark.txt` |
| Local ratio gate and boundary/failure fixtures | PASS | `benchmark-comparison.txt`, `benchmark-ratio-fixtures.txt` |
| BENCH-5b/BENCH-6 enforcement fixtures | PASS | `benchmark-enforcement-fixtures.txt`, `bench6-gate-fixture.txt` |
| Peak memory settle/export | PASS | `peak-memory.txt` |
| Peak memory forced failure | PASS | `peak-memory-failure-fixture.txt` |
| Full-app startup with forced tile draw | PASS — p95 180.135 ms | `startup-p95.txt` |
| Reliability with per-process cold/warm tiles | PASS — 100/100 and 10,000/10,000 | `reliability-100x100.txt` |
| Hosted eight-job dispatch | PASS — 8/8 | CI #28 on exact `0395605`; `hosted-run-28-closure.md` |

Exact settle peak: 461,799,424 B. Exact headroom below 524,288,000 B:
62,488,576 B. The forced fixture reached 1,037,467,648 B and was rejected.
