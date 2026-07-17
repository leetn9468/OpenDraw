# BENCH-R3.5 — Rendering Performance Specification

Owner-ratified 2026-07-12. This specification supersedes a whole-canvas,
single-frame interpretation of the 1,000-object Phase 1 gate.

## Preliminary audit

Commit `a4b20bd` only removed an ineffective compile-time ASan conditional
from the non-verification `swiftGeometryBenchmark`, leaving one 15-second smoke
ceiling. It changed no iteration count, geometry input, tolerance, expected
value, or `VERIFY-*` assertion boundary and is approved as-is.

## Conditions

- Fixed unique-ID, mixed-node 1,000-object reference document and reference artboard.
- Release build on the owner's arm64 Mac with display sleep inhibited.
- 60 warm-up frames followed by at least 300 measured frames.
- Report p50, p95, and maximum frame time; production rendering paths only.

| ID | Scenario | Absolute target | Mechanism |
|---|---|---|---|
| BENCH-1 | Continuously drag one selected object | p95 ≤ 16.7 ms | Damage is old ∪ new visual bounds; clean regions come from cache. |
| BENCH-2 | Constant-velocity viewport pan | p95 ≤ 16.7 ms | Retained cache redraws newly exposed strips only. |
| BENCH-2b | Forced-exposure pan at 2× zoom | p95 ≤ 16.7 ms; ≥1 strip every frame | Viewport-sized retained cache shifts clean pixels and redraws exposed strips. |
| BENCH-3 | Continuous pinch/scroll zoom | p95 ≤ 33 ms; settled full-quality frame ≤ 100 ms | Scaled cached bitmap during gesture; precise redraw on settle. |
| BENCH-4 | Cold full redraw | Informational only | Always record; explicitly exempt from 16.7 ms. |

## Ordered implementation and exit criteria

1. Typed change-stream damage tracking (`none`, `rects`, `full`) must make BENCH-1 pass.
2. Spatial-index viewport culling is required for large-document headroom.
3. Incremental retained-bitmap redraw must make BENCH-2 pass; scaled-cache zoom must make BENCH-3 pass.
4. Per-object/tile caching is conditional: implement only if BENCH-1/2/3 still miss after step 3, otherwise defer to Phase 5 and record that decision.

Every completed step is a separate commit whose message records BENCH-1/2/3
p50, p95, and max plus the BENCH-4 cold number. Numeric damage-merge or zoom-
bucket heuristics require a pre-authored verification entry. CI uses ratio-based
regression thresholds; the absolute targets bind on the reference hardware.

## R3 checkpoint report

Include the four benchmark tables for every completed step, the step where
each target first passed, the step-4 decision, and the `a4b20bd` audit above.

## Current production-path result

Measured 2026-07-12 on owner reference hardware `MacBookPro18,2` (arm64),
release build, 60 warm-up frames and 300 measured frames:

| Scenario | p50 | p95 | max / settle | Result |
|---|---:|---:|---:|---|
| BENCH-1 drag | 4.937 ms | 5.324 ms | 5.565 ms | PASS |
| BENCH-2 pan | 0.087 ms | 0.109 ms | 0.148 ms | PASS |
| BENCH-2b forced exposure | 5.368 ms | 5.831 ms | 7.628 ms | PASS; strips > 0 every frame |
| BENCH-3 zoom | 2.379 ms | 8.853 ms | 10.443 ms; settle 2.778 ms | PASS |
| BENCH-4 cold-open | — | — | 9.359 ms | informational |
| Warm full redraw | — | — | 4.491 ms | informational |

The retained full-artboard budget is `67,108,864` pixels. BENCH-2 is the pure
blit case because the 800×500 reference artboard fits that budget. BENCH-2b
uses a viewport-sized 800×500 retained bitmap at 2× zoom: the 1,600×1,000
visible traversal is strictly larger than the cached extent, and a two-pixel
pan per frame is asserted to increase the production strip-redraw counter.

The former 4.203 ms value was a warm full redraw after all scenario warm-ups,
not a cold open. BENCH-4 now runs before any scenario or renderer warm-up in a
fresh harness process; its 9.359 ms value includes first-use text/render setup.
The separately labelled warm full redraw is 4.491 ms.

All binding targets, including forced-exposure BENCH-2b, pass. Per-object/tile
caching is therefore definitively deferred to Phase 5 under the owner-ratified
conditional step-4 rule.

The approximately 41 ms audit baseline used the pre-R1.5 duplicate-ID sample
and is not directly comparable to the current deterministic unique-ID results.

## 2026-07-17 tile-production supersession note

Historical results and mechanism descriptions above are intentionally
preserved. The owner-selected Option A corridor supersedes only the BENCH-2b
mechanism; its 16.7 ms p95 target and 60+300 schedule are unchanged.

| Historical mechanism | Production successor |
|---|---|
| 2-device-pixel pan through `ViewportStripCache`, its strip counter, and the 1,000-node fixture | 46,480×250-unit exposure corridor at zoom 2/backing scale 1; 9,100 strictly interior nodes; setup columns 0…3; frame f renders exactly `(f+3,0)` and `(f+3,1)` |
| `SceneBitmapCache` for BENCH-1/2/3 | `TileCompositeRenderer`; BENCH-1 uses typed-damage invalidation, BENCH-2 is warm-hit dominated, BENCH-3 enters the renderer-owned direct gesture path and settles through tiles |

The corridor harness traps any unexpected render, zero-render frame, or hit
from a never-rendered region. The local owner-reference baseline was rebased
only for changed-mechanism rows at `58e867b`, with source provenance
`5f18000fcab25d2fa7f52e81dd5f33900604fe15`. Absolute targets were not moved.
