# Phase 5 delta history P3 evidence map

Final producing build-input revision:
`311ea023a63b0820c72fd1ba64e1ea5985ec4be6`.

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

All artifacts above were regenerated on the exact producing revision. Empty
format, dependency, and clean-room files mean the respective no-diagnostic
commands exited zero.

Implementation lineage:

- `18d5a2ab5fa33b4cac3911756598eb06f4b58388` — composite command atomicity,
  group/ungroup and compound composites, align composite, runtime anchor
  slices, structural segment slices, real delta gesture coalescing,
  VERIFY-025/026 permanent fixtures, mixed seeded corpus, and the extended
  BENCH-5 production mix.
- `311ea023a63b0820c72fd1ba64e1ea5985ec4be6` — strict repository formatting;
  this is the final P3 build input proved by every artifact in this directory.

The first pre-optimization composite/anchor BENCH-5b attempt observed `1.083
ms` p95 and was rejected against the unchanged `1.0 ms` target. The target was
not changed. Removing redundant whole-document validation from the composite
wrapper while retaining each child preflight produced the retained `0.818 ms`
p95 result. Direct-apply atomicity remains pinned by the forced-unwind fixture.
