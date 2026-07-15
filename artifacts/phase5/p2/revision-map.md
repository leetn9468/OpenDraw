# Phase 5 delta history P2 evidence map

Final producing build-input revision:
`db19297de665daedad53bc2c23580e708d859fce`.

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

All artifacts above were regenerated after the final baseline-only commit on
the exact producing revision. Empty format, dependency, and clean-room files
mean the respective no-diagnostic commands exited zero.

Implementation lineage:

- `7e3c8e7d2f138797c1c5ad15ed6022ce06c5d759` — structural commands,
  approved-byte store, real history/checkpoint pins, VERIFY-024 fixtures, mixed
  corpus, structural BENCH-5 path.
- `3679dfa960c82934ae26fa74653acbaf8f948c2d` — read-only structural positional
  preflights remove the duplicate sibling-array copy; benchmark wrapper now
  propagates the benchmark process status instead of allowing `tee` to mask it.
- `db19297de665daedad53bc2c23580e708d859fce` — retains the optimized
  owner-reference BENCH-5 baseline and is the final build input proved here.

The pre-correction final-battery attempt observed BENCH-5b p95 `1.139 ms` and
was rejected against the unchanged `1.0 ms` target. It is not retained as pass
evidence. Three corrective validation runs were `0.876`, `0.846`, and `0.851`
ms; the source-revision baseline run was `0.881 ms`; the final retained run is
`0.885 ms`.
