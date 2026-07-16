# Delta history P4 — production cutover and retirement map

Date: 2026-07-16

Status: implementation complete; final gate evidence is recorded separately in
`delta-history-P4-gate-report.md` and `artifacts/phase5/p4/`.

## Sole production owner

`VectorFoundryApp.CanvasView` owns one `DeltaCommandHistory`. Shape, text,
image, layer, style, gradient, alignment, grouping, compound, transform, and
anchor operations all commit captured-inverse commands. Transform and anchor
drags use delta gesture sessions, so intermediate frames are not recorded.
Menu undo/redo call delta history directly. A macOS memory-pressure dispatch
source invokes `DeltaCommandHistory.applyMemorySafetyNet()`.

The former runtime gate was deleted. Tests, scripts, Makefile targets,
benchmarks, the memory harness, and CI now execute one unconditional history
configuration.

## Removed types and files

- `CommandHistory.swift`: the snapshot undo/redo container was removed.
  Shared protocol/change-stream/unsaved-coordinator declarations moved to
  `DocumentCommand.swift`.
- The P1 runtime-gate source: removed with no replacement toggle.
- `AlignmentCommands.swift`: replaced by `CompositeSceneCommands.align`.
- `SceneCommands.swift`: replaced by `StructuralCommands`,
  `CompositeSceneCommands`, and `AnchorGeometryCommands`.
- The legacy non-reversible `DocumentCommand(name:mutation:)` initializer was
  removed. Production commands require captured inverse data.
- The old 30-entry and five-entry pressure constants were removed from
  `DocumentLimits`.

## Retained snapshot mechanism with a new owner

Snapshot undo history is retired, but checkpoint snapshots are retained inside
`DeltaCommandHistory`. The retained pieces are:

- the history-head checkpoint representing state before the oldest retained
  command;
- periodic checkpoints at the frozen K=25 interval, bounded to nine total
  checkpoints including the head;
- `ApprovedAssetStore` shared immutable embedded-asset storage and separate
  history/checkpoint pin accounting;
- checkpoint recovery and forward replay after inverse or composite-unwind
  failure.

These snapshots are recovery accelerators owned by delta history, not an
alternate application undo path.

## Test population reconciliation

P3 executed 129 tests with the gate enabled. P4 deletes seven obsolete tests:
six snapshot/gate tests and the P1 gate-default test. Two snapshot tests are
migrated in place rather than deleted. No new standalone P4 test function is
added; the existing UI journey and accessibility tests are expanded to prove
the production cutover. The resulting single population is:

`129 - 7 + 0 = 122 tests`.

The expanded headless UI journey and accessibility tests both exercise create,
style, transform, group/ungroup, anchor editing, and undo/redo beyond depth 30.
The headless journey additionally saves, reopens, and exports the resulting
document.

## Complete supersession table

| Removed/replaced item | Disposition | Successor evidence |
|---|---|---|
| Snapshot `CommandHistory` application undo/redo owner | Removed | `DeltaCommandHistory`; production wiring in `VectorFoundryApp/main.swift`; headless UI journey and accessibility tests |
| Legacy non-reversible `DocumentCommand(name:mutation:)` | Removed | Captured-inverse command factories and P1–P3 permanent suites |
| `historyLimitIsImmutableAndCappedAtThirty` | Deleted | `testVerify027CountEvictionAndReplayBoundFrozenExample`; OD-1 capacity assertions |
| `minimumHistoryEntriesUnderMemoryPressure = 5` and old pressure assertions | Removed | `testVerify027FloorOutranksByteBudgetFrozenExample`; `testP2SafetyNetDropsPeriodicCheckpointsButPreservesFloorPins` |
| `commandUndoRedoAndBranch` | Deleted | `testVerify028RedoBranchAndCancelledGestureFrozenStateMachine` |
| `historyDirtyCoalescingRollbackAndLimit` | Deleted; responsibilities split | `deltaRevisionDirtyAndChangeStreamSemantics`; `testP3RealGestureCoalescingCommitsOneCommandAndCancelPreservesRedo`; VERIFY-027 capacity proofs |
| `revisionGestureAndChangeStreamSemantics` | Migrated/renamed | `deltaRevisionDirtyAndChangeStreamSemantics` |
| `failedFirstGestureDoesNotCorruptLaterCoalescing` | Deleted | `testP3AnchorGestureCoalescesAndFailedFirstGestureDoesNotCorruptLaterCoalescing` |
| `alignmentIsUndoable` | Deleted | `testP3AlignmentIsOneCompositeAndUndoableOnDeltaPath` |
| `directAnchorGroupUngroupAndCompoundCommandsAreUndoable` | Deleted | `testP3GroupUngroupAndCompoundRoundTripsRestoreCanonicalDocument`; migrated direct-anchor integration tests |
| `snapshotHistorySharesEmbeddedAssetsAndHonorsMemorySafetyNet` | Retained semantics, migrated to checkpoint owner | `checkpointHistorySharesEmbeddedAssetsAndHonorsMemorySafetyNet`; P2 safety-net and real-pin proofs |
| P1 default-off feature-gate test | Deleted with the removed gate | Single unconditional 122-test population and zero-reference application-tree grep |
| `AlignmentCommands.swift` | Removed | `CompositeSceneCommands.align` |
| `SceneCommands.swift` | Removed | `StructuralCommands`, `CompositeSceneCommands`, and `AnchorGeometryCommands` |
| P1 runtime-gate source | Removed | Delta history is the sole production and test path |
| ADR-012 snapshot-primary 30/5 rows | Superseded; historical text retained | OD-1–OD-4 and ADR-012 retirement execution note |

Every deleted test appears above. No deletion has an empty justification.
