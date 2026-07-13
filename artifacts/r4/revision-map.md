# R4 retained-artifact revision map

| Artifact | Producing revision |
|---|---|
| `debug-build.txt`, `debug-tests.txt` | `b01364b` |
| `release-build.txt`, `release-tests.txt` | `b01364b` |
| `asan-tests.txt` | `b01364b` |
| `coverage-tests.txt`, `coverage-summary.txt` | `b01364b` |
| `format.txt`, `module-dependencies.txt`, `clean-room.txt` | `b01364b` |
| `macos15-deployment-build.txt`, `symbol-graph.txt` | `b01364b` |
| `adversarial-tests.txt` | `b01364b` |
| `golden-test.txt` | `b01364b` |
| `ui-accessibility-tests.txt` | `b01364b` |
| `release-integrity.txt` | `b01364b` |
| `startup-p95.txt` | `b01364b` |
| `peak-memory.txt`, `peak-memory-failure-fixture.txt` | `b01364b` |
| `render-benchmark.txt`, `benchmark-comparison.txt`, `benchmark-gate-fixtures.txt` | `b01364b` |
| `a6-test-existence.txt`, `a6-filtered-tests.txt` | `b01364b` |
| `audit-005-006-test-existence.txt`, `audit-005-006-filtered-tests.txt` | `b01364b` |
| `reliability-100x100.txt` | `2884a54` |
| `environment.txt` | `2884a54` (metadata summary; performance files retain their own full hashes) |

`2884a54` changes only per-process duration capture in
`scripts/nightly-reliability.sh`; therefore only the reliability artifact was
invalidated and rerun after the complete `b01364b` battery.
