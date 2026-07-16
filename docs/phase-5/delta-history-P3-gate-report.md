# Delta history P3 gate report

Date: 2026-07-16

Final build-input revision:
`311ea023a63b0820c72fd1ba64e1ea5985ec4be6`

Core implementation revision:
`18d5a2ab5fa33b4cac3911756598eb06f4b58388`

Evidence: `artifacts/phase5/p3/`

## S1 — RESOLVED

`CompositeCommands.ordered` stores an ordered child list and captures its
inverse as reversed captured child inverses. It sums child structural costs
plus 128 bytes of framing, unions child damage, carries child asset pins, and
identity-elides an all-identity list.

Forward and inverse child lists apply sequentially. A child failure unwinds
prior children in reverse. A clean unwind leaves the document unchanged and
records nothing. If an unwind itself fails, the direct command restores its
captured pre-state and delta history engages nearest-checkpoint recovery with
a structured `.commit` diagnostic. Both branches are permanent forced-failure
fixtures. No matrix inversion occurs in command code.

Files: `CompositeCommands.swift`, `DeltaCommandHistory.swift`,
`DeltaHistoryP3VerifyTests.swift`.

## S2 — RESOLVED

`CompositeSceneCommands` stages every child mutation before constructing the
next command, so every inverse captures the exact intermediate state.
Group/ungroup are mirror composites. Ungroup stores each `G ∘ Nᵢ` local
transform, reparents in stable order, then removes the empty group. The frozen
VERIFY-025 fixture pins `(9,2)`, `(5,2)`, `(6,0)`, and child-1 origin `(7,2)`
exactly. A separate rotated-group integration fixture pins exact visual-bounds
invariance.

Make/release-compound are structural composites over exact subpath membership
and full stored payloads. Group→ungroup and make→release round trips satisfy
VERIFY-022 canonical equality.

Files: `CompositeSceneCommands.swift`, `DeltaHistoryP3VerifyTests.swift`.

## S3 — RESOLVED

Multi-object alignment deterministically orders selected IDs, computes the
existing visual-bounds alignment result, and records one composite of captured
transform value swaps. The delta-path fixture proves one history entry and
exact canonical restoration after undo. The original snapshot-path
`alignmentIsUndoable` behavior and test are untouched.

## S4 — RESOLVED

`PathAnchorSlice` is the runtime-history `{A,H_in,H_out}` representation.
Endpoint absence is `nil` only in this derived slice; `PenAnchor` and schema v4
are unchanged. Slice assignment writes stored pre/post values verbatim.

Permanent VERIFY-026 fixtures pin the exact smooth triple `(100,100)`,
`(90,95)`, `(110,105)`, its translated triple `(120,110)`, `(110,105)`,
`(130,115)`, bitwise stability of the untouched corner handle, and restoration
of endpoint `nil`. Structural anchor add/delete uses captured cubic-segment
array slices and exact inverse replacement.

Files: `AnchorGeometryCommands.swift`, `DeltaHistoryP3VerifyTests.swift`.

## S5 — RESOLVED

The delta history now has real transform and anchor gesture sessions.
Intermediate updates mutate the rendered document without touching undo,
redo, or the global counter. Gesture end records one explicit pre/post command;
cancellation restores the pre-state without clearing redo or incrementing the
counter.

Permanent fixtures prove transform and anchor coalescing, commit-time redo
clearing, cancelled-gesture redo preservation, and that a failed first anchor
update does not corrupt the next gesture. Snapshot `CommandHistory` and its
existing coalescing tests are untouched.

## S6 — RESOLVED

FROZEN VERIFY-025 and VERIFY-026 now list their P3 permanent test names.
The Phase 5 section records **P-COMPOSITE-ATOMIC** exactly as owner-authored:
clean reverse unwind, containment on unwind failure, child-cost plus framing,
damage union, and composite-granularity identity elision. The passing fixtures
constitute Codex agreement. No frozen claim or numeric value was edited.

## S7 — RESOLVED

The pinned `0x00000000A110F00D` corpus now mixes group/ungroup composites,
alignment composites, transform value swaps, and anchor slices. Seeded anchor
deltas vary numerically while paired operations retain exact cycle boundaries.
The 204-command run creates periodic checkpoints, evicts four oldest commands,
then proves VERIFY-022 equality at every one of 200 retained undo and redo
steps. Failures retain `CORPUS_FAILURE` kind, index, seed, and phase metadata.

## S8 — RESOLVED

Flag remains default OFF; snapshot history remains primary; zero supersessions
occur. BENCH-5 measures a production composite containing transform and anchor
slice children, mixed with structural record/commit operations on the fixed
1,000-node scene.

| Scenario | p50 | p95 | max | Frozen target | Headroom | Result |
|---|---:|---:|---:|---:|---:|---|
| BENCH-5a composite/anchor undo-redo | 0.009 ms | 0.010 ms | 0.140 ms | p95 <= 16.7 ms | 16.690 ms | PASS |
| BENCH-5b structural/composite/anchor record | 0.182 ms | 0.818 ms | 0.868 ms | p95 <= 1.0 ms | 0.182 ms | PASS |

All seven owner-reference ratios pass. The exact-1.25 pass and 1.314801 fail
fixtures remain blocking and pass.

## Flag-state test accounting

| Configuration | Executed | Skipped | Result |
|---|---:|---:|---|
| Debug, flag OFF | 92 | 37 | PASS |
| Debug, flag ON | 129 | 0 | PASS |
| Release, flag OFF | 92 | 37 | PASS |
| Release, flag ON | 129 | 0 | PASS |

Relative to accepted P2, P3 adds fifteen default-off delta tests:

1. clean composite rollback;
2. unwind-failure checkpoint containment and direct atomicity;
3. all-identity composite elision;
4. frozen VERIFY-025 ungroup numbers;
5. single-child reversal;
6. group/ungroup and compound canonical round trips;
7. rotated-group visual invariance;
8. alignment as one composite;
9. frozen VERIFY-026 smooth triple;
10. corner-handle bitwise stability;
11. endpoint-`nil` restoration;
12. structural anchor-slice add/delete;
13. transform gesture coalescing and cancellation;
14. anchor gesture coalescing after a failed first gesture; and
15. seeded composite/anchor eviction-and-checkpoint corpus.

Thus P1's 11, P2's 11, and P3's 15 are the 37 OFF skips.

## Final gate table

| Gate | Flag | Result |
|---|---|---|
| Format / debug / release / macOS 15 deployment | OFF | PASS |
| Debug tests | OFF | PASS — 92 executed, 37 skipped |
| Debug tests | ON | PASS — 129 executed, 0 skipped |
| Release tests | OFF | PASS — 92 executed, 37 skipped |
| Release tests | ON | PASS — 129 executed, 0 skipped |
| AddressSanitizer main + isolated corpus | OFF | PASS — 128 + 1, zero diagnostics |
| AddressSanitizer main + isolated corpus | ON | PASS — 128 + 1, zero diagnostics |
| Coverage | ON | PASS — 88.55% >= 55% |
| Dependency direction / clean-room / symbol graph | OFF | PASS |
| Adversarial / golden / UI-accessibility | OFF | PASS — 2 / 1 / 2 |
| Release assembly and signature | OFF | PASS |
| BENCH-1/2/2b/3/settle/5a/5b absolute + local ratios | ON for BENCH-5 | PASS |
| Peak-memory settle | ON | PASS — 286,359,552 <= 524,288,000 bytes |
| Peak-memory export | ON | PASS — 296,271,872 <= 681,574,400 bytes |
| Peak-memory forced failure fixture | ON | PASS — gate rejected 862,879,744 bytes |
| Full-app startup | Snapshot primary | PASS — p95 152.765 <= 2,000 ms |
| Reliability | Snapshot primary | PASS — 100 launches, 10,000 round trips |

## Frozen-integrity confirmation

No frozen VERIFY value, expected result, constant, tolerance, ceiling,
benchmark target, or ratio threshold changed. No pre-existing test was edited
or weakened. P1 and P2 permanent tests remain intact. Snapshot
`CommandHistory`, its 30-entry cap, five-entry pressure floor, primary app
selection, and behavior are unchanged. P4 has not begun.
