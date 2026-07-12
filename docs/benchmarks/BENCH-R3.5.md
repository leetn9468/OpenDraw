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
