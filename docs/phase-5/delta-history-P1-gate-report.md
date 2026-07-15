# Delta history P1 gate report

Date: 2026-07-16

Final build-input revision:
`e38200bc49b68f025c19c8a22fef4a9ea5969222`

Core implementation revision:
`7ec93fdb16356ccbc5b56c0f593353dcba254472`

Evidence: `artifacts/phase5/p1/`

## S1 — RESOLVED

`DocumentCommand` carries immutable ID, timestamp, damage bounds, structural
cost, pin metadata, atomic apply, and record-time-captured forward/inverse
assignments. Arbitrary/legacy closures validate a candidate before assignment;
the closed value-swap classes preflight the exact target/payload before their
single assignment. Command inversion swaps captured directions and performs no
geometry matrix inversion.

Files: `CommandHistory.swift`, `CanonicalDocumentEquality.swift`.

## S2 — RESOLVED

`ValueSwapCommands` implements node transform, path style, node property, text
content, layer visibility/lock, and artboard-property swaps. Canonical payload
bytes enforce P-IDENT; signed zero is distinct. Identity elision occurs before
redo clearing and counter increment.

Files: `ValueSwapCommands.swift`, `DeltaHistoryP1VerifyTests.swift`.

## S3 — RESOLVED

`DeltaCommandHistory` freezes N=200, B=67,108,864, M=10, K=25, and the
nine-checkpoint ceiling. It implements undo/redo stacks, commit-time redo
clearing, count/byte eviction under P-FLOOR, a monotone checked counter, head
and periodic checkpoints, single asset charging to the oldest retained pin,
and atomic reassignment when that pin is evicted. Redo entries remain charged.

The peak-memory harness concurrently retains a real 70,000,000-byte pinned
P-FLOOR history (Σ=70,009,000, zero evictions) and a 200-command history with
nine checkpoints.

Files: `DeltaCommandHistory.swift`, `R4GateHarness/main.swift`,
`check-peak-memory.sh`.

## S4 — RESOLVED

Undo/redo failure records `DeltaHistoryDiagnostic`, restores the nearest
lineage-compatible checkpoint, and replays captured forward commands. The
forced inverse-failure fixture reaches this path, restores the original state,
records checkpoint 0/replay 0, moves the entry to redo, and then redoes it.

Test: `testDeltaHistoryForcedInverseFailureRestoresNearestCheckpointAndReportsDiagnostic`.

## S5 — RESOLVED

The single runtime flag is `OPENDRAW_DELTA_HISTORY=1`; every other value and an
absent variable are OFF. The app still constructs only `CommandHistory`, so the
snapshot engine remains primary. Its 30-entry cap, five-entry pressure floor,
tests, and behavior are unchanged. P1 performs no supersession.

Files: `DeltaHistoryFeatureFlag.swift`, `delta-history-P1.md`.

## S6 — RESOLVED

Permanent named tests pin VERIFY-022, VERIFY-023, every required VERIFY-027
example, charge transfer, checkpoint count, VERIFY-028, failure containment,
all value-swap classes, and the seeded `0x00000000A110F00D` full-unwind/replay
corpus. The queue only gained test references and its R4-era range qualifier;
no frozen claim or value changed.

File: `DeltaHistoryP1VerifyTests.swift`.

## S7 — RESOLVED

Both BENCH-5 scenarios use release production code, the 1,000-object BENCH-1
scene, 60 warm-up operations, and 300 measured operations with the flag ON.

| Scenario | p50 | p95 | max | Frozen target | Result |
|---|---:|---:|---:|---:|---|
| BENCH-5a undo/redo apply | 0.006 ms | 0.006 ms | 0.032 ms | p95 <= 16.7 ms | PASS |
| BENCH-5b record/commit | 0.123 ms | 0.142 ms | 0.302 ms | p95 <= 1.0 ms | PASS |

The owner-reference baseline and exact-1.25 fixtures contain both rows. Local
ratios remain blocking; hosted absolute targets remain blocking; hosted ratios
remain informational with explicit bootstrap rows until the two hosted metrics
are reviewed into the hosted reference.

## S8 — RESOLVED

The historical queue line now says “R4-close scope,” while the sole current
statement freezes VERIFY-001–028. No ambiguous current frozen range remains.

## Final gate table

| Gate | Flag | Result |
|---|---|---|
| Format / debug build / release build / macOS 15 deployment build | OFF | PASS |
| Debug tests | OFF | PASS — 91 named tests executed, 11 delta tests skipped |
| Debug tests | ON | PASS — 102 named tests executed, 0 skipped |
| Release tests | OFF | PASS — 91 named tests executed, 11 delta tests skipped |
| Release tests | ON | PASS — 102 named tests executed, 0 skipped |
| AddressSanitizer main + isolated corpus | OFF | PASS — 91 named tests, 0 diagnostics |
| AddressSanitizer main + isolated corpus | ON | PASS — 102 named tests, 0 diagnostics |
| Coverage | ON | PASS — 88.84% >= 55% |
| Dependency direction / clean-room / symbol graph | OFF | PASS |
| Adversarial / golden / UI-accessibility focused suites | OFF | PASS |
| Release assembly and signature | OFF | PASS |
| BENCH-1/2/2b/3/settle/5a/5b absolute and local ratio gates | ON for BENCH-5 | PASS |
| Peak-memory settle | ON | PASS — 285,917,184 <= 524,288,000 bytes |
| Peak-memory export | ON | PASS — 295,845,888 <= 681,574,400 bytes |
| Peak-memory forced failure fixture | ON | PASS — observed gate failure at 862,568,448 bytes |
| Full-app startup | Snapshot primary | PASS — p95 185.225 <= 2,000 ms |
| Reliability | Snapshot primary | PASS — 100 launches, 10,000 round trips |

## Frozen-integrity confirmation

No frozen VERIFY value, constant, tolerance, ceiling, benchmark target, or
ratio threshold changed. No existing test was edited. The snapshot history
limit and five-entry pressure floor remain in source and their permanent test
passes with the flag OFF and ON. P2 has not begun.
