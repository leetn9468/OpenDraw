# Phase 5 delta history P1 evidence map

Producing build-input revision:
`e38200bc49b68f025c19c8a22fef4a9ea5969222`.

The core delta-history/BENCH-5 implementation landed at
`7ec93fdb16356ccbc5b56c0f593353dcba254472`. The producing revision adds the
required P-FLOOR plus nine-checkpoint peak-memory envelope. Every artifact in
this directory was regenerated after that change on the producing revision.

| Gate | Artifact |
|---|---|
| Environment | `environment.txt` |
| Format | `format.txt` |
| Debug/release builds | `debug-build.txt`, `release-build.txt` |
| macOS 15 deployment build | `macos15-deployment-build.txt` |
| Debug tests, flag OFF/ON | `debug-tests-flag-off.txt`, `debug-tests-flag-on.txt` |
| Release tests, flag OFF/ON | `release-tests-flag-off.txt`, `release-tests-flag-on.txt` |
| ASan, both flag states | `asan-tests-both-flags.txt` |
| Coverage | `coverage-tests-flag-on.txt`, `coverage-summary.txt` |
| Dependency/clean-room/symbol graph | `module-dependencies.txt`, `clean-room.txt`, `symbol-graph.txt` |
| Adversarial/golden/UI | `adversarial-tests.txt`, `golden-tests.txt`, `ui-accessibility-tests.txt` |
| Release assembly/signature | `release-integrity.txt` |
| BENCH-1–5 and local ratios | `render-benchmark.txt`, `benchmark-comparison.txt` |
| Ratio falsifiability | `benchmark-gate-fixtures.txt` |
| P-FLOOR/checkpoint peak memory | `peak-memory.txt`, `peak-memory-failure-fixture.txt` |
| Full-app startup | `startup-p95.txt` |
| Reliability 100×100 | `reliability-100x100.txt` |

Zero-length format, dependency, and clean-room artifacts are successful
no-diagnostic outputs; their commands exited zero before the remaining battery
continued.
