# TEXT-DEFECT-001 — conservative Core Text ink bounds

Date: 2026-07-17  
Investigated against: `52546b2`

## Result

**Current release UI reachability: NOT-REACHABLE.** The zero-area default
`layoutBounds` defect was real, and a stale strip bitmap is reproducible if a
caller mutates text while reusing the same cache revision. The current app does
not put `ViewportStripCache` or `SceneBitmapCache` in its drawing path, however:
`CanvasView.draw` invokes `CoreGraphicsRenderer` directly. The benchmark and
tests are the only current cache callers. A committed edit also changes the
history revision, causing `ViewportStripCache` to discard its previous image and
redraw the complete viewport.

This is not a claim that future damage-driven caching was safe. Live gesture
updates currently mutate the history document without advancing a revision or
publishing damage. Phase 5 T2 must land the predeclared damage-bearing gesture
change publication before a cache is connected to that path.

## Reproduction retained

Three permanent tests capture the distinction:

- `defaultAndFallbackTextInkIsContainedByVisualBoundsPlusOnePixel` failed
  before the fix with 2,668 out-of-bound rendered-pixel reports.
- `unchangedRevisionMutationReproducesStripCacheStalenessOutsideReleaseWiring`
  demonstrates stale output when the cache revision contract is deliberately
  violated.
- `revisionChangedTextMoveInvalidatesStripCacheAndMatchesDirectRender` proves
  the correctly revision-keyed move is pixel-identical to direct rendering.

Pre-fix focused result: bounds containment failed; revision-changed cache/direct
comparison passed. Post-fix focused result: all five text-bound and cache tests
pass.

## Fix

`TextShaper.conservativeBounds` unions Core Text typographic bounds with
`CTLineGetImageBounds`, including overhangs and fallback runs. `TextObject` then
unions that result with its authoring `layoutBounds`; `SceneNode.localBounds`
and `visualBounds` use the computed conservative result.

The derived bound is not serialized. The v4 schema and canonical document bytes
therefore remain unchanged, and decoded legacy/default zero-area layout bounds
receive correct ink coverage at use time. If shaping cannot produce a trusted
bound, `conservativeInkBounds` is nil so a damage-driven caller can classify it
as unknown rather than trust a partial rectangle.

## Verification

- Strict recursive swift-format lint: pass.
- Module dependency check: pass.
- Focused TEXT-DEFECT tests: 5/5 pass.
- Debug suite: 127/127 pass.
- Release suite: 127/127 pass.
- ASan suite: 126 general + 1 deadline-isolated test pass.
- Golden rendering, golden boundary policy, VERIFY-015, and typed
  `.none != .full`: pass without golden regeneration.
- Canonical v4 golden bytes and historical migration/round-trip tests: pass.
- Frozen release benchmark: pass. Measured p95 values were BENCH-1 5.357 ms,
  BENCH-2 0.111 ms, BENCH-2b 5.975 ms, BENCH-3 9.113 ms, BENCH-5a 0.010 ms,
  and BENCH-5b 0.830 ms; BENCH-3 settle was 2.946 ms.

No golden fixture or frozen numeric value changed.
