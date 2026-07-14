# OpenDraw remediation project state

Updated: 2026-07-15

The owner-directed tracker was absent from repository history when the R4
rejection was received. This file restores the twelve hard closure rows from
that directive. A row is closed only by committed, directly named evidence.

## Acceptance checkpoints

| Acceptance | State | Evidence / blocker |
|---|---|---|
| A6 — R3/R3-B checkpoint package | `ACCEPTED` | Exact 14-row table, zero-new-production-math declaration, grep proof and 19-test combined pass; revalidated in the complete `f6ec81a` battery and directly inspected by TN LEE. |
| A7 — R4 CI/reliability acceptance | `ACCEPTED` | Technical hosted requirements closed through CI #8. TN LEE completed the mandatory three-file inspection on 2026-07-15 at 00:38 UTC+08:00; record: `artifacts/r4/a7-human-spot-check.md`. |
| A8 — Phase 5 entry | `CLOSED — AUTHORIZED` | Annotated tag `pre-phase5-remediation` targets acceptance-evidence revision `6dea372fc90d7474dc1f5db0085dd03bfdc046ea`. |

## Hard blockers

| ID | Requirement | State | Direct evidence / exact remaining requirement |
|---|---|---|---|
| BLOCK-001 | Restore the exact 14-item A6 closure package | `CLOSED` | `docs/remediation/A6-R3-checkpoint.md`; `a6-test-existence.txt`; `a6-filtered-tests.txt`; explicit test-side numeric-policy classification and zero-new-production-math declaration |
| BLOCK-002 | Prove the real minimum-OS (macOS 15.x) Apple Silicon release smoke | `CLOSED` | On MacBookPro18,2 / Apple M1 Max / 64 GB / macOS 15.7.5 build 24G624 / Swift 6.1.2 at current build-input revision `ce3b4b3`: `macos15-reliability-100x100.txt` proves 100 distinct clean processes and 10,000 round trips with zero failures; `macos15-startup-p95.txt` proves 20 full-app launches with p95 143.960 ms ≤ 2,000 ms. Both retain environment metadata. |
| BLOCK-003 | Enforced peak-memory assertions | `CLOSED` | Local gate passes at `ce3b4b3`; qualifying CI #8 `startup-memory` passes on `94fb0f0` at 214,106,112/223,936,512 bytes and the unchanged forced fixture fails as required at 790,921,216 bytes. |
| BLOCK-004 | Enforced startup p95 | `CLOSED` | Local gate passes at `ce3b4b3`; qualifying CI #8 passes 20 hosted launches at p95 225.979 ms against the unchanged 2,000 ms target. |
| BLOCK-005 | 100 clean launches and 10,000 aggregate native round trips | `CLOSED` | Qualifying CI #8 executes `nightly-reliability`: 100 distinct processes, 10,000 cycles, zero crashes/nonzero exits/timeouts/corruption. |
| BLOCK-006 | Hosted-CI execution and ratio proof | `CLOSED` | Manually dispatched CI #8 (`29347892897`) at `94fb0f0` executed all eight `macos-15` jobs successfully. Artifacts/logs are retained by `88c3d58`; the hosted candidate is committed at the enforced path with exact 90-day provenance. CI #8 was bootstrap-only (`ratio_enforcement=OFF`, definitionally 1.000000); the next hosted run automatically enforces the unchanged 1.25 ratio. Failed/non-qualifying attempts remain recorded: `29325516216`, CI #4, CI #5 and CI #6. |
| BLOCK-007 | Fresh final-revision full verification battery | `CLOSED` | Complete local battery passed at `ce3b4b3`; the affected shared ASan gate passed at `5d2ea50`; qualifying CI #8 passed all eight jobs at `94fb0f0`; hosted baseline validation and ratio fixtures passed at `88c3d58`. Artifact mapping is in `revision-map.md`. |
| BLOCK-008 | Reproducibility metadata for corpus and benchmarks | `CLOSED` | `docs/phase-4/fuzz-results.md`, benchmark runner metadata, and retained `artifacts/r4/` logs |
| BLOCK-009 | Exact audit closure-matrix traceability | `CLOSED` | `docs/audits/findings-closure-matrix.md` names exact test files/functions and commits |
| BLOCK-010 | Correct and internally consistent R4 documents | `CLOSED` | Documentation closure commit containing this tracker and the corrected checkpoint/audit/policy files |
| BLOCK-011 | Exact revision accounting | `CLOSED` | `revision-map.md` maps the complete battery and every later affected-gate rerun through qualifying CI #8 and evidence commit `88c3d58`. CI #8 directly passes dependency, clean-room, symbol-graph and release assembly/signature on `94fb0f0`. |
| BLOCK-012 | Annotated Phase 5 entry tag | `CLOSED` | Annotated tag `pre-phase5-remediation` exists and resolves to exact acceptance-evidence revision `6dea372fc90d7474dc1f5db0085dd03bfdc046ea`. |

## Tag state

`pre-phase5-remediation`: **PRESENT — ANNOTATED**, target
`6dea372fc90d7474dc1f5db0085dd03bfdc046ea`.

Overall verdict: **PASSED — PHASE 5 ENTRY AUTHORIZED**.

## A7 human inspection record

TN LEE directly opened `artifacts/r4/a6-test-existence.txt`,
`artifacts/r4/revision-map.md`, and the exact 14-row table in
`docs/remediation/A6-R3-checkpoint.md` on 2026-07-15 at 00:38 UTC+08:00.
Existence-proof format, per-artifact revision accounting, and exact per-row test
names were confirmed. The permanent record is
`artifacts/r4/a7-human-spot-check.md`.

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
