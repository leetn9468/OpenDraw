# OpenDraw remediation project state

Updated: 2026-07-13

The owner-directed tracker was absent from repository history when the R4
rejection was received. This file restores the twelve hard closure rows from
that directive. A row is closed only by committed, directly named evidence.

## Acceptance checkpoints

| Acceptance | State | Evidence / blocker |
|---|---|---|
| A6 — R3/R3-B checkpoint package | `CLOSED` | `docs/remediation/A6-R3-checkpoint.md`; implementation/gate revision `6de4bce` |
| A7 — R4 CI/reliability acceptance | `NOT ACCEPTED` | BLOCK-002 and BLOCK-006 remain open |
| A8 — Phase 5 entry | `BLOCKED` | No tag may be created while any blocker is open |

## Hard blockers

| ID | Requirement | State | Direct evidence / exact remaining requirement |
|---|---|---|---|
| BLOCK-001 | Restore the exact 14-item A6 closure package | `CLOSED` | `docs/remediation/A6-R3-checkpoint.md` maps every owner-defined group to symbols, tests and commits |
| BLOCK-002 | 100-run smoke on real macOS 13 Apple Silicon | `OPEN` | No qualifying macOS 13 machine was available. Run `scripts/nightly-reliability.sh <artifact>` on macOS 13.x arm64 and record model/SoC/RAM/toolchain/revision. Current macOS 15 evidence is not substituted. |
| BLOCK-003 | Enforced peak-memory assertions | `CLOSED` | `scripts/check-peak-memory.sh`; PRD ceilings 500 MiB settle/650 MiB export; artifact `artifacts/r4/peak-memory.txt` |
| BLOCK-004 | Enforced startup p95 | `CLOSED` | `scripts/check-startup-p95.sh`; PRD target 2,000 ms p95 over 20 clean processes; artifact `artifacts/r4/startup-p95.txt` |
| BLOCK-005 | 100 clean launches and 10,000 aggregate native round trips | `CLOSED` | `scripts/nightly-reliability.sh`; 100/100 launches, 10,000/10,000 round trips, zero crashes/nonzero exits/timeouts/corruption; artifact `artifacts/r4/reliability-100x100.txt` |
| BLOCK-006 | Hosted-CI ratio gate with hosted baseline/run proof | `OPEN` | Enforcement and failing fixture exist (`scripts/check-benchmark-regression.sh`, `scripts/test-benchmark-regression-gate.sh`), but no remote is configured and no hosted CI run/baseline artifact exists. The committed baseline is explicitly owner-reference, not hosted proof. |
| BLOCK-007 | Fresh final-revision full verification battery | `CLOSED` | Initial full battery on `52c3295`; script-only correction at `f854389` followed by affected-gate reruns; test-only mutation logging at `6de4bce` followed by debug/release/ASan/coverage/adversarial reruns; `artifacts/r4/` |
| BLOCK-008 | Reproducibility metadata for corpus and benchmarks | `CLOSED` | `docs/phase-4/fuzz-results.md`, benchmark runner metadata, and retained `artifacts/r4/` logs |
| BLOCK-009 | Exact audit closure-matrix traceability | `CLOSED` | `docs/audits/findings-closure-matrix.md` names exact test files/functions and commits |
| BLOCK-010 | Correct and internally consistent R4 documents | `CLOSED` | Documentation closure commit containing this tracker and the corrected checkpoint/audit/policy files |
| BLOCK-011 | Exact revision accounting | `CLOSED` | Implementation/gate commits `52c3295`, `f854389`, `6de4bce`; test and targeted-rerun accounting in `docs/phase-4/R4-checkpoint.md` |
| BLOCK-012 | Annotated Phase 5 entry tag | `OPEN` | `pre-phase5-remediation` intentionally does not exist because BLOCK-002 and BLOCK-006 remain open |

## Tag state

`pre-phase5-remediation`: **ABSENT — REQUIRED WHILE A8 IS BLOCKED**.
