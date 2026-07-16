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

Hosted run 17 follow-up:

- `36e46319e88ba6ee68e9acf826548900122137ad` — evidence-only P4 revision
  executed by hosted push run 16 and dispatched run 17. Run 16 completed;
  run 17 exited 133 after redirected Swift stdout lost the BENCH lines.
  Preserved evidence: `hosted-run-16-push-benchmark.txt`,
  `hosted-run-16-comparison.txt`, `hosted-run-17-failure-log.txt`, and
  `hosted-run-17-partial-benchmark.txt`.
- `a364fd1d7352a63d46277417995364c8a31ad6d6` — benchmark-wrapper-only
  evidence-preservation input. Affected-gate artifacts:
  `hosted-triage-benchmark.txt`,
  `hosted-triage-benchmark-comparison.txt`,
  `hosted-triage-ratio-fixtures.txt`, and
  `hosted-triage-stress-trap.txt`. The stress fixture intentionally applies
  CPU contention to prove that an exit-133 BENCH-5b failure retains the last
  completed section and the exact observed/target values; it is not a
  performance qualification run.

The classification and operator rerun instructions are recorded in
`hosted-run-17-triage.md`.

Hosted BENCH-5b informational policy:

- `afc03ddf236a816627ea408064541bd34b4e5b2f` — owner-decision
  implementation input. `RenderBenchmark` defaults BENCH-5b enforcement ON,
  the hosted workflow alone selects OFF, and the new blocking fixture proves
  default BENCH-5b trapping, hosted-off BENCH-5b reporting, and unchanged
  BENCH-5a trapping.
- Affected-gate artifacts produced on that exact revision:
  `bench5b-policy-local-enforced.txt`,
  `bench5b-policy-local-comparison.txt`,
  `bench5b-policy-hosted-informational.txt`,
  `bench5b-policy-hosted-comparison-simulation.txt`,
  `bench5b-policy-ratio-fixtures.txt`, and
  `bench5b-policy-enforcement-fixtures.txt`.
- `hosted-bench5b-policy-report.md` records the gate table, scope proof, and
  the remaining operator push/manual-dispatch action.
