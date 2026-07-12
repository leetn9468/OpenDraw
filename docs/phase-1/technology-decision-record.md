# Technology decision record

Status values: `Accepted` means the Phase 1 baseline; `Provisional` requires the
listed Phase 2 proof before broad implementation.

## TDR-001 — Platform target

- Status: Accepted; owner reconfirmation requested.
- Decision: macOS 13+, Apple Silicon and Intel.
- Reason: AppKit/Core Graphics provide a coherent native foundation; macOS 13
  keeps deployment practical while retaining still-used Intel Macs.
- Consequence: no Windows/Linux MVP and CI must build both architectures.

## TDR-002 — Language and build

- Status: Accepted.
- Decision: Swift 6 language mode, current supported Xcode, Swift Package Manager.
- Reason: native framework access, strong value semantics, testable packages, no
  mandatory external dependency.
- Gate: warnings-as-errors build and test on both architectures.

## TDR-003 — UI and accessibility

- Status: Provisional.
- Decision: AppKit window/view/controller shell with custom `NSView` canvas;
  standard AppKit controls for panels and menus.
- Gate: keyboard traversal, VoiceOver labels/selection announcements, Retina and
  non-Retina rendering, IME input, and responsive resize proof-of-concepts.

## TDR-004 — Rendering and geometry

- Status: Provisional.
- Decision: retained independent document model; Core Graphics rendering into an
  AppKit canvas. Double-precision document coordinates and affine transforms;
  screen-space hit tolerance converted at current zoom.
- Gate: representative 1,000-object benchmark meets frame/memory targets and
  visually stable cubic curves at 1%–6,400% zoom.

## TDR-005 — Text

- Status: Provisional.
- Decision: Core Text for shaping/layout and system font discovery; store Unicode
  content plus requested PostScript font name, size, and paint.
- Gate: Latin, Arabic, Devanagari, CJK, emoji, RTL, combining marks, missing fonts,
  and IME fixtures render and reopen consistently.

## TDR-006 — Persistence and interchange

- Status: Provisional.
- Decision: a versioned original document package containing canonical JSON and
  embedded assets; atomic replacement. SVG 1.1 documented subset for interchange;
  PNG via ImageIO/Core Graphics.
- Gate: deterministic serialization, unknown-field strategy, hostile-input limits,
  100-cycle native round trip, and golden SVG/PNG fixture suite.

## TDR-007 — Testing

- Status: Accepted.
- Decision: Swift Testing for unit/integration/performance tests; XCUITest only for critical
  user journeys; deterministic render fixtures with perceptual/pixel thresholds.
- Consequence: model, commands, formats, and renderer interfaces live in testable
  packages independent of application windows.

## TDR-008 — Foundation validation decision

- Status: Provisional umbrella decision.
- Decision: Swift/AppKit/Core Graphics is approved for Phase 2 spikes, not yet for
  unrestricted feature implementation.
- Pass conditions: TDR-003 through TDR-006 gates pass on the oldest supported OS,
  no critical accessibility or text blocker exists, and performance targets are met
  or a documented optimization path is demonstrated.
- Failure response: write a superseding TDR comparing Metal-backed rendering,
  alternate text integration, or a revised deployment target before proceeding.

## Initial dependency/license policy

| Dependency | Role | License/terms | Approval |
|---|---|---|---|
| Swift standard library | Language runtime | Apple Swift license / Apache 2.0 components | Approved subject to shipped-notice review |
| AppKit, Core Graphics, Core Text, ImageIO | Platform/UI/render/text/image | Apple SDK agreement; system frameworks | Approved for macOS distribution subject to final distribution review |
| Swift Testing/XCUITest | Testing | Swift toolchain and Apple SDK terms | Approved for development/testing |

Third-party packages are not approved by default. Before addition, record exact
version, source, SPDX identifier, notice obligations, security owner, and reason.
Copyleft or source-available dependencies require explicit project-owner review.
