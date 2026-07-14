# R4 retained-artifact revision map

## Current retained artifacts

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
| `hosted/ci-6-*` | Hosted run `29345329291` at `2cfa845` | `bd4524f` |
| `asan-tests-run6-fix.txt` | `5d2ea50` | `bd4524f` |
| `hosted/ci-8-*` | Qualifying dispatched run `29347892897` at `94fb0f0` | `88c3d58` |
| `benchmarks/hosted-macos15-arm64-baseline.tsv` | Run `29347892897` artifact 8316881233 at `94fb0f0` | `88c3d58` |
| `a7-human-spot-check.md` | TN LEE direct inspection, 2026-07-15 00:38 UTC+08:00 | `6dea372` |

`f6ec81a` remains the macOS 15 platform-floor revision. The complete-battery
revision is `ce3b4b3`; evidence commit
`8da5ee8` retains its complete local battery and the CI #4 triage records.

`ce3b4b3` fixes the stale file-descriptor cleanup race and makes the existing
550 MiB forced-memory allocation incompressible. It changes no threshold,
target, tolerance, ceiling, benchmark, retry policy, workflow semantic, or
VERIFY value. The complete local battery was rerun at that exact revision.

`59eec99` completed the CI #5 hosted-benchmark correction. Its build-input chain
from `b57293c` changes only `.github/workflows/ci.yml`: hosted benchmark
selection now bootstraps from a hosted-sourced candidate when no committed
hosted baseline exists and invokes the unchanged ratio checker once that
baseline is present; incomplete hosted
baseline files fail closed before comparison. Per the CI #5
directive this hosted-only change requires a new hosted run, not a local
battery rerun. Evidence commit `e01ac1b` retains CI #5 and both workflow-mode
dry-run proofs.

`5d2ea50` corrects the CI #6 ASan
test-harness defect by making `make sanitize` and hosted CI call the same
two-invocation script: 89 ASan tests, then the unchanged deadline-sensitive
corpus test in isolation. The affected local ASan gate passed 89/89 plus 1/1
at that exact revision; `bd4524f` retains the failing hosted log and passing
corrective log. The complete remainder of the local battery remains mapped to
`ce3b4b3`/`8da5ee8` because no other gate input changed.

`88c3d58` is the final R4 build-input/evidence revision. It adds the
hosted-sourced baseline produced by qualifying run `29347892897`; no
`Sources/`, `Tests/`, script, package or workflow file changes. The unchanged
ratio checker accepts the same-run bootstrap values at 1.000000, the exact
1.25 fixture passes, and the 1.314801 fixture fails. At R4 closure, later hosted
runs were configured for blocking `ENFORCE` mode. Post-tag run
<https://github.com/leetn9468/OpenDraw/actions/runs/29350963872> demonstrated
2.3–2.8× shared-runner variance; the explicit 2026-07-15 Phase 5 operations
decision supersedes hosted enforcement without changing the local checker,
owner-reference baseline, fixtures, or any closed remediation row.

Acceptance-evidence revision `6dea372fc90d7474dc1f5db0085dd03bfdc046ea`
records the mandatory named-human A7 inspection. Annotated tag
`pre-phase5-remediation` resolves exactly to that revision. The later state
recording commit is documentation-only and does not change the proven target.

## Post-platform build-input rerun accounting

| Build-input change | Affected gate rerun/evaluation | Retaining commit |
|---|---|---|
| `b6cee43` portable CI/scripts | dependency, clean-room, benchmark/ratio fixtures, peak-memory/failure fixture, reliability | `d1edd2f` |
| `ce3b4b3` production/test + memory fixture | complete local battery, focused regression and release stress | `8da5ee8` |
| `b57293c`/`59eec99` hosted baseline workflow | actual BOOTSTRAP and failing ENFORCE block proofs; five-metric fail-closed proof | `e01ac1b`/`2cfa845` |
| `5d2ea50` shared ASan runner | 89/89 ASan plus isolated 1/1 deadline test | `bd4524f` |
| `88c3d58` hosted baseline | five unique metrics, 90-day provenance, same-run 1.000000 validation, exact-1.25 pass and 1.314801 fail | `88c3d58` |

## ADR-011 macOS 15 rerun accounting

The owner-directed macOS 15 platform-floor battery was executed at build-input
revision `f6ec81a`. Evidence/state commit `4f156b9` introduced the ADR-011
report and retained the battery. Identical zero-output or summary artifacts
kept their earlier blob commits; those commits are named rather than falsely
claiming that `4f156b9` changed an identical file. Later reruns superseded the
live artifact contents as mapped above.

| ADR-011 artifact group | Producing revision | Artifact blob commit | ADR-011 evidence/state commit |
|---|---|---|---|
| `debug-build.txt`, `debug-tests.txt` | `f6ec81a` | `4f156b9` | `4f156b9` |
| `release-build.txt`, `release-tests.txt` | `f6ec81a` | `4f156b9` | `4f156b9` |
| `asan-tests.txt` | `f6ec81a` | `4f156b9` | `4f156b9` |
| `coverage-tests.txt` | `f6ec81a` | `4f156b9` | `4f156b9` |
| `coverage-summary.txt` (identical summary) | `f6ec81a` | `f44b7e4` | `4f156b9` |
| `format.txt`, `module-dependencies.txt`, `clean-room.txt` (identical zero-output passes) | `f6ec81a` | `7cfbf00` | `4f156b9` |
| `macos15-deployment-build.txt`, `symbol-graph.txt` | `f6ec81a` | `4f156b9` | `4f156b9` |
| `adversarial-tests.txt`, `golden-test.txt`, `ui-accessibility-tests.txt` | `f6ec81a` | `4f156b9` | `4f156b9` |
| `release-integrity.txt` | `f6ec81a` | `4f156b9` | `4f156b9` |
| `macos15-startup-p95.txt`, `startup-p95.txt` | `f6ec81a` | `4f156b9` | `4f156b9` |
| `peak-memory.txt`, `peak-memory-failure-fixture.txt` | `f6ec81a` | `4f156b9` | `4f156b9` |
| `render-benchmark.txt`, `benchmark-comparison.txt` | `f6ec81a` | `4f156b9` | `4f156b9` |
| `benchmark-gate-fixtures.txt` (identical fixture output) | `f6ec81a` | `7cfbf00` | `4f156b9` |
| `a6-test-existence.txt`, `a6-filtered-tests.txt` | `f6ec81a` | `4f156b9` | `4f156b9` |
| `audit-005-006-test-existence.txt`, `audit-005-006-filtered-tests.txt` | `f6ec81a` | `4f156b9` | `4f156b9` |
| `macos15-reliability-100x100.txt`, `reliability-100x100.txt` | `f6ec81a` | `4f156b9` | `4f156b9` |
| `environment.txt`, `revision-scope-proof.txt` | `f6ec81a` | `4f156b9` | `4f156b9` |

`docs/reviews/ADR-011-macos15-platform-rerun-report.md` was introduced by
evidence/state commit `4f156b9` and names producing revision `f6ec81a`.
