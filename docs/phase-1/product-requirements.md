# Product requirements document

## Product goal

Build an original desktop vector editor for macOS that lets illustrators,
design students, and technically minded hobbyists create and revise modest
vector artwork without depending on a subscription product. The MVP is an
open-source learning project intended to become a useful personal tool. It is
not a clone and does not promise full parity or proprietary-file compatibility.

## Primary users and workflows

| User | Primary workflow |
|---|---|
| Design learner | Create a document, draw shapes and Bézier paths, style and arrange them, save, reopen, and export SVG/PNG |
| Hobbyist illustrator | Select and directly edit anchors, group objects, use layers, align objects, and undo experiments |
| Contributor/tester | Open deterministic sample documents and verify editing and file round trips |

## Supported environment

- macOS 13 Ventura or newer.
- Apple Silicon (`arm64`) and Intel (`x86_64`).
- Keyboard, pointing device, and standard Retina/non-Retina displays.
- English UI for MVP. Unicode text content is supported within the limits in
  `BEH-TEXT-001`; localization is post-MVP.

## MVP boundary

The MVP provides one rectangular artboard per document; paths and rectangles,
ellipses, and lines; object and anchor selection; solid RGB fill/stroke;
transform, arrange, group, layers, alignment; undo/redo; plain text objects;
linked or embedded raster placement; an original native save format; SVG import
and export for a documented subset; PNG export; and basic clipboard operations.

Gradients, CMYK workflows, compound paths, transparency editing, printing,
scripting, plug-ins, PDF/EPS and proprietary native formats are not MVP promises.

## Functional requirements

The normative functional requirements are the rows marked `MVP Required` in
the capability matrix. Each maps to at least one `BEH-*` behavior and `AT-*`
acceptance test.

## Quality and success metrics

Measurements use a release build on the oldest supported OS and the baseline
test Mac: 8 GB RAM, four logical CPU cores, SSD, and a 1920×1080 display. Phase 2
will nominate actual hardware before benchmarks become release gates.

| Metric | MVP target |
|---|---|
| Cold startup | Document-ready in ≤2.0 s at p95 over 20 runs |
| Common pointer interaction | Input-to-visible-update ≤50 ms at p95 |
| Rendering | ≤16.7 ms/frame at p95 while panning the representative document; no frame >100 ms |
| Representative document | 1 artboard, 1,000 objects, 10,000 anchors, 10 raster images totaling 50 MP |
| Memory | ≤500 MB resident after representative document settles; ≤650 MB during PNG export |
| Reliability | 100 consecutive automated smoke runs with zero crashes or hangs |
| Native round trip | Reopen preserves all supported semantic properties and stacking order |
| SVG round trip | Supported subset remains visually equivalent within 1 pixel at 2× rasterization; unsupported features produce warnings, not silent loss |
| Undo | Every MVP mutation is reversible and redoable until a new mutation branches history |

## Constraints

- The document model must not depend on AppKit view objects.
- All mutations pass through an undoable command or transaction boundary.
- Imports are untrusted and must have size/depth limits and controlled errors.
- Dependencies require an approved license entry before use.
- The legacy decompiler export is never a build input or design source.

## Non-goals

- Pixel-identical reproduction of any legacy UI.
- Binary or proprietary native-document compatibility.
- Professional prepress, color-management, collaboration, animation, or web app.
- Matching undocumented quirks of another product.
