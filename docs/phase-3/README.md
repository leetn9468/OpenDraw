# Phase 3 vertical-slice review

Status: **Implemented and verified**  
Baseline date: 2026-07-12

## Delivered

- Adaptive cubic subdivision/flattening, conservative/tight bounds, curve and
  anchor hit-testing, closure and fill rules, explicit tolerance handling.
- Versioned document model with stable IDs, layers, transforms, styles and
  invariant validation independent of AppKit.
- Atomic candidate-state commands, undo/redo, drag coalescing, dirty/save point,
  failure rollback and a configurable 100-entry history ceiling.
- Core Graphics scene traversal, fill/stroke/cap/join/dash, viewport clip/pan/zoom,
  selection overlays, backing-scale boundary and damage-region representation.
- Pen, rectangle, ellipse, constraint and snapping state machines.
- Atomic native save/load and deterministic SVG export.
- Interactive application shell: pen double-click completes a path; rectangle and
  ellipse drag; toolbar save/export dialogs; original sample curve.

## Evidence

The Phase 3 gate passed formatting, dependency-boundary checks, 19 automated tests,
and release build before Phase 4 work began. Relevant suites cover geometry,
history rollback/coalescing, tool states, deterministic/atomic persistence, SVG
escaping, rendering and Unicode shaping.

## Known usability limits at this boundary

The shell is an engineering vertical slice, not the full Phase 1 MVP. It supports
open/save/export, undo/redo, selection drag, an accent-style action and unsaved-close
protection. Direct anchor dragging, a full properties panel, recent files and the
complete accessibility-polished workflow still need product UI integration. No
claim is made that every Phase 1 acceptance journey is complete.

See [native format](native-format.md) and the Phase 4 expansion review.
