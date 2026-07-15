# Delta history P2 gate report

Date: 2026-07-16

Final build-input revision:
`db19297de665daedad53bc2c23580e708d859fce`

Core implementation revision:
`7e3c8e7d2f138797c1c5ad15ed6022ce06c5d759`

Performance correction revision:
`3679dfa960c82934ae26fa74653acbaf8f948c2d`

Evidence: `artifacts/phase5/p2/`

## S1 — RESOLVED

`StructuralCommands` implements shape, text, image, paste, and layer insertion.
Insert preflight proves the exact target position, validates the new payload,
and checks additive global IDs, recursive node/segment counts, and aggregate
asset bytes before mutating the accepted document. Duplicate-ID, 100,001st-node,
and 1,025th-layer fixtures throw with counter zero and byte-identical documents.
Inverse removes the captured IDs.

Files: `StructuralCommands.swift`, `DeltaHistoryP2VerifyTests.swift`.

## S2 — RESOLVED

Delete and cut store exact parent/index/full-node slots. Multi-delete is one
command; its documented deepest/descending removal order is inverted in exact
reverse order. The permanent `[A,B,C]` fixture restores B at index 1 with an
equal payload. Deleting the only child leaves the group node intact and undo
restores the child at index 0 under VERIFY-022 equality.

Files: `StructuralCommands.swift`, `DeltaHistoryP2VerifyTests.swift`.

## S3 — RESOLVED

Node z-order, cross-parent moves, and layer reorder capture before/after
positions and restore them exactly. A same-position reorder has byte-identical
canonical payloads, so P-IDENT elides it without clearing redo or incrementing
the counter. Same-parent, cross-layer, layer-order, identity, undo, and redo
paths are permanently pinned.

## S4 — RESOLVED

`ApprovedAssetStore` is a shared SHA-256-addressed immutable byte store.
`ApprovedImageCache` publishes bytes after decoder approval. Structural
commands require embedded bytes to be present in that store and carry real
approved-store pins separately from structural cost.

`DeltaCommandHistory` atomically replaces its complete history/checkpoint pin
sets. The three-MiB fixture survives zero-byte store pressure and restores an
identical SHA-256. Real oldest-pin eviction transfers both the store pin and B
charge to the later entry; last-pin eviction releases the bytes; checkpoint-only
pins remain outside B. Safety-net pressure drops periodic checkpoints while
preserving all ten M-floor entries and their real pin. The independent
`maximumRetainedBitmapPixels` constant remains unchanged.

Files: `ApprovedAssetStore.swift`, `ApprovedImages.swift`,
`DeltaCommandHistory.swift`, `R4GateHarness/main.swift`.

## S5 — RESOLVED

VERIFY-024 has implementation-only permanent references for its exact three
frozen examples:

- `testVerify024ABCExactIndexAndPayloadRestoration`
- `testVerify024ThreeMiBAssetSurvivesPressurePinnedAndSHA256RoundTrip`
- `testVerify024EmptyGroupPersistsAndInverseRestoresIndexZero`

No claim, number, hash rule, or frozen status was edited.

## S6 — RESOLVED

The `0x00000000A110F00D` mixed corpus uses value swaps, structural insert/remove,
and reorder. A balanced 40-command prefix returns to D0 and is then evicted by
200 retained mixed commands. It proves 40 count evictions, the nine-checkpoint
ceiling, exact VERIFY-022 equality at every retained undo/redo step, full unwind
to D0, and replay to Dn with standing `CORPUS_FAILURE` retention metadata.

## S7 — RESOLVED

Flag remains default OFF; snapshot history remains primary; no supersession
occurs. BENCH-5 now measures structural delete/reinsert on the fixed 1,000-node
scene. The first final-battery attempt correctly failed at 1.139 ms p95. The
target was not changed. Read-only positional preflight removed a redundant
array copy, and the shell wrapper was corrected so `tee` cannot mask a failed
absolute-target precondition.

| Scenario | p50 | p95 | max | Frozen target | Headroom | Result |
|---|---:|---:|---:|---:|---:|---|
| BENCH-5a structural undo/redo | 0.101 ms | 0.366 ms | 0.477 ms | p95 <= 16.7 ms | 16.334 ms | PASS |
| BENCH-5b structural record/commit | 0.301 ms | 0.885 ms | 1.040 ms | p95 <= 1.0 ms | 0.115 ms | PASS |

All seven owner-reference ratios pass; exact-1.25 pass and 1.314801 fail
fixtures remain blocking and pass.

## Flag-state test accounting

| Configuration | Executed | Skipped | Result |
|---|---:|---:|---|
| Debug, flag OFF | 92 | 22 | PASS |
| Debug, flag ON | 114 | 0 | PASS |
| Release, flag OFF | 92 | 22 | PASS |
| Release, flag ON | 114 | 0 | PASS |

Relative to accepted P1, P2 adds twelve tests: one unconditional approved-cache
store-wiring test and eleven default-off delta tests. The eleven flag-isolated
tests are structural class/atomic rejection, node/layer ceilings, VERIFY-024
ABC, multi-cut order, empty group, three-MiB SHA, real-pin transfer, last-pin
release/checkpoint accounting, safety-net floor pins, reorder/identity, and the
mixed corpus. Thus P1's 11 delta tests plus P2's 11 are the 22 OFF skips.

## Final gate table

| Gate | Flag | Result |
|---|---|---|
| Format / debug / release / macOS 15 deployment | OFF | PASS |
| Debug tests | OFF | PASS — 92 executed, 22 skipped |
| Debug tests | ON | PASS — 114 executed, 0 skipped |
| Release tests | OFF | PASS — 92 executed, 22 skipped |
| Release tests | ON | PASS — 114 executed, 0 skipped |
| AddressSanitizer main + isolated corpus | OFF | PASS — 113 + 1, zero diagnostics |
| AddressSanitizer main + isolated corpus | ON | PASS — 113 + 1, zero diagnostics |
| Coverage | ON | PASS — 88.46% >= 55% |
| Dependency direction / clean-room / symbol graph | OFF | PASS |
| Adversarial / golden / UI-accessibility | OFF | PASS — 2 / 1 / 2 |
| Release assembly and signature | OFF | PASS |
| BENCH-1/2/2b/3/settle/5a/5b absolute + local ratios | ON for BENCH-5 | PASS |
| Peak-memory settle | ON | PASS — 285,900,800 <= 524,288,000 bytes |
| Peak-memory export | ON | PASS — 296,075,264 <= 681,574,400 bytes |
| Peak-memory forced failure fixture | ON | PASS — gate rejected 862,814,208 bytes |
| Full-app startup | Snapshot primary | PASS — p95 160.703 <= 2,000 ms |
| Reliability | Snapshot primary | PASS — 100 launches, 10,000 round trips |

## Frozen-integrity confirmation

No frozen VERIFY value, expected result, constant, tolerance, ceiling,
benchmark target, or ratio threshold changed. No pre-existing test was edited
or weakened. The P1 stub-pin test remains. Snapshot `CommandHistory`, its
30-entry cap, five-entry pressure floor, primary app selection, and tests are
unchanged. P3 has not begun.
