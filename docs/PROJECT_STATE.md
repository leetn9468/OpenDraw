# OpenDraw remediation project state

Updated: 2026-07-13

The owner-directed tracker was absent from repository history when the R4
rejection was received. This file restores the twelve hard closure rows from
that directive. A row is closed only by committed, directly named evidence.

## Acceptance checkpoints

| Acceptance | State | Evidence / blocker |
|---|---|---|
| A6 — R3/R3-B checkpoint package | `CLOSED` | Exact 14-row table, zero-new-production-math declaration, grep proof and 19-test combined pass; final implementation/gate revision `2884a54` |
| A7 — R4 CI/reliability acceptance | `NOT ACCEPTED` | BLOCK-002 through BLOCK-006 include unresolved external/hosted proof components |
| A8 — Phase 5 entry | `BLOCKED` | No tag may be created while any blocker is open |

## Hard blockers

| ID | Requirement | State | Direct evidence / exact remaining requirement |
|---|---|---|---|
| BLOCK-001 | Restore the exact 14-item A6 closure package | `CLOSED` | `docs/remediation/A6-R3-checkpoint.md`; `a6-test-existence.txt`; `a6-filtered-tests.txt`; explicit test-side numeric-policy classification and zero-new-production-math declaration |
| BLOCK-002 | Codec reliability and full-app startup on real macOS 13 Apple Silicon | `OPEN` | No qualifying macOS 13 machine was available. In one session on the same macOS 13.x arm64 machine, retain both `artifacts/r4/macos13-reliability-100x100.txt` from `scripts/nightly-reliability.sh` and `artifacts/r4/macos13-startup-p95.txt` from `scripts/check-startup-p95.sh 20`; the startup p95 target remains 2,000 ms. Both artifacts must retain the environment header after identifier stripping. Current macOS 15 evidence is not substituted. |
| BLOCK-003 | Enforced peak-memory assertions | `OPEN — LOCAL PASS, HOSTED PENDING` | Corrected gate decodes ten embedded 5 MP images through `RasterResourceLoader` and `ApprovedImageCache`, renders approved images, and proves forced over-allocation failure. Local artifacts: `peak-memory.txt`, `peak-memory-failure-fixture.txt`. First hosted `startup-memory` job must pass. |
| BLOCK-004 | Enforced startup p95 | `OPEN — LOCAL PASS, HOSTED PENDING` | Local nearest-rank 20-process gate passes. First hosted `startup-memory` job must pass; static-initializer timing excludes exec/dyld/pre-main. |
| BLOCK-005 | 100 clean launches and 10,000 aggregate native round trips | `OPEN — LOCAL PASS, HOSTED PENDING` | Local sequential run records 100 distinct PIDs and per-process durations. First hosted scheduled `nightly-reliability` job must pass. |
| BLOCK-006 | Hosted-CI execution and ratio proof | `OPEN` | No remote/hosted run exists. The first hosted run must show `startup-memory`, `nightly-reliability`, `benchmark`, and `adversarial-golden` green, retain their artifacts/run URL, and bootstrap a clearly hosted baseline. This simultaneously closes hosted components of BLOCK-003/004/005. |
| BLOCK-007 | Fresh final-revision full verification battery | `CLOSED LOCALLY` | Complete 89-test/release/ASan/coverage and all local gates ran on `b01364b`; reliability-only script change `2884a54` was followed by the affected 100-process rerun; artifact mapping in `revision-map.md` |
| BLOCK-008 | Reproducibility metadata for corpus and benchmarks | `CLOSED` | `docs/phase-4/fuzz-results.md`, benchmark runner metadata, and retained `artifacts/r4/` logs |
| BLOCK-009 | Exact audit closure-matrix traceability | `CLOSED` | `docs/audits/findings-closure-matrix.md` names exact test files/functions and commits |
| BLOCK-010 | Correct and internally consistent R4 documents | `CLOSED` | Documentation closure commit containing this tracker and the corrected checkpoint/audit/policy files |
| BLOCK-011 | Exact revision accounting | `CLOSED` | `revision-map.md` and `revision-scope-proof.txt`; final gate commits `b01364b`, `2884a54`; `14de9b3` ancestry confirmed |
| BLOCK-012 | Annotated Phase 5 entry tag | `OPEN` | `pre-phase5-remediation` intentionally does not exist because BLOCK-002 and BLOCK-006 remain open |

## Tag state

`pre-phase5-remediation`: **ABSENT — REQUIRED WHILE A8 IS BLOCKED**.

## Frozen owner decisions

> **Owner decision (TN LEE, 2026-07-13): Option A is adopted.** BLOCK-002 now
> requires both the codec reliability run and the full-app startup run on real
> macOS 13.x Apple Silicon hardware. Option B, accepting codec-only smoke as
> sufficient macOS 13 runtime proof, was considered and rejected. BLOCK-002
> closes only when both artifacts are retained from the same session and
> machine. This decision may not be weakened without a further explicit owner
> decision under frozen rule 11.
