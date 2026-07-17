# Tile-render caching T1

Date: 2026-07-17  
Freeze basis: `790c013`  
Producing build-input revision: `fba637212174fd4c9fe6a047b7a340077e06a22d`

## Result

T1 is implemented behind `OPENDRAW_TILE_CACHE=1`, default off. The new entry
point provides the frozen device-pixel grid, conservative damage mapping,
exact-budget LRU container, and cold/warm tile-composite harness. It calls the
existing `CoreGraphicsRenderer` once per miss under a full-scene tile clip and
integer device-pixel translation. Tiles remain pure derived bitmaps; there are
no pins or asset owners.

The application reads the flag once during startup but does not route any
production caller to `TileCompositeRenderer` in T1. `CanvasView.draw` remains
on its prior direct-render call in both flag states, so the 127-test flag-off
population is unchanged. The flag-on population is 136: the same 127 tests
plus nine T1 tests.

## Permanent tests

- VERIFY-029: `verify029FrozenDamageMappingExamples` and
  `verify029FrozenConservativeInkCases`.
- VERIFY-030: `verify030FrozenGridGeometryAndByteCosts`.
- VERIFY-031: `verify031FrozenCapacityAndExactBoundaryEviction`,
  `verify031FrozenLRUAndGenerationBehavior`, and
  `verify031DisabledCacheRemainsCompositeCorrect`.
- VERIFY-032: `verify032MixedSceneColdAndWarmCompositeEqualDirect`,
  `verify032CornerStraddleColdAndWarmCompositeEqualDirect`, and
  `verify032EmptyColdAndWarmCompositeEqualDirect`.

Every cold and warm comparison reported zero differing pixels. The frozen
limits remained 4,000, 2,621, and 655 for the three pinned scenes; the
disabled-cache correctness fixture also reported zero.

## Scope boundary

No invalidation/change-stream wiring, live-gesture damage publication,
VERIFY-033 deterministic corpus, BENCH-2b tile-render counting, benchmark
source, or peak-memory scenario extension is present in T1. BENCH-1/2/2b/3/5
and the pre-T1 memory scenario ran flag-off and unchanged. T2 follows only
after T1 acceptance.

## Evidence

The complete local gate evidence, retained first flag-on ASan contention
attempt, test-count reconciliation, static scope proof, and revision map are
under `artifacts/phase5/tile-t1/`.

## Final local gate table

| Gate | Flag | Result |
|---|---|---|
| Format / debug / release / macOS 15 deployment | — | PASS |
| Debug tests | OFF | PASS — 127 existing tests |
| Debug tests | ON | PASS — 136 tests |
| Release tests | OFF | PASS — 127 existing tests |
| Release tests | ON | PASS — 136 tests |
| AddressSanitizer | OFF | PASS — 126 main + 1 isolated deadline test |
| AddressSanitizer | ON | PASS — 134 main + 1 isolated deadline + 1 isolated geometry test |
| Coverage | ON | PASS — 89.24% >= 55% |
| Dependency / clean-room / symbol graph | — | PASS |
| Adversarial / golden / UI-accessibility | OFF | PASS — 2 / 1 / 2 |
| Release assembly and signature | OFF | PASS |
| Unchanged BENCH-1/2/2b/3/5 absolute + ratios | OFF | PASS |
| Unchanged peak-memory settle / export | OFF | PASS — 287,096,832 / 295,911,424 B |
| Unchanged peak-memory forced failure fixture | OFF | PASS — rejected 863,109,120 B |
| Full-app startup | OFF | PASS — p95 175.583 ms <= 2,000 ms |
| Reliability | OFF | PASS — 100 launches / 10,000 round trips |
