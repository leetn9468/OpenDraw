# Tile-render caching T3 — production cutover and local closure

Date: 2026-07-17  
Accepted T2 basis: `da6b14c` (`6452540` evidence)  
Frozen basis: `790c013`  
Implementation commits: `2b7e214`, `5f18000`, `58e867b`, `be6b0d4`, `a7c5b9f`

## Result

S1–S5 are resolved locally. `CanvasView` owns `TileCompositeRenderer`; the
direct renderer exists only inside that owner for tile misses and OD-6 gesture
frames, plus independent VERIFY-032/033 references. The startup gate is gone,
all accepted T1/T2 tests are unconditional, and BENCH-1/2/3 now exercise the
production tile path.

S6 is open. No push or hosted manual dispatch was performed by this local
implementation task. The feature closes only after the operator dispatches
the exact final revision and all eight hosted jobs are retained and reported.

## Reconciled unconditional population

`140 − 4 + 2 = 138` tests:

- 140 was the accepted T2 enabled population.
- Four mechanism-coupled tests were retired with `SceneBitmapCache` and
  `ViewportStripCache`.
- Two permanent replacements were added:
  `bench2bExposureCorridorRendersExactIndices` and
  `productionDocumentCoordinateCompositeEqualsDirect`.

The 12 formerly conditional tests are now unconditional:

1. `verify029FrozenDamageMappingExamples`
2. `verify029FrozenConservativeInkCases`
3. `verify030FrozenGridGeometryAndByteCosts`
4. `verify031FrozenCapacityAndExactBoundaryEviction`
5. `verify031FrozenLRUAndGenerationBehavior`
6. `verify031DisabledCacheRemainsCompositeCorrect`
7. `verify032MixedSceneColdAndWarmCompositeEqualDirect`
8. `verify032CornerStraddleColdAndWarmCompositeEqualDirect`
9. `verify032EmptyColdAndWarmCompositeEqualDirect`
10. `verifyT2TypedChangesUseOneInvalidationChokePoint`
11. `verify033FrozenSeededInvalidationCompletenessCorpus`
12. `verifyT2PressureDropsFullTileCacheBeforeCheckpointsAndPreservesFloorPins`

## Complete executed supersession table

| Removed or replaced item | Disposition | Owner-visible successor / justification |
|---|---|---|
| Startup environment flag, `TileCacheStartupConfiguration`, `.featureDisabled`, renderer configuration, application startup read | Deleted | Unconditional `TileCompositeRenderer`; single 138-test population |
| Conditional T1/T2 `@Suite(.enabled(if: ...))` gates and helper boolean | Deleted | Same 12 tests run unconditionally in debug, release, ASan, and coverage |
| `CanvasView` standalone `CoreGraphicsRenderer` production wiring | Deleted | `TileCompositeRenderer.compositeDocumentCoordinates`; renderer-owned direct miss/OD-6 gesture rendering; VERIFY reference use only |
| `SceneBitmapCache.swift` retained full-scene bitmap mechanism | Deleted | Production tile cache; BENCH-1 typed-damage invalidation, BENCH-2 warm hits, BENCH-3 tile settle |
| `ViewportStripCache.swift`, strip counter, 2-device-pixel fixture | Deleted | Frozen 46,480×250 exposure corridor and exact render/hit traps per owner Option A |
| `forcedExposurePanRedrawsNonzeroStrips` | Deleted | `bench2bExposureCorridorRendersExactIndices` |
| `cachedPanMeetsInteractiveFrameBudget` | Deleted | BENCH-2 production tile-path p95 plus warm-hit trap |
| `revisionChangedTextMoveInvalidatesStripCacheAndMatchesDirectRender` | Deleted | VERIFY-033, typed invalidation suite, and production-coordinate composite equivalence |
| `unchangedRevisionMutationReproducesStripCacheStalenessOutsideReleaseWiring` | Deleted | No unsupported out-of-band retained-strip owner remains; all production edits flow through typed history damage |
| Old changed-mechanism owner-reference rows | Rebased in one provenance commit (`58e867b`) | Tile-production/corridor measurements from `5f18000`; 1.25 local ratio unchanged |

`DocumentLimits.maximumRetainedBitmapPixels` is not deleted: it is an
independently frozen document-limit policy and remains covered by VERIFY-008.

## Local benchmark result

| Scenario | Observed | Frozen target | Result |
|---|---:|---:|---|
| BENCH-1 drag | p95 4.970 ms | ≤16.7 ms | PASS |
| BENCH-2 pan | p95 0.111 ms | ≤16.7 ms | PASS |
| BENCH-2b corridor | p95 0.371 ms | ≤16.7 ms | PASS |
| BENCH-3 zoom | p95 6.564 ms | ≤33 ms | PASS |
| BENCH-3 settle | 12.842 ms | ≤100 ms | PASS |
| BENCH-5a undo/redo | p95 0.011 ms | ≤16.7 ms | PASS |
| BENCH-5b record | p95 0.853 ms | ≤1.0 ms local | PASS |
| BENCH-6 tile edit | p95 4.967 ms | ≤8.0 ms | PASS |

BENCH-6's 8.0 ms timing target remains blocking locally on owner-reference
hardware. Under the 2026-07-18 owner decision, hosted timing is informational;
the nonzero-hit and exact-damage-mapping assertions remain trapping in every
mode.

BENCH-2b setup rendered columns 0…3. Frames 1…360 rendered exactly
`(f+3,0)` and `(f+3,1)`; all other visible tiles were proven prior-rendered
hits; the final rendered-region count was 728.

## Local gates

| Gate | Result |
|---|---|
| Format; debug/release/macOS 15 build | PASS |
| Debug tests | PASS — 138/138 |
| Release tests | PASS — 138/138 |
| ASan | PASS — 136 main + 1 parser deadline + 1 geometry deadline = 138 |
| Coverage | PASS — 90.69% ≥55% |
| Dependency / clean room / symbol graph | PASS |
| Adversarial / golden / UI journey | PASS — 4/4; journey includes undo depth >30 and exact composite/direct spot check |
| Release assembly/signature/arm64 | PASS |
| Benchmarks and local 1.25 ratio | PASS |
| Peak memory settle | PASS — 461,799,424 B; 62,488,576 B exact headroom |
| Peak memory export | PASS — 469,942,272 B; 211,632,128 B exact headroom under export ceiling |
| Peak memory forced failure | PASS — gate rejected 1,037,467,648 B with nonzero exit |
| Full-app startup | PASS — p95 180.135 ms ≤2,000 ms; forced production canvas display |
| Reliability | PASS — 100 processes/10,000 codec round trips plus cold/warm production tile composite per process |
| Hosted eight-job manual dispatch | OPEN — operator action and evidence required |

## Frozen-value statement

No frozen VERIFY-029–033 value, OD-5–8 value, BENCH absolute target, schedule,
cache byte budget, tile size, corpus draw, memory ceiling, or ratio changed.
Every deletion performed by T3 appears in the supersession table above.
