# Phase 5 delta history P4 evidence map

Final producing build-input revision:
`17f45ab2b74f732fe6830ef18ebbaa37e4c1b1fe`.

| Gate | Artifact |
|---|---|
| Environment and exact revision | `environment.txt` |
| Runtime-gate zero-reference proof | `flag-removal-grep.txt` |
| Retired snapshot/scene command zero-reference proof | `retired-path-grep.txt` |
| Test-count reconciliation | `test-reconciliation.txt` |
| Format | `format.txt` |
| Debug/release builds | `debug-build.txt`, `release-build.txt` |
| macOS 15 deployment build | `macos15-deployment-build.txt` |
| Debug/release tests | `debug-tests.txt`, `release-tests.txt` |
| AddressSanitizer | `asan-tests.txt` |
| Coverage | `coverage-tests.txt`, `coverage-summary.txt` |
| Dependency/clean-room/symbol graph | `module-dependencies.txt`, `clean-room.txt`, `symbol-graph.txt` |
| Adversarial/golden/UI-accessibility | `adversarial-tests.txt`, `golden-tests.txt`, `ui-accessibility-tests.txt` |
| Release assembly/signature | `release-integrity.txt` |
| BENCH-1–5 and local ratios | `render-benchmark.txt`, `benchmark-comparison.txt` |
| Ratio falsifiability | `benchmark-gate-fixtures.txt` |
| P-FLOOR/checkpoint peak memory | `peak-memory.txt`, `peak-memory-failure-fixture.txt` |
| Full-app startup | `startup-p95.txt` |
| Reliability 100×100 | `reliability-100x100.txt` |

All artifacts above were regenerated on the exact producing revision. Empty
format, dependency, and clean-room files mean the respective no-diagnostic
commands exited zero.

Implementation lineage:

- `0157b2b8ce7346ebf315d82431f886141f9d012f` — delta-only application
  wiring, feature-gate deletion, snapshot undo retirement, multi-selection
  gesture coalescing, memory-pressure wiring, test migration, row-by-row
  supersessions, ADR/state/queue updates.
- `17f45ab2b74f732fe6830ef18ebbaa37e4c1b1fe` — removes the final runtime
  flag wording from benchmark output and the unused AppKit local parameter;
  this is the final P4 build input proved by every artifact in this directory.
