# Tile-render caching T2

Date: 2026-07-17
Freeze basis: `790c013`
Accepted T1 basis: `fba6372` (`0a9918b` evidence)
Producing build-input revision: `da6b14ca7809fb9b2e1328832fc7a2dc7967eb97`

## Result

T2 is complete behind the existing default-off tile flag. Live transform and
anchor frames now publish typed conservative damage without adding history
entries or revisions; cancellation publishes restoration damage. A tile
renderer can synchronously subscribe to that same change stream. Its sole
damage mutation point classifies `.none`, mapped `.rects`, and lazy-full
`.full`/unknown damage, while zoom or backing-scale changes bump a generation
only when the value changes.

The 64-step VERIFY-033 walk reproduces the frozen 205-draw distribution before
executing mutations. Every full-canvas composite, including the corpus-end
auto-commit, matched direct rendering with zero differing pixels.

BENCH-6 runs on the exact 1,000-root reference scene with an explicitly enabled
fully warm tile cache. Its pinned sequence alternates `+1/-1` x translations
on interior path node 84. All 360 frames trap unless they retain nonzero hits
and render exactly the frozen damage mapping. Final p95 was 4.658 ms against
the immutable 8.0 ms target, leaving 3.342 ms headroom.

The memory gate now retains 512 independently backed full tiles, exactly
134,217,728 cache bytes, concurrently with the settled render, P-FLOOR history,
and nine checkpoints. The measured settle peak was 453,869,568 bytes, with
exact headroom 70,418,432 bytes under the unchanged 524,288,000-byte ceiling.

## Test populations

- Flag OFF: 128 executed tests = the untouched 127-test population plus
  `verifyT2TransformGesturePublishesFrameCommitAndCancellationDamage`.
- Flag ON: 140 executed tests = the OFF population, nine accepted T1 tests,
  and the three new flag-only T2 tests for invalidation wiring, VERIFY-033,
  and memory-pressure ordering.

The raw Swift Testing summary includes flag-skipped tests. Executed counts in
`artifacts/phase5/tile-t2/test-counts.txt` are reconciled from passing test
records.

## Scope boundary

Production rendering remains direct: `CanvasView` still owns and invokes
`CoreGraphicsRenderer`, and no production caller references
`TileCompositeRenderer`. BENCH-1/2/2b/3/5 retain their existing direct code;
only BENCH-6 constructs the tile renderer, using explicit configuration rather
than reading the process flag. BENCH-2b's implementation and T3 corridor
supersession were not touched. Frozen VERIFY values and policies were not
changed; only implementation references were added.

Complete evidence and the S1-S6 revision map are under
`artifacts/phase5/tile-t2/`.
