# OpenDraw remediation project state

Updated: 2026-07-15

The owner-directed tracker was absent from repository history when the R4
rejection was received. This file restores the twelve hard closure rows from
that directive. A row is closed only by committed, directly named evidence.

## Acceptance checkpoints

| Acceptance | State | Evidence / blocker |
|---|---|---|
| A6 — R3/R3-B checkpoint package | `CLOSED` | Exact 14-row table, zero-new-production-math declaration, grep proof and 19-test combined pass; revalidated in the complete `f6ec81a` battery |
| A7 — R4 CI/reliability acceptance | `NOT ACCEPTED` | BLOCK-003/004/005 hosted components and BLOCK-006 remain unresolved |
| A8 — Phase 5 entry | `BLOCKED` | No tag may be created while any blocker is open |

## Hard blockers

| ID | Requirement | State | Direct evidence / exact remaining requirement |
|---|---|---|---|
| BLOCK-001 | Restore the exact 14-item A6 closure package | `CLOSED` | `docs/remediation/A6-R3-checkpoint.md`; `a6-test-existence.txt`; `a6-filtered-tests.txt`; explicit test-side numeric-policy classification and zero-new-production-math declaration |
| BLOCK-002 | Prove the real minimum-OS (macOS 15.x) Apple Silicon release smoke | `CLOSED` | On MacBookPro18,2 / Apple M1 Max / 64 GB / macOS 15.7.5 build 24G624 / Swift 6.1.2 at current build-input revision `ce3b4b3`: `macos15-reliability-100x100.txt` proves 100 distinct clean processes and 10,000 round trips with zero failures; `macos15-startup-p95.txt` proves 20 full-app launches with p95 143.960 ms ≤ 2,000 ms. Both retain environment metadata. |
| BLOCK-003 | Enforced peak-memory assertions | `OPEN — LOCAL PASS, HOSTED PENDING` | At `ce3b4b3`, the production gate passes at 214,564,864/224,821,248 bytes and the unchanged 550 MiB forced fixture reliably fails at 791,560,192 bytes. CI #4 exposed and `ce3b4b3` fixed the compressible-allocation fixture defect without changing the 500/650 MiB ceilings. Hosted closure requires `startup-memory` to pass as part of one final-revision run in which all eight workflow jobs are green. |
| BLOCK-004 | Enforced startup p95 | `OPEN — LOCAL PASS, HOSTED PENDING` | At `ce3b4b3`, the local nearest-rank 20-process gate passes with p95 143.960 ms. Hosted closure requires `startup-memory` to pass as part of one final-revision run in which all eight workflow jobs are green; static-initializer timing excludes exec/dyld/pre-main. |
| BLOCK-005 | 100 clean launches and 10,000 aggregate native round trips | `OPEN — LOCAL PASS, HOSTED PENDING` | At `ce3b4b3`, the sequential local run records 100 distinct PIDs, 10,000 cycles, and zero failures. Hosted closure requires executed, green `nightly-reliability` as part of one final-revision run in which all eight workflow jobs are green. |
| BLOCK-006 | Hosted-CI execution and ratio proof | `OPEN` | Closure requires all eight jobs currently defined by the workflow to execute and pass in one manually dispatched run on the final revision, with retained artifacts/run URL and a clearly hosted baseline/comparison bootstrap. Partial-green runs never qualify and are retained as failed attempts with their URLs. Failed attempts retained: CI #1 (`29315797697`, portability), CI #4 (`29327190429`, descriptor/memory-fixture defects), CI #5 (`29340697610`, cross-hardware benchmark baseline), and CI #6 (`29345329291`, contended ASan deadline test). Corrections through `5d2ea50` preserve all numeric gates; no qualifying run has been evaluated on the final revision. |
| BLOCK-007 | Fresh final-revision full verification battery | `CLOSED LOCALLY` | The complete local battery passed at code revision `ce3b4b3`. Hosted-only benchmark corrections required no local rerun. The later shared ASan gate input at `5d2ea50` was rerun at that exact revision and passed 89/89 plus the isolated unchanged corpus test 1/1; no other local gate input changed. Artifact mapping is in `revision-map.md`. |
| BLOCK-008 | Reproducibility metadata for corpus and benchmarks | `CLOSED` | `docs/phase-4/fuzz-results.md`, benchmark runner metadata, and retained `artifacts/r4/` logs |
| BLOCK-009 | Exact audit closure-matrix traceability | `CLOSED` | `docs/audits/findings-closure-matrix.md` names exact test files/functions and commits |
| BLOCK-010 | Correct and internally consistent R4 documents | `CLOSED` | Documentation closure commit containing this tracker and the corrected checkpoint/audit/policy files |
| BLOCK-011 | Exact revision accounting | `CLOSED` | `revision-map.md` maps the complete local battery to `ce3b4b3`/`8da5ee8`, CI #5 to `e01ac1b`, and the affected ASan rerun at `5d2ea50` to evidence `bd4524f`. Dependency, clean-room, symbol-graph, and release assembly/signature gates remain explicitly retained at the post-`ce3b4b3` battery. |
| BLOCK-012 | Annotated Phase 5 entry tag | `OPEN` | `pre-phase5-remediation` intentionally does not exist because BLOCK-006 and the hosted components of BLOCK-003/004/005 remain open. |

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

> **2026-07-13 — ADR-1 REVISED.** Minimum supported platform is raised from
> macOS 13.0 to **macOS 15.0 (Sequoia)**, Apple Silicon only (unchanged).
> Rationale: macOS 13 has exited Apple's security-update window; no macOS 13
> hardware is available or worth provisioning for a pre-release product; the
> owner's reference machine (MacBookPro18,2, macOS 15.x) becomes the
> minimum-OS runtime-proof environment. The 2026-07-13 Option A decision
> (BLOCK-002 requires BOTH codec reliability AND full-app startup runs at the
> minimum OS) is **retained in substance** and retargeted from macOS 13 to
> macOS 15; it is superseded only in its OS number, not its scope.
