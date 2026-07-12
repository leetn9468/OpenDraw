# MVP acceptance-test outline

Each scenario is implementation-independent. Automation level is assigned during
Phase 2: model/format behavior should be unit or integration tested; visible input
and accessibility journeys may use XCUITest plus focused manual review.

## Core scenarios

| ID | Given / When / Then |
|---|---|
| AT-001 | Given the new-document dialog, when valid dimensions are confirmed, then one empty artboard and unlocked layer exist; invalid dimensions create nothing. |
| AT-002 | Given an object at known coordinates, when the canvas pans and zooms, then document coordinates and saved output do not change and pointer-centered zoom keeps the pointed location stable. |
| AT-003 | Given overlapping, locked, hidden, and visible objects, when click/Shift-click/marquee are used, then only eligible objects enter selection in the specified manner. |
| AT-004 | Given a cubic path, when an anchor and then one handle move, then anchor order remains stable and only the expected adjacent geometry changes; undo restores it. |
| AT-005 | Given an empty document, when three anchors are created and the second is dragged, then one ordered open cubic path exists; undo removes only the third anchor and redo restores it. |
| AT-006 | Given each primitive tool, when normal, Shift-constrained, and zero-area drags occur, then correct geometry is created for the first two and no object/history item for the last. |
| AT-007 | Given three selected shapes, when fill, stroke, cap, join, and dash are applied, then all render identically to the values and one undo restores every prior style. |
| AT-008 | Given two selected objects, when moved, scaled, and rotated about a reference point, then their relative layout is preserved and inverse undo returns exact model values. |
| AT-009 | Given three objects, when each alignment mode is invoked, then their requested visual-bound edges/centers coincide without reordering. |
| AT-010 | Given two layers with objects, when visibility, lock, and order change, then render, export, hit testing, and editing eligibility match BEH-LAYER-001 and round-trip. |
| AT-011 | Given two transformed objects, when grouped, entered, edited, and ungrouped, then selection semantics change as specified and visible placement/order is preserved. |
| AT-012 | Given a sequence covering every MVP mutation, when undo reaches the initial state and redo reaches the final state, then model hashes match; a branched edit clears redo; save checkpoint tracks dirty state. |
| AT-013 | Given linked-swatch and literal-color objects, when the swatch changes, then only linked objects update and native reopen preserves that distinction. |
| AT-014 | Given multilingual/RTL/emoji text and an unavailable font, when edited, displayed, saved, and reopened, then content is preserved, fallback is visible, and the missing-font warning is nonblocking. |
| AT-015 | Given valid embedded/linked PNG/JPEG plus missing, malformed, and oversized cases, when placed/reopened, then valid images retain aspect/transform and invalid cases are safe and diagnosable. |
| AT-016 | Given a document containing every MVP object/property, when saved atomically and reopened 100 times, then canonical semantic snapshots match and interrupted-save fault injection preserves the previous file. |
| AT-017 | Given approved SVG subset and hostile/unsupported fixtures, when imported/exported, then subset visuals meet tolerance, output is deterministic, unsupported features warn, and scripts/network/entities never execute. |
| AT-018 | Given inside/outside-artboard artwork, when PNG exports at 1× and 2× with transparent/solid backgrounds, then dimensions, clipping, colors, and destination failure behavior are correct. |
| AT-019 | Given internal objects, external SVG/image, and plain text clipboard data, when copy/cut/paste occurs, then the safest highest-fidelity supported flavor is used and cut is one undoable mutation. |
| AT-020 | Given keyboard-only, VoiceOver, reduced-motion, and increased-contrast settings, when the primary workflow runs, then controls and selection are perceivable and operable without pointer or color-only cues. |

## Release-level scenarios

| ID | Scenario and pass condition |
|---|---|
| AT-PERF-001 | Cold-start, interaction, frame-time, and memory measurements meet the PRD targets on nominated baseline hardware. |
| AT-ROBUST-001 | 100 automated smoke runs complete with no crash/hang and all malformed-input fixtures return controlled errors. |
| AT-E2E-001 | Create document → draw/edit/style → layer/group/align → add text/image → save/reopen → SVG and PNG export completes with expected semantic and golden outputs. |

## Coverage rule

No `CAP-*` item may remain `MVP Required` without a linked `BEH-*` and `AT-*`.
An acceptance test passes only when its assertions, fixtures, environment, and
observed result are recorded; a manual visual impression alone is insufficient.
