# Behavioral specification catalog

These specifications describe observable behavior only. Unless stated otherwise,
invalid numeric input leaves the document unchanged, displays a concise original
error, and does not add an undo entry. Every successful mutation marks the
document dirty and participates in undo/redo.

## BEH-DOC-001 — Create a document

- Input: positive finite width and height, unit, optional name.
- Transition: create one visible, unlocked layer and one empty artboard.
- Output: editable window at fit-to-artboard zoom; document is initially unsaved.
- Edge cases: reject zero, negative, non-finite, or implementation-limit dimensions.
- Acceptance: AT-001.

## BEH-CANVAS-001 — Navigate the canvas

- Zoom changes the display scale without changing document coordinates.
- Pan changes the viewport only. Objects may exist outside the artboard but are
  excluded from artboard export.
- Zoom is clamped to a documented safe range and centered on the pointer when
  invoked by pointer gesture.
- Acceptance: AT-002.

## BEH-SEL-001 — Select objects

- Clicking the topmost unlocked visible hit object replaces selection.
- Shift-click toggles a hit object. Clicking empty space clears selection.
- A marquee selects intersecting objects; locked/hidden objects are ineligible.
- Acceptance: AT-003.

## BEH-SEL-002 — Select path components

- Direct selection exposes anchors and direction handles for eligible paths.
- Moving selected anchors retains their order; moving a handle changes its
  adjacent curve without moving the anchor.
- An empty-component click clears component selection, not the owning object.
- Acceptance: AT-004.

## BEH-PATH-001 — Create and edit cubic paths

- Click adds a corner anchor; drag adds an anchor with direction handles.
- Clicking the first anchor closes a path with at least two existing anchors.
- Escape finishes an open path. Delete removes selected anchors; a path with too
  few anchors is removed according to its type.
- Undo while drawing removes only the last committed anchor/operation.
- Acceptance: AT-005.

## BEH-SHAPE-001 — Create primitives

- Drag creates a rectangle, ellipse, or line from press to release.
- Shift constrains rectangles/ellipses to equal dimensions and lines to 45° steps.
- Zero-area drags create no object and no undo entry.
- Acceptance: AT-006.

## BEH-STYLE-001 — Apply fill and stroke

- A selected object accepts fill of none or solid sRGB; stroke additionally has
  nonnegative width, cap, join, miter limit, and nonnegative dash values.
- Odd dash arrays repeat to form an even pattern. All-zero dash arrays are solid.
- Applying a style to multiple selected objects is one undoable transaction.
- Acceptance: AT-007.

## BEH-XFORM-001 — Transform objects

- Move, rotate, and nonzero scale operate around the displayed reference point.
- A multi-selection transforms as one set while preserving relative placement.
- Non-finite values and singular numeric transforms are rejected without mutation.
- Acceptance: AT-008.

## BEH-ALIGN-001 — Align objects

- Two or more selected objects align left/right/top/bottom or horizontal/vertical
  center using their visual bounds. Alignment preserves stacking order.
- If fewer than two eligible objects exist, the command is disabled.
- Acceptance: AT-009.

## BEH-LAYER-001 — Manage layers and order

- Documents always contain at least one layer. Objects belong to exactly one layer.
- Hidden layers do not render/export; locked layers render but cannot be edited.
- Reordering deterministically changes drawing and hit-test order. Deleting the
  final layer is rejected; deleting a nonempty layer requires confirmation.
- Acceptance: AT-010.

## BEH-GROUP-001 — Group objects

- Group requires at least two objects and preserves their visible order.
- Normal selection treats a group as one object; explicit entry selects children.
- Ungroup restores children at the group's position with visual transforms intact.
- Acceptance: AT-011.

## BEH-HISTORY-001 — Undo and redo

- Each completed user gesture or confirmed panel edit is one logical history item.
- Undo reverses exactly the latest item; redo reapplies it. A new edit after undo
  discards the redo branch. Save records a clean checkpoint without clearing history.
- Acceptance: AT-012.

## BEH-COLOR-001 — Use sRGB colors and swatches

- Channels are stored deterministically in a documented sRGB representation.
- A swatch has stable identity, unique display name, and color. Editing a swatch
  updates objects linked to it; copied literal colors are unaffected.
- Acceptance: AT-013.

## BEH-TEXT-001 — Create plain point text

- Clicking creates point text; Unicode scalar input is retained.
- User chooses an available font, size, and solid color. Missing fonts use a visible
  fallback and produce a nonblocking warning without changing stored font identity.
- MVP has no text-on-path, area text, rich runs, or outline conversion.
- Acceptance: AT-014.

## BEH-IMAGE-001 — Place raster images

- PNG and JPEG may be embedded or linked. Placement preserves pixel aspect ratio.
- Missing linked images show a placeholder and warning; the document remains open.
- Malformed, oversized, or unsupported images fail without partial objects.
- Acceptance: AT-015.

## BEH-FILE-001 — Save and reopen

- Save writes a versioned original format atomically through a temporary sibling.
- Reopen restores supported objects, IDs, order, styles, geometry, resources, and
  document settings. Unknown newer data is either preserved when safe or warned;
  unsupported major versions do not partially open.
- Acceptance: AT-016.

## BEH-SVG-001 — Import and export the SVG subset

- Subset: one viewport, groups, paths, rect/ellipse/line, solid sRGB fill/stroke,
  basic transforms, simple text, and embedded/relative PNG/JPEG images.
- Import resolves only safe local relative resources by explicit permission; no
  network fetch, scripts, event handlers, or external entity processing.
- Unsupported visible features produce a structured warning. Export is deterministic.
- Acceptance: AT-017.

## BEH-PNG-001 — Export PNG

- Export rasterizes the artboard at a positive finite scale with transparent or
  chosen solid background. Objects outside the artboard are clipped.
- Existing destination replacement requires standard confirmation; failure leaves
  the prior file intact where the platform permits.
- Acceptance: AT-018.

## BEH-CLIP-001 — Copy, cut, and paste

- Copy exposes an internal lossless flavor and SVG when representable. Text editing
  uses plain text. Cut is copy plus one undoable deletion.
- Paste prefers the internal flavor from this app, otherwise safe SVG, image, or
  plain text. Repeated paste offsets objects predictably and retains order.
- Acceptance: AT-019.

## BEH-A11Y-001 — Operate with accessibility support

- Controls have accessible labels, roles, values, keyboard focus, and non-color-only
  state cues. Core document commands have keyboard equivalents.
- Canvas selection is announced, and reduced-motion/high-contrast settings are honored.
- Acceptance: AT-020.
