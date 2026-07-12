# Prioritized capability matrix

| ID | Capability | Classification | MVP slice or rationale | Behavior | Acceptance |
|---|---|---|---|---|---|
| CAP-001 | Document creation/settings | MVP Required | New, named/unnamed, dimensions, units | BEH-DOC-001 | AT-001 |
| CAP-002 | Artboard/canvas | MVP Required | One rectangular artboard; pan/zoom; off-artboard objects | BEH-CANVAS-001 | AT-002 |
| CAP-003 | Selection | MVP Required | Click, marquee, additive selection | BEH-SEL-001 | AT-003 |
| CAP-004 | Direct selection | MVP Required | Anchors and handles on one or more paths | BEH-SEL-002 | AT-004 |
| CAP-005 | Pen/Bézier editing | MVP Required | Open/closed cubic paths; add/move/delete anchors | BEH-PATH-001 | AT-005 |
| CAP-006 | Primitive shapes | MVP Required | Rectangle, ellipse, straight line | BEH-SHAPE-001 | AT-006 |
| CAP-007 | Fill/stroke | MVP Required | Solid RGB, none, width, cap, join, dash | BEH-STYLE-001 | AT-007 |
| CAP-008 | Transformations | MVP Required | Move, scale, rotate; numeric and interactive | BEH-XFORM-001 | AT-008 |
| CAP-009 | Alignment | MVP Required | Edge/center alignment to selection bounds | BEH-ALIGN-001 | AT-009 |
| CAP-010 | Layers/object order | MVP Required | Create/rename, visibility/lock, reorder | BEH-LAYER-001 | AT-010 |
| CAP-011 | Grouping | MVP Required | Group/ungroup and nested selection | BEH-GROUP-001 | AT-011 |
| CAP-012 | Compound paths | Post-MVP | Boolean/fill-rule UX requires separate design | — | — |
| CAP-013 | Undo/redo | MVP Required | All document mutations; clean/dirty state | BEH-HISTORY-001 | AT-012 |
| CAP-014 | Color models/swatches | MVP Required | sRGB and document swatches; no CMYK | BEH-COLOR-001 | AT-013 |
| CAP-015 | Gradients | Post-MVP | Solid paint validates style architecture first | — | — |
| CAP-016 | Transparency | Post-MVP | Object opacity and blend modes deferred | — | — |
| CAP-017 | Text/font handling | MVP Required | Plain point text, font/size/color, fallback | BEH-TEXT-001 | AT-014 |
| CAP-018 | Raster placement | MVP Required | PNG/JPEG linked or embedded; transform | BEH-IMAGE-001 | AT-015 |
| CAP-019 | Native save/reopen | MVP Required | Versioned original package/JSON format | BEH-FILE-001 | AT-016 |
| CAP-020 | SVG import/export | MVP Required | Documented basic SVG subset | BEH-SVG-001 | AT-017 |
| CAP-021 | PNG export | MVP Required | Artboard rasterization at chosen scale | BEH-PNG-001 | AT-018 |
| CAP-022 | Clipboard | MVP Required | Internal objects plus SVG/plain-text flavors | BEH-CLIP-001 | AT-019 |
| CAP-023 | Printing | Explicitly Out of Scope | Exported output can be printed externally | — | — |
| CAP-024 | Scripting | Explicitly Out of Scope | Security/API stability cost exceeds MVP value | — | — |
| CAP-025 | Plug-ins | Explicitly Out of Scope | ABI and trust model intentionally deferred | — | — |
| CAP-026 | PDF/EPS import/export | Research Needed | Licensing, fidelity, and framework behavior | — | — |
| CAP-027 | Proprietary file formats | Explicitly Out of Scope | No implicit native compatibility | — | — |
| CAP-028 | Accessibility | MVP Required | Keyboard access, labels, focus, contrast | BEH-A11Y-001 | AT-020 |
| CAP-029 | Autosave/recovery | Post-MVP | Native manual save is MVP requirement | — | — |
| CAP-030 | Multiple artboards | Post-MVP | Single artboard keeps coordinates/files simple | — | — |
