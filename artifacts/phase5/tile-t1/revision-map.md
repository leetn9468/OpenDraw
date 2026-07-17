# Phase 5 tile-render caching T1 evidence map

Producing build-input revision:
`fba637212174fd4c9fe6a047b7a340077e06a22d`.

| Gate | Flag | Artifact |
|---|---|---|
| Environment and exact revision | — | `environment.txt` |
| Flag, production-caller, benchmark, and changed-path isolation | OFF | `flag-isolation.txt` |
| Test-count reconciliation | OFF/ON | `test-reconciliation.txt` |
| Format | — | `format.txt` |
| Debug/release builds | — | `debug-build.txt`, `release-build.txt` |
| macOS 15 deployment build | — | `macos15-deployment-build.txt` |
| Debug tests | OFF/ON | `debug-tests-flag-off.txt`, `debug-tests-flag-on.txt` |
| Raw runtime suite-gating proof | OFF | `debug-tests-flag-off-runtime-gating.txt` |
| Release tests | OFF/ON | `release-tests-flag-off.txt`, `release-tests-flag-on.txt` |
| AddressSanitizer | OFF/ON | `asan-tests-flag-off.txt`, `asan-tests-flag-on.txt` |
| Retained contended ASan attempt | ON | `asan-tests-flag-on-contended-failure.txt` |
| Coverage | ON | `coverage-tests-flag-on.txt`, `coverage-summary.txt` |
| Dependency/clean-room/symbol graph | — | `module-dependencies.txt`, `clean-room.txt`, `symbol-graph.txt` |
| Adversarial/golden/UI-accessibility | OFF | `adversarial-tests.txt`, `golden-tests.txt`, `ui-accessibility-tests.txt` |
| Release assembly/signature | OFF | `release-integrity.txt` |
| Unchanged BENCH-1/2/2b/3/5 and local ratios | OFF | `render-benchmark.txt`, `benchmark-comparison.txt` |
| Benchmark ratio/enforcement falsifiability | OFF | `benchmark-gate-fixtures.txt`, `bench5b-enforcement-fixtures.txt` |
| Unchanged peak-memory scenario and failure fixture | OFF | `peak-memory.txt`, `peak-memory-failure-fixture.txt` |
| Full-app startup | OFF | `startup-p95.txt` |
| Reliability 100×100 | OFF | `reliability-100x100.txt` |

All qualifying artifacts were regenerated from the producing build-input
revision. Empty format, dependency, and clean-room files mean the respective
no-diagnostic commands exited zero.

The first flag-on ASan main-suite attempt is retained verbatim and predates the
final test-only exact-mapping amendment. It failed only
the unchanged 15-second `swiftGeometryBenchmark` wall-clock guard at
16.625875667 seconds while the new image-comparison tests ran concurrently.
The qualifying run used the repository's established isolated wall-clock
method: 134 non-wall-clock tests, one isolated deterministic corpus test, and
one isolated geometry benchmark. It passed with the geometry benchmark at
0.865 seconds. No deadline, threshold, source, or test was changed.

Implementation lineage:

- `6933d36488c2e6a06bb1f05d068b62d94bad62e9` — T1 grid, mapping, cache,
  composite entry point, startup flag read, and nine permanent tests.
- `fba637212174fd4c9fe6a047b7a340077e06a22d` — pins the backing-scale-two
  VERIFY-029 mapping and exact tile sets for all five conservative-ink cases;
  this is the final T1 build input proved by every qualifying artifact.

No frozen VERIFY value changed. No production caller uses the tile composite
entry point. No invalidation, benchmark, BENCH-2b, or peak-memory-extension
code changed in T1.
