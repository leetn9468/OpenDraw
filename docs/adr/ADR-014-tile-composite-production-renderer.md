# ADR-014 — Tile composite is the production renderer

Date: 2026-07-17  
Status: Accepted for local delivery; hosted closure pending

## Decision

`TileCompositeRenderer` is the sole production rendering entry point.
`CanvasView` composites document tiles in document coordinates, subscribes the
renderer to `DeltaCommandHistory` once, and uses the same renderer across
command commits, undo/redo, live gestures, pan, zoom, backing-scale changes,
document replacement, and memory pressure.

The renderer owns `CoreGraphicsRenderer`. That direct renderer is not a
standalone production path: it renders whole scene objects into a clipped tile
on cache misses and supplies the OD-6 direct continuous-zoom gesture phase.
VERIFY-032/033 may also instantiate it as an independent reference renderer.

## Consequences

- A 256×256-device-pixel, exact-byte LRU cache is always present and remains
  bounded by 134,217,728 bytes.
- Typed damage has one invalidation choke point. Zoom/backing-scale changes
  bump the generation; equal zoom is a no-op.
- `CanvasView` drops pure derived tile data before history checkpoints under
  memory pressure.
- BENCH-1/2/3 measure production tiles; BENCH-3 gestures remain direct inside
  the tile renderer and settle through tiles.
- The former startup gate, retained-scene bitmap cache, and viewport-strip
  cache have no production or test owner and are deleted.

## Evidence

The frozen arithmetic and correctness suites, 64-step VERIFY-033 corpus,
end-to-end undo-depth>30 UI journey, exact BENCH-2b corridor assertions, and
local gate evidence are mapped in `docs/phase-5/tile-cache-T3.md` and
`artifacts/phase5/tile-t3/revision-map.md`.
