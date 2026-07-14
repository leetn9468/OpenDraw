# R4 retained-artifact revision map

| Artifact | Producing revision | Retaining evidence/state commit |
|---|---|---|
| `debug-build.txt`, `debug-tests.txt` | `f6ec81a` | `4f156b9` |
| `release-build.txt`, `release-tests.txt` | `f6ec81a` | `4f156b9` |
| `asan-tests.txt` | `f6ec81a` | `4f156b9` |
| `coverage-tests.txt`, `coverage-summary.txt` | `f6ec81a` | `4f156b9` (battery evidence set; unchanged summary blob originated at `f44b7e4`) |
| `format.txt` | `f6ec81a` | `4f156b9` battery evidence set |
| `module-dependencies.txt`, `clean-room.txt` | `b6cee43` | `d1edd2f` rerun attestation; output blobs were unchanged |
| `macos15-deployment-build.txt`, `symbol-graph.txt` | `f6ec81a` | `4f156b9` |
| `adversarial-tests.txt` | `f6ec81a` | `4f156b9` |
| `golden-test.txt` | `f6ec81a` | `4f156b9` |
| `ui-accessibility-tests.txt` | `f6ec81a` | `4f156b9` |
| `release-integrity.txt` | `f6ec81a` | `4f156b9` |
| `macos15-startup-p95.txt`, `startup-p95.txt` | `f6ec81a` | `4f156b9` |
| `peak-memory.txt`, `peak-memory-failure-fixture.txt` | `b6cee43` | `d1edd2f` |
| `render-benchmark.txt`, `benchmark-comparison.txt`, `benchmark-gate-fixtures.txt` | `b6cee43` | `d1edd2f` rerun evidence; fixture blob remained unchanged |
| `a6-test-existence.txt`, `a6-filtered-tests.txt` | `f6ec81a` | `4f156b9` |
| `audit-005-006-test-existence.txt`, `audit-005-006-filtered-tests.txt` | `f6ec81a` | `4f156b9` |
| `macos15-reliability-100x100.txt` | `f6ec81a` | `4f156b9` |
| `reliability-100x100.txt` | `b6cee43` | `d1edd2f` |
| `environment.txt`, `revision-scope-proof.txt` | `f6ec81a` | `4f156b9` |
| `hosted/ci-1-run.json`, `hosted/ci-1-jobs.json`, `hosted/ci-1-*-annotations.json`, `hosted/ci-1-job-*.log` | Hosted run `29315797697` at `834526c` | `d1edd2f` |

`f6ec81a` is the final build-input revision for the macOS 15 platform-floor
change. The complete local battery was rerun at this exact revision. Evidence
commits `4f156b9` and `834526c` contain no build-input change.

`b6cee43` changes only hosted-workflow configuration, documentation, and shared
shell portability (`rg` to POSIX `grep`) without changing expressions or gate
semantics. The affected dependency, clean-room, benchmark/ratio/fixture,
peak-memory/failure-fixture, and 100×100 reliability gates were rerun at that
exact revision. Unaffected complete-battery artifacts remain mapped to
`f6ec81a`.
