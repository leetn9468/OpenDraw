# OpenDraw remediation project state

Updated: 2026-07-19

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
| BLOCK-006 | Hosted-CI execution and ratio proof | `CLOSED` | Manually dispatched CI #8 (`29347892897`) at `94fb0f0` executed all eight `macos-15` jobs successfully. Artifacts/logs are retained by `88c3d58`; the hosted candidate remains at the hosted-reference path with exact provenance. CI #8 was bootstrap-only (`ratio_enforcement=OFF`, definitionally 1.000000). The post-remediation 2026-07-15 owner decision makes later hosted ratios informational while preserving blocking absolute targets and the unchanged blocking local 1.25 gate; remediation closure is unaffected. Failed/non-qualifying attempts remain recorded: `29325516216`, CI #4, CI #5 and CI #6. |
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

> **2026-07-15 — OD-1 (supersedes ADR-2 capacity):** history capacity is
> N = 200 commands AND B = 64 MiB (67,108,864 bytes, Σ costInBytes incl.
> history-pinned assets), minimum retained M = 10, checkpoint interval K = 25
> (global monotone command counter). ADR-2's 30/5 snapshot constants are
> superseded; the ADR text is appended, not rewritten.
> **OD-2:** hybrid checkpointing per spec §4 (snapshot every K commands and
> always at history head after eviction).
> **OD-3:** history remains runtime-only; document schema v4 unchanged.
> **OD-4:** ADR-2 supersession rationale: "the snapshot cap was a memory-cost
> ceiling, not a UX target; command-inverse history achieves deeper undo
> within a smaller budget."

> **2026-07-15 — Hosted benchmark ratio gate downgraded to INFORMATIONAL.**
> Measured cross-run hardware variance on GitHub-hosted `macos-15` runners is
> ~2.3–2.8× (runs #5, #8, and the first ENFORCE run), exceeding the 1.25
> ratio threshold's discrimination ability; a single-run baseline with a fixed
> ratio is structurally non-viable on shared runners. Therefore: (1) hosted
> ABSOLUTE benchmark targets remain BLOCKING and unchanged; (2) the hosted
> ratio comparison is retained and always emitted as an INFORMATIONAL artifact
> (never fails the job); (3) ratio-based regression detection remains BLOCKING
> exclusively on stable owner-reference hardware via the unchanged local gate
> and baseline. Options A (N-of-M retries) and B (loosened hosted ratio) were
> considered and rejected: both mask noise without adding detection power.
> This decision may only be revisited by a further explicit owner decision.

> **2026-07-17 — OD-5:** tile size 256×256 device pixels; tile-cache budget
> exactly 134,217,728 bytes (= 512 full tiles at 262,144 B each — the exact
> divisibility is a design property, pinned); LRU eviction by last composite
> use; exact byte accounting (w×h×4, edge tiles smaller); when the budget
> cannot fit one full tile the cache is disabled-but-correct (every composite
> miss-renders; the §3 invariant still holds).
> **OD-6:** exact-current-zoom caching; any zoom change bumps the cache
> generation (lazy full invalidation); zoom gestures retain the direct-render
> path — BENCH-3 semantics and targets untouched by construction.
> **OD-7:** per-object caching DEFERRED pending profiling evidence; Phase 5
> V1 is tile-only.
> **OD-8:** the peak-memory gate scenario extends to settle + delta-history
> P-FLOOR worst case + nine checkpoints + tile cache filled to budget; the
> 500 MiB ceiling is unchanged; under memory-safety-net pressure the tile
> cache is discarded FIRST (pure derived data), before any checkpoint and
> long before the history floor. **Reporting rule (owner correction,
> 2026-07-17): compliance is proven only by exact measured bytes and exact
> byte headroom at the gate; percentage estimates are never proof.** The
> arithmetic expectation — 285,294,592 (P4 measured settle peak) +
> 134,217,728 = 419,512,320 B, implying 104,775,680 B headroom under
> 524,288,000 — is an expectation only; the gate reports measured values.

Round-2 extension incorporated into the freeze: a backing-scale change bumps
the cache generation exactly like a zoom change.

> **BENCH-2b mechanism supersession.** The frozen 2-device-pixel-pan
> viewport-strip mechanism (BENCH-R3.5) is formally superseded for the tile
> era. New mechanism: a BENCH-2b-specific EXPOSURE CORRIDOR fixture —
> document 46,480 × 250 units, z = 2, backingScale = 1 (device 92,960 × 500),
> viewport 800 × 500 device px, pan exactly 256 device px (128 doc units) per
> frame, 360 advances (60 warm-up + 300 measured), each advance exposing
> exactly one never-rendered tile column (indices 4…363; initial columns 0…3
> rendered in setup). Content: a strictly periodic pattern, 25 nodes placed
> strictly interior to every 128-doc-unit period (364 periods, 9,100 nodes,
> within the 100,000 ceiling), so every new tile column intersects exactly
> 25 objects — pinned per-frame render load replaces node-count fidelity;
> the 1,000-node reference document remains unchanged for every other BENCH
> scenario. Retained unchanged: p95 ≤ 16.7 ms target, 60+300 schedule,
> trapping nonzero-render precondition. Strengthened: the harness asserts
> the EXACT new tile indices per frame — frame f renders exactly tiles
> (f+3, 0) and (f+3, 1) and everything else composites from cache; any other
> render or any hit-served never-rendered region traps. The old strip
> mechanism, counter, and fixture are retired with a row in the supersession
> record. This decision may only be revisited by explicit owner decision.

> **2026-07-16 — Hosted BENCH-5b absolute gate downgraded to INFORMATIONAL.**
> BENCH-5b is a sub-millisecond CPU micro-benchmark (structural/composite/
> anchor record-commit p95, target 1.0 ms, calibrated on owner-reference
> hardware). Measured shared-runner behavior spans 0.938 ms (run #16, pass at
> 6% margin) to 12.277 ms under controlled CPU contention — a >12× swing. No
> fixed hosted target for this gate can be simultaneously discriminating and
> stable: a 5 ms target still flaps under contention spikes; a 15 ms target
> detects nothing. Therefore: (1) BENCH-5b remains BLOCKING at the unchanged
> 1.0 ms p95 on owner-reference hardware (the gate that has correctly failed
> and forced optimization three times); (2) on hosted runners BENCH-5b is
> measured and reported as INFORMATIONAL — always emitted with p50/p95/max in
> the benchmark artifact, never failing the job; (3) BENCH-5a remains BLOCKING
> on hosted unchanged (0.026 ms p95 under the same contention — three orders
> of magnitude of headroom); (4) BENCH-1/2/2b/3 hosted absolute targets remain
> BLOCKING unchanged, with the standing BENCH-1 headroom WATCH retained.
> Precedent and rationale mirror the 2026-07-15 hosted-ratio decision:
> shared-runner noise is recorded, not enforced; enforcement lives on stable
> reference hardware. This decision may only be revisited by a further
> explicit owner decision.

> **2026-07-18 — Hosted BENCH-6 TIMING gate downgraded to INFORMATIONAL;
> BENCH-6 CORRECTNESS assertions remain BLOCKING everywhere.** BENCH-6
> (incremental tile-edit recomposite, p95 target 8.0 ms calibrated on
> owner-reference hardware) measured 4.787 and 5.708 ms on one hosted run
> and 16.964 ms (max 113.417 ms) on the next, on identical code — a >3.5×
> cross-run swing exceeding the target's 1.6× local headroom. As with the
> 2026-07-15 ratio and 2026-07-16 BENCH-5b decisions: no fixed hosted
> timing target for this gate can be simultaneously discriminating and
> stable; enforcement lives on stable reference hardware. Therefore:
> (1) BENCH-6 timing remains BLOCKING at the unchanged 8.0 ms p95 on
> owner-reference hardware; (2) hosted BENCH-6 timing is measured and
> emitted as INFORMATIONAL (p50/p95/max always in the artifact, never
> failing the job); (3) BENCH-6's CORRECTNESS preconditions — nonzero cache
> hits every measured frame, and rendered tiles EXACTLY equal to the frozen
> damage mapping (superset and subset both trap) — remain BLOCKING in BOTH
> modes without exception: they are runner-speed-independent and are the
> tile cache's staleness/over-invalidation defense; (4) all other gates'
> standing split is unchanged (absolute BENCH-1/2/2b/3 + BENCH-5a blocking
> everywhere; 5b and ratios per their existing decisions). Options A
> (higher hosted target) and C (N-of-M) considered and rejected: A cannot
> discriminate inside a 4.8–17 ms noise band; C masks noise. Revisit only
> by further explicit owner decision.

> **2026-07-18 — Wall-clock-deadline test isolation policy.** Any test whose
> assertion is a wall-clock deadline (currently: the adversarial-corpus
> deadline test and the geometry 15-second smoke) runs ISOLATED — after the
> main suite, sequentially, in EVERY job (local and hosted) that executes
> it. Deadlines themselves are unchanged and remain trapping. This
> generalizes the accepted CI #6 / T1 method from per-incident patching to a
> standing rule; future wall-clock-deadline tests join the isolated set by
> construction. Contention observations (CI #6: 7.90 s; this run: 3.427 s /
> 3.162 s) are the triggering evidence.

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

## Phase 5 operations decisions

The 2026-07-15 hosted-ratio and 2026-07-16 hosted BENCH-5b decisions are
post-remediation operations policies, not amendments to the accepted
remediation. Triggering ratio evidence is the first post-tag ENFORCE run,
<https://github.com/leetn9468/OpenDraw/actions/runs/29350963872>: every frozen
absolute BENCH target passed, while shared-runner ratios reached 2.343808–
2.780947. BENCH-5b evidence is the successful push run #16
<https://github.com/leetn9468/OpenDraw/actions/runs/29498775517>, failed
dispatch run #17
<https://github.com/leetn9468/OpenDraw/actions/runs/29499008599>, and the
controlled-contention reproduction retained in
`artifacts/phase5/p4/hosted-triage-stress-trap.txt`. BLOCK-001–012 remain
`CLOSED`, A6/A7 remain `ACCEPTED`, A8 remains `CLOSED — AUTHORIZED`, and
`pre-phase5-remediation` continues to target
`6dea372fc90d7474dc1f5db0085dd03bfdc046ea`.

## Phase 5 delivery state

Delta command history P1–P4 is **DELIVERED**. The runtime gate and snapshot
undo owner are retired; delta history is the only application undo/redo path.
The document schema remains v4 and runtime history remains unpersisted per
OD-3. Snapshot machinery remains only under its new checkpoint owner, with
shared immutable asset storage retained. Permanent VERIFY-022–028 evidence and
the authoritative supersession record are in
`docs/verification/VERIFICATION_QUEUE.md`; the P4 implementation map is
`docs/phase-5/delta-history-P4.md`.

Tile-render caching T1 and T2 were accepted at `fba6372` and `da6b14c`.
The tile-render caching specification is now **DELIVERED**:
`TileCompositeRenderer` is the only production renderer, the former
environment gate and all conditional test gating are removed, and the
BENCH-2b exposure corridor replaces the retired viewport-strip mechanism.
VERIFY-029–033 remain `FROZEN`; no frozen arithmetic, target, corpus draw,
or policy value changed. The executed deletion/successor table and local gate
map are in `docs/phase-5/tile-cache-T3.md`, with the production-renderer
decision in `docs/adr/ADR-014-tile-composite-production-renderer.md`.

T3 S6 is **CLOSED** by manually dispatched CI #28 on exact revision
`039560539127cb459f64216bd0ab93f5505a6de1`:
<https://github.com/leetn9468/OpenDraw/actions/runs/29625792344>. All eight jobs
passed. The production benchmark environment contained exactly the two
decision-backed informational timing inputs; BENCH-2b reported
`rendered_regions=728`; and BENCH-6 reported nonzero hits plus exact damage
mapping as blocking correctness. The full hosted BENCH table and job record are
retained in `artifacts/phase5/tile-t3/hosted-run-28-closure.md`.

Manual CI #26 on `6090efe` passed the real benchmark measurement and seven of
eight jobs, but its BENCH-5b-off falsifiability case was contaminated by an
organic BENCH-6 9.464 ms timing trap. The final fixture-class correction makes
every exit-asserting fixture all-timing-off except for its deterministic target
and permanently verifies that production CI contains exactly the two
decision-backed timing downgrades. Evidence is retained in
`artifacts/phase5/tile-t3/hosted-run-26-fixture-immunity.md`. CI #28 proves the
class fix on hosted hardware and closes that incident.

The editor UI redesign U3-A and U3-B is **DELIVERED**. U3-B implementation and
its complete local gate battery pass at
`a9f219c6b3f94befa55d7c5eba9409f4b80bd934`:
VERIFY-034 is frozen and executed, the six-control align family is live,
selection chrome and modifier interactions follow the design tokens, and the
retired create-text alert is superseded by in-place editing. TN LEE granted
owner visual acceptance on 2026-07-19 for
`artifacts/phase5/ui-b/chrome-dark-mid-gesture.png`, closing U3-B and the UI
redesign. The gate report, revision map, deviation delta, menu audit, and
supersession record are under
`artifacts/phase5/ui-b/` and `docs/phase-5/ui-redesign-U3B.md`, retained by
evidence revision `58bcf8e6f5d6a3828bc9e16c85303a514ada6c37`.

The feature's hosted story is **CLOSED** by manually dispatched CI #19 on exact
revision `d278755e020455955c1837a7aa36ef20ec0058fe`:
<https://github.com/leetn9468/OpenDraw/actions/runs/29529375715>. All eight jobs
executed successfully. Hosted BENCH-5a remained blocking and passed at
0.050 ms p95; BENCH-5b measured 1.067 ms p95 and was emitted as informational
under the frozen 2026-07-16 owner decision. Evidence is retained under
`artifacts/phase5/p4/`.

### P4 supersession table

| Removed/replaced item | Disposition | Successor evidence |
|---|---|---|
| Snapshot `CommandHistory` application undo/redo owner | Removed | `DeltaCommandHistory`; production wiring in `VectorFoundryApp/main.swift`; headless UI journey and accessibility integration tests |
| Legacy non-reversible `DocumentCommand(name:mutation:)` | Removed | Captured-inverse value-swap, structural, composite, resource, and anchor command factories; P1–P3 permanent suites |
| `historyLimitIsImmutableAndCappedAtThirty` | Deleted | `testVerify027CountEvictionAndReplayBoundFrozenExample`; OD-1 capacity assertions |
| `minimumHistoryEntriesUnderMemoryPressure = 5` and old pressure assertions | Removed | `testVerify027FloorOutranksByteBudgetFrozenExample`; `testP2SafetyNetDropsPeriodicCheckpointsButPreservesFloorPins` |
| `commandUndoRedoAndBranch` | Deleted | `testVerify028RedoBranchAndCancelledGestureFrozenStateMachine` |
| `historyDirtyCoalescingRollbackAndLimit` | Deleted; responsibilities split | `deltaRevisionDirtyAndChangeStreamSemantics`; `testP3RealGestureCoalescingCommitsOneCommandAndCancelPreservesRedo`; VERIFY-027 capacity proofs |
| `revisionGestureAndChangeStreamSemantics` | Migrated/renamed | `deltaRevisionDirtyAndChangeStreamSemantics` |
| `failedFirstGestureDoesNotCorruptLaterCoalescing` | Deleted | `testP3AnchorGestureCoalescesAndFailedFirstGestureDoesNotCorruptLaterCoalescing` |
| `alignmentIsUndoable` | Deleted | `testP3AlignmentIsOneCompositeAndUndoableOnDeltaPath` |
| `directAnchorGroupUngroupAndCompoundCommandsAreUndoable` | Deleted | P3 group/compound round-trip proof plus migrated direct-anchor deletion and handle tests |
| `snapshotHistorySharesEmbeddedAssetsAndHonorsMemorySafetyNet` | Retained semantics, migrated to checkpoint owner | `checkpointHistorySharesEmbeddedAssetsAndHonorsMemorySafetyNet`; P2 safety-net proof; retained checkpoint snapshots and `ApprovedAssetStore` |
| P1 default-off feature-gate test | Deleted with the removed gate | Single unconditional 122-test population and zero-reference application-tree grep |
| `AlignmentCommands.swift` | Removed | `CompositeSceneCommands.align` |
| `SceneCommands.swift` | Removed | `StructuralCommands`, `CompositeSceneCommands`, and `AnchorGeometryCommands` |
| ADR-012 snapshot-primary 30/5 rows | Superseded; historical text retained | OD-1–OD-4 and ADR-012 retirement execution note |
