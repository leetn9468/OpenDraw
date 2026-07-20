# UI redesign U3-B execution record

Validated implementation revision:
`a9f219c6b3f94befa55d7c5eba9409f4b80bd934`.

## VERIFY-034 agreement and execution

U3-B agrees with VERIFY-034. `EditorDocument.visualBounds(for:)` supplies the
same stroke-inclusive bounds used by the shipped Align Left path. The flipped
AppKit canvas makes document Y increase downward, so top is `minY` and bottom
is `maxY`. The frozen checkpoint is
`0a9619515d97226d6c0e531b3a319df8c583bafb`; implementation follows in
`f3181ef54f865fa23eb58e72f0a552b1d253dea8`.

`CompositeSceneCommands.align` unions all selected visual bounds, derives the
six raw-Double targets without rounding, skips exact zero deltas, and emits one
ordered composite of existing transform value swaps. A single object or an
already-aligned selection therefore reaches the existing identity-elision
boundary and changes neither undo nor redo depth. The pre-existing shipped-left
test is unmodified and passes.

## Delivered surface

- Object menu and Inspector expose Left, Center, Right, Top, Middle, and
  Bottom. Their accessibility nodes are permanent shell-contract fixtures.
- Selection bounds, handles, rotation control, anchors, direction handles,
  marquee, snap guides, and delta badge use only `Theme` colors, fonts,
  radii, and metrics. Interaction hit radii remain 6, 7, and 8 points.
- Shift scale constrains aspect, Option scale grows symmetrically, Shift rotate
  additively enables the existing `pi/12` snap, Option handle drag breaks a
  smooth anchor through an anchor-slice value swap, and marquee activation is
  delayed until three screen points.
- Text objects edit through an overlaid AppKit field editor. Escape, Return,
  focus loss, and canvas click-away commit through the existing text-content
  value swap. Empty new text cancels creation without history. The Inspector's
  Text section is visible only for a single text selection.

## Supersession record

| Retired/replaced item | Disposition | Successor |
|---|---|---|
| Create Text `NSAlert` flow | Removed; no silent deletion | In-place `NSTextField` editor plus `InPlaceTextEditing`; permanent empty-new and existing-value-swap round-trip fixture |
| Five disabled align Inspector controls | Replaced | Enabled six-control generalized VERIFY-034 path, including shipped Left |
| Axis-specific align target calculation, including averaged object centers | Generalized after shipped-left compatibility proof | Combined visual-bounds target shared by all six axes; the existing shipped-left test passes unmodified |
| U3-A C2 open deviation | Closed as directive erratum | VERIFY-013 remains `pi/12`; `pi/8` remains its half-away tie input; no frozen change |

## Scope proofs

Canonical render goldens cover document pixels rather than AppKit selection
chrome; both remained byte-identical. `RenderBenchmark` depends on headless
renderer and command modules, not `VectorFoundryApp`, `CanvasView`, or `Theme`,
so the heavier chrome is absent from every benchmark scenario. No benchmark
target, baseline, frozen value, or render math changed.

The reconciled population is 146: U3-A's 140 plus six permanent U3-B tests.
The runner executes 144 main tests followed by the two policy-isolated
wall-clock deadline tests. Detailed names and gate observations are retained
under `artifacts/phase5/ui-b/`.

## Closure state

All automated and local performance gates pass. TN LEE granted owner visual
acceptance on 2026-07-19. Manually dispatched CI #32
<https://github.com/leetn9468/OpenDraw/actions/runs/29686626995> verified exact
revision `8d604586406565718a1d2146c91214742a6ecc7d`, event
`workflow_dispatch`, and eight of eight successful jobs. The verbatim hosted
BENCH table and retained artifacts are in `artifacts/phase5/ui-b/hosted/`.
U3-B and the UI redesign are **DELIVERED**.
