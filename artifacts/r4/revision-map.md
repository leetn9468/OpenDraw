# R4 retained-artifact revision map

| Artifact | Producing revision | Retaining evidence/state commit |
|---|---|---|
| `debug-build.txt`, `debug-tests.txt` | `ce3b4b3` | `8da5ee8` |
| `release-build.txt`, `release-tests.txt` | `ce3b4b3` | `8da5ee8` |
| `asan-tests.txt` | `ce3b4b3` | `8da5ee8` |
| `coverage-tests.txt`, `coverage-summary.txt` | `ce3b4b3` | `8da5ee8` |
| `format.txt`, `module-dependencies.txt`, `clean-room.txt` | `ce3b4b3` | `8da5ee8` complete-battery attestation; zero-output blobs were unchanged |
| `macos15-deployment-build.txt`, `symbol-graph.txt` | `ce3b4b3` | `8da5ee8` |
| `adversarial-tests.txt` | `ce3b4b3` | `8da5ee8` |
| `golden-test.txt` | `ce3b4b3` | `8da5ee8` |
| `ui-accessibility-tests.txt` | `ce3b4b3` | `8da5ee8` |
| `release-integrity.txt` | `ce3b4b3` | `8da5ee8` |
| `macos15-startup-p95.txt`, `startup-p95.txt` | `ce3b4b3` | `8da5ee8` |
| `peak-memory.txt`, `peak-memory-failure-fixture.txt`, `memory-fixture-stress.txt` | `ce3b4b3` | `8da5ee8` |
| `render-benchmark.txt`, `benchmark-comparison.txt`, `benchmark-gate-fixtures.txt` | `ce3b4b3` | `8da5ee8`; fixture blob remained unchanged |
| `a6-test-existence.txt`, `a6-filtered-tests.txt` | `ce3b4b3` | `8da5ee8` |
| `audit-005-006-test-existence.txt`, `audit-005-006-filtered-tests.txt` | `ce3b4b3` | `8da5ee8` |
| `macos15-reliability-100x100.txt`, `reliability-100x100.txt` | `ce3b4b3` | `8da5ee8` |
| `descriptor-race-regression.txt` | `ce3b4b3` | `8da5ee8` |
| `environment.txt`, `revision-scope-proof.txt` | `ce3b4b3` | `8da5ee8` |
| `hosted/ci-1-run.json`, `hosted/ci-1-jobs.json`, `hosted/ci-1-*-annotations.json`, `hosted/ci-1-job-*.log` | Hosted run `29315797697` at `834526c` | `d1edd2f` |
| `hosted/ci-4-*` | Hosted run `29327190429` at `8c157cb` | `8da5ee8` |
| `hosted/ci-5-*` | Hosted run `29340697610` at `9471562`; workflow-mode proof at `b57293c`/`59eec99` | `e01ac1b` plus final state evidence commit |

`f6ec81a` remains the macOS 15 platform-floor revision. The current final
build-input and complete-battery revision is `ce3b4b3`; evidence commit
`8da5ee8` retains its complete local battery and the CI #4 triage records.

`ce3b4b3` fixes the stale file-descriptor cleanup race and makes the existing
550 MiB forced-memory allocation incompressible. It changes no threshold,
target, tolerance, ceiling, benchmark, retry policy, workflow semantic, or
VERIFY value. The complete local battery was rerun at that exact revision.

`59eec99` is the current final build-input revision. Its build-input chain from
`b57293c` changes only `.github/workflows/ci.yml`: hosted benchmark selection
now bootstraps from a hosted-sourced candidate when no committed hosted baseline exists and invokes
the unchanged ratio checker once that baseline is present; incomplete hosted
baseline files fail closed before comparison. Per the CI #5
directive this hosted-only change requires a new hosted run, not a local
battery rerun. Evidence commit `e01ac1b` retains CI #5 and both workflow-mode
dry-run proofs.
