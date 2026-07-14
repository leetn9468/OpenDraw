# R4 retained-artifact revision map

| Artifact | Producing revision |
|---|---|
| `debug-build.txt`, `debug-tests.txt` | `f6ec81a` |
| `release-build.txt`, `release-tests.txt` | `f6ec81a` |
| `asan-tests.txt` | `f6ec81a` |
| `coverage-tests.txt`, `coverage-summary.txt` | `f6ec81a` |
| `format.txt` | `f6ec81a` |
| `module-dependencies.txt`, `clean-room.txt` | `b6cee43` |
| `macos15-deployment-build.txt`, `symbol-graph.txt` | `f6ec81a` |
| `adversarial-tests.txt` | `f6ec81a` |
| `golden-test.txt` | `f6ec81a` |
| `ui-accessibility-tests.txt` | `f6ec81a` |
| `release-integrity.txt` | `f6ec81a` |
| `macos15-startup-p95.txt`, `startup-p95.txt` | `f6ec81a` |
| `peak-memory.txt`, `peak-memory-failure-fixture.txt` | `b6cee43` |
| `render-benchmark.txt`, `benchmark-comparison.txt`, `benchmark-gate-fixtures.txt` | `b6cee43` |
| `a6-test-existence.txt`, `a6-filtered-tests.txt` | `f6ec81a` |
| `audit-005-006-test-existence.txt`, `audit-005-006-filtered-tests.txt` | `f6ec81a` |
| `macos15-reliability-100x100.txt` | `f6ec81a` |
| `reliability-100x100.txt` | `b6cee43` |
| `environment.txt`, `revision-scope-proof.txt` | `f6ec81a` |
| `hosted/ci-1-run.json`, `hosted/ci-1-jobs.json`, `hosted/ci-1-*-annotations.json`, `hosted/ci-1-job-*.log` | Hosted run `29315797697` at `834526c`; retrieved during `b6cee43` triage |

`f6ec81a` is the final build-input revision for the macOS 15 platform-floor
change. The complete local battery was rerun at this exact revision. Evidence
commits `4f156b9` and `834526c` contain no build-input change.

`b6cee43` changes only hosted-workflow configuration, documentation, and shared
shell portability (`rg` to POSIX `grep`) without changing expressions or gate
semantics. The affected dependency, clean-room, benchmark/ratio/fixture,
peak-memory/failure-fixture, and 100×100 reliability gates were rerun at that
exact revision. Unaffected complete-battery artifacts remain mapped to
`f6ec81a`.
