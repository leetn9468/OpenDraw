# Architecture decision records

## ADR-001 — Swift toolchain

Accepted: Swift 6 language mode, Swift Package Manager, macOS 15 minimum. C++ is
prohibited unless a measured isolated operation fails its budget and an ADR defines
a narrow C ABI, ownership, sanitizer, and licensing boundary.

## ADR-002 — Precision and tolerance

Accepted: document geometry uses 64-bit `Double`. Exact equality is reserved for
stored identity/property checks. Geometry algorithms receive explicit document-space
tolerances. Pointer hit tolerance is expressed in screen points and divided by zoom.
Non-finite values are rejected at mutation/import boundaries.

## ADR-003 — Scene representation and ownership

Accepted: retained, value-semantic document snapshots with stable UUID-backed IDs.
Layers own ordered objects; objects own geometry/style values. Resource tables will
own shared assets by stable ID. UI selection references IDs, never view pointers.

## ADR-004 — Rendering

Accepted for foundation: stateless translation from retained model to Core Graphics
immediate drawing. Backend types remain inside `CanvasRender`. Display lists/caches
may be added behind that boundary after profiling; Metal requires a superseding ADR.

## ADR-005 — UI and text

Accepted for foundation: AppKit composition shell and custom `NSView` canvas, with
standard controls for accessibility. Core Text is isolated in `TextEngine`. All
AppKit access is MainActor-isolated; shaping/model work may move to worker tasks.

## ADR-006 — Native format

Provisional: versioned package with canonical sorted-key JSON plus assets, decoded
only by `DocumentFormats`. Current JSON codec proves deterministic model round trip;
atomic package writing, migrations, limits, unknown fields, and assets are Phase 3
work before the format is user-facing.

## ADR-007 — Undo and transactions

Accepted foundation: command applies to a candidate value snapshot; success stores
the former snapshot, failure stores nothing. Undo/redo history is session-only and
branching clears redo. Phase 3 may replace full snapshots internally while preserving
observable atomic semantics.

## ADR-008 — Concurrency

Accepted: AppKit and window/view state stay on MainActor. Model snapshots are
`Sendable`; background render/import work receives immutable snapshots and returns
results. No shared mutable global document state. Cancellation and generation IDs
must prevent stale asynchronous results from replacing current state.

## ADR-009 — Dependencies

Accepted: Apple system frameworks and Swift standard/runtime only for the foundation.
Every third-party package needs exact-version pinning, SPDX/license review, notices,
security ownership, and a written reason. Do not introduce dependencies to save a
small amount of original code.

## ADR-010 — Test pyramid

Accepted: Swift Testing for unit/property-sample/integration/performance checks,
bitmap golden tests with explicit thresholds when fixtures stabilize, XCUITest for
critical UI journeys once an Xcode app project exists, parser fuzzing in Phase 3,
and manual accessibility/input hardware matrices where automation is insufficient.
