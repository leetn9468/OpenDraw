# Tile caching T2 revision map

Build-input revision: `da6b14ca7809fb9b2e1328832fc7a2dc7967eb97`
Accepted T1 basis: `fba6372`; T1 evidence basis: `0a9918b`; frozen basis: `790c013`

| Scope | Status | Implementation / permanent references | Evidence |
|---|---|---|---|
| S1 gesture damage publication | RESOLVED | `DocumentDamage.swift`; `DocumentCommand.swift`; `DeltaCommandHistory.swift`; `ValueSwapCommands.swift`; `verifyT2TransformGesturePublishesFrameCommitAndCancellationDamage` | `debug-tests-flag-off.txt`, `release-tests-flag-off.txt` |
| S2 single invalidation choke point | RESOLVED | `TileCompositeRenderer.subscribe/consume/invalidate`; `TileCache.invalidate`; `verifyT2TypedChangesUseOneInvalidationChokePoint` | `debug-tests-flag-on.txt`, `asan-tests-flag-on-main.txt`, `scope-proof.txt` |
| S3 frozen VERIFY-033 corpus | RESOLVED | `verify033FrozenSeededInvalidationCompletenessCorpus` | `corpus-distribution.txt`, `debug-tests-flag-on.txt`, `asan-tests-flag-on-main.txt` |
| S4 BENCH-6 | RESOLVED | `RenderBenchmark/main.swift`; `run-render-benchmark.sh`; `test-bench6-gate.sh`; local baseline/ratio fixtures; hosted CI wiring | `render-benchmark.txt`, `benchmark-comparison.txt`, `bench6-gate-fixture.txt`, `benchmark-ratio-fixtures.txt` |
| S5 memory envelope / pressure order | RESOLVED | `R4GateHarness/main.swift`; `TileCacheMemoryPressure.swift`; `check-peak-memory.sh`; `verifyT2PressureDropsFullTileCacheBeforeCheckpointsAndPreservesFloorPins` | `peak-memory.txt`, `peak-memory-failure-fixture.txt`, `debug-tests-flag-on.txt` |
| S6 final local gates | RESOLVED | full batteries, ASan, coverage, benchmark, memory and integrity gates | `gate-summary.md`, `test-counts.txt`, remaining logs in this directory |

## Frozen corpus distribution (verbatim)

```text
CORPUS_DISTRIBUTION seed=0x00000000A110F00D steps=64 advances=205
operations=valueSwap:15 structural:21 reorder:5 undo:8 redo:5 gestureFrame:6 zoomChange:4
structural=insert:11 delete:10
gesture_frames=open:6 continue:0
zoom_changes=step2:1.0->1.0 step14:1.0->1.5 step19:1.5->0.5 step38:0.5->0.5
last_step=(64, 'gestureFrame', 205)
```

## Scope boundary

- No frozen arithmetic, target, policy, operation range, or draw-consumption value changed; frozen-file changes are references only.
- `CanvasView` remains a direct `CoreGraphicsRenderer` caller and has no `TileCompositeRenderer` reference.
- BENCH-1/2/2b/3/5 remain direct and do not read `OPENDRAW_TILE_CACHE`; BENCH-6 uses explicit tile configuration.
- The BENCH-2b block and its T3 corridor supersession were not changed.
