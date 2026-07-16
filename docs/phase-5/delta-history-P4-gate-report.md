# Delta history P4 gate report

Date: 2026-07-16

Final build-input revision:
`17f45ab2b74f732fe6830ef18ebbaa37e4c1b1fe`

Core cutover revision:
`0157b2b8ce7346ebf315d82431f886141f9d012f`

Evidence: `artifacts/phase5/p4/`

## S1 — RESOLVED

The P1 runtime gate and its type/source are deleted. Delta history is
unconditional in production, tests, benchmarks, memory harnesses, Makefile,
and CI. All 37 formerly gated P1–P3 tests are ordinary unconditional tests.
The final benchmark describes `history=delta-only`.

`flag-removal-grep.txt` proves zero retired-identifier matches across Sources,
Tests, scripts, workflow, Makefile, Package.swift, and docs, and zero generic
runtime-flag wording in the application tree. Immutable P1–P3 evidence logs
are explicitly excluded because they are historical records, not live
references.

## S2 — RESOLVED

The snapshot `CommandHistory` undo/redo container, its legacy non-reversible
command initializer, snapshot memory-estimation helpers, 30-entry cap, and
five-entry pressure floor are removed. `AlignmentCommands.swift` and
`SceneCommands.swift` are also removed after their delta successors became
the sole production command surfaces.

Retained with a new owner:

- `DeltaCommandHistory.Checkpoint` document snapshots at the history head and
  frozen K=25 periodic boundaries;
- checkpoint recovery plus forward replay;
- `ApprovedAssetStore` shared immutable asset storage and separate
  history/checkpoint pin accounting;
- `GestureID`, `DocumentChange`, change broadcasting, reversible
  `DocumentCommand`, and unsaved-change coordination, moved to
  `DocumentCommand.swift`.

Checkpoint snapshots are recovery machinery only; no alternate application
undo path remains.

## S3 — RESOLVED

The complete row-by-row supersession table is committed in
`docs/verification/VERIFICATION_QUEUE.md`,
`docs/PROJECT_STATE.md`, and
`docs/phase-5/delta-history-P4.md`. Every deleted test names a permanent delta
successor or an owner-visible removal justification. The shared-asset snapshot
test is retained and renamed under the checkpoint owner rather than deleted.

## S4 — RESOLVED

`CanvasView` owns one `DeltaCommandHistory`. All tools and panels commit
value-swap, structural, resource, composite, or anchor-slice commands.
Transform/anchor drags use real delta gesture sessions; menu undo/redo calls
delta history directly. A macOS memory-pressure source invokes the delta
checkpoint safety net.

`headlessUIJourneyCreateStyleTransformSaveReopenAndExport` and
`accessibilityTreeExposesDocumentLayersSelectionAndFrames` both exercise
create, style, transform, group/ungroup, anchor edit, and undo/redo beyond 30.
The headless journey also saves, reopens, and exports. Both pass on the final
revision.

## S5 — RESOLVED

P3 executed 129 tests with the delta gate enabled. P4 deletes seven obsolete
snapshot/gate tests, adds no standalone test function, migrates two retained
tests in place, and expands two integration tests:

`129 - 7 + 0 = 122`.

The single debug and release populations each execute 122 tests with zero
skips. ASan executes 121 tests plus the isolated mutation-corpus deadline test.

### Complete final gate table

| Gate | Result |
|---|---|
| Format / debug / release / macOS 15 deployment | PASS |
| Debug tests | PASS — 122 executed, 0 skipped |
| Release tests | PASS — 122 executed, 0 skipped |
| AddressSanitizer main + isolated corpus | PASS — 121 + 1, zero diagnostics |
| Coverage | PASS — 88.81% >= 55% |
| Dependency direction / clean-room / symbol graph | PASS |
| Adversarial / golden / UI-accessibility | PASS — 2 / 1 / 2 |
| Release assembly and signature | PASS |
| BENCH-1 drag | PASS — p95 5.438 ms <= 16.7 ms |
| BENCH-2 pan | PASS — p95 0.111 ms <= 16.7 ms |
| BENCH-2b forced exposure | PASS — p95 5.713 ms <= 16.7 ms; 360/360 frames redraw strips |
| BENCH-3 zoom / settle | PASS — p95 8.865 ms <= 33 ms; settle 2.994 ms <= 100 ms |
| BENCH-4 cold-open | INFORMATIONAL — 9.049 ms |
| BENCH-5a composite/anchor undo-redo | PASS — p95 0.010 ms <= 16.7 ms |
| BENCH-5b structural/composite/anchor record | PASS — p95 0.829 ms <= 1.0 ms |
| Seven owner-reference local ratios | PASS — all <= 1.25 |
| Exact-1.25 pass / 1.314801 fail fixtures | PASS |
| Peak-memory settle | PASS — 285,294,592 <= 524,288,000 bytes |
| Peak-memory export | PASS — 295,862,272 <= 681,574,400 bytes |
| Peak-memory forced failure fixture | PASS — gate rejected 862,208,000 bytes |
| Full-app startup | PASS — p95 164.317 <= 2,000 ms |
| Reliability | PASS — 100 processes, 10,000 round trips, zero failures |

BENCH-5 headroom is 16.690 ms for 5a and 0.171 ms for 5b. No target was
adjusted to the observations.

## S6 — RESOLVED

ADR-012 records retirement execution while preserving its historical text.
`PROJECT_STATE.md` marks delta history P1–P4 DELIVERED and links the
supersession record. The VERIFY-022–028 batch remains FROZEN and is marked
implementation-complete with permanent P1–P3 test references intact.

## Frozen-integrity confirmation

No frozen VERIFY value, expected result, constant, tolerance, ceiling,
benchmark target, ratio threshold, or document-schema rule changed. Every
test deletion appears in the supersession table. Snapshot checkpoints and
shared immutable asset storage remain exactly where delta recovery requires
them; snapshot application undo/redo does not remain.

## Hosted follow-up — dispatched run 17

The first dispatched P4 benchmark run exited 133 before its redirected Swift
stdout buffer was flushed. The raw log, partial artifact, same-revision push
run, hypothesis classification, controlled line-195 reproduction, wrapper-only
evidence fix, and affected-gate rerun are recorded in
`artifacts/phase5/p4/hosted-run-17-triage.md`.

No production source, test, frozen value, absolute benchmark target,
precondition, or hosted/local gate semantic changed. The wrapper still returns
the benchmark binary's exit 133; it now preserves enough output to report the
exact hosted BENCH-5 value required by the standing owner-decision process.

## Hosted BENCH-5b owner decision

The 2026-07-16 owner decision retains BENCH-5b's frozen 1.0 ms p95 target as a
blocking owner-reference gate and makes only the GitHub-hosted observation
informational. Implementation revision
`afc03ddf236a816627ea408064541bd34b4e5b2f` adds a default-on harness-boundary
mode; only the hosted workflow selects `off`. BENCH-2b and BENCH-5a remain
blocking in both modes.

The two-way falsifiability fixtures, complete final-revision benchmark tables,
local ratios, scope proof, and external dispatch requirement are recorded in
`artifacts/phase5/p4/hosted-bench5b-policy-report.md`. No production module,
application test, frozen value, target, or scenario changed.
