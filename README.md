# OpenDraw

A native vector graphics editor for macOS, built in Swift for Apple Silicon.

> **Status: early development.** The architecture, document model, and
> verification infrastructure are complete and audited; the user interface is
> currently a minimal functional shell. If you're here expecting an
> Illustrator replacement today, come back later. If you're here for a
> rigorously verified vector graphics core, read on.

## What it is

OpenDraw is a from-scratch, clean-room vector editor. No inherited codebases,
no dependency takeovers. The current build supports:

- Bézier paths (pen tool with smooth/corner anchors, mirrored handles,
  open and closed paths)
- Rectangles, ellipses, and text objects
- Direct selection: anchor and direction-handle editing with document-space
  transform composition
- Grouping, ungrouping, and compound paths (make/release)
- Layers with lock/hide, precise hit testing, and a spatial index
- Bounded snapshot history (30-entry undo)
- Raster image placement with strict resource limits and an approved-image
  rendering pipeline
- Native JSON document format with atomic, durable saves, autosave, and
  rolling backups
- SVG import with hardened parser limits; PNG export
- Angle and axis snapping with pinned, verified tie-breaking rules

## Requirements

- macOS 15.0 (Sequoia) or later
- Apple Silicon

Both constraints are deliberate (recorded architecture decisions ADR-1/ADR-011):
one platform, one architecture, no legacy surface.

## Building

```sh
git clone https://github.com/leetn9468/OpenDraw.git
cd OpenDraw
scripts/build-release-app.sh
open dist/OpenDraw.app
```

Tests: `swift test`. The full local gate battery (sanitizers, coverage,
benchmarks, memory ceilings, reliability loops) lives in `scripts/`.

## How this project is built — and verified

OpenDraw is developed by AI coding agents under human architectural direction,
with an unusual constraint: **nothing ships on self-reported results.** Every
piece of production math goes through a pre-authored verification queue
(worked examples pinned before implementation, including degenerate cases,
with two independent AI reviewers required to agree), and an independent
cross-verification layer recomputes all numeric claims rather than trusting
them.

The pre-release audit ran under a zero-deferral policy — every finding of
every severity fixed, no accepted-risk register, no conditional passes — and
closed through 12 hard blockers with committed, reproducible evidence:

- 90 tests green across debug, release, and AddressSanitizer configurations
- 21 frozen verification entries (VERIFY-001–021) covering transforms, Bézier
  evaluation, bounds, fill rules, snapping, and zoom math
- Deterministic adversarial corpus (512 mutations, pinned seed) against the
  JSON and SVG parsers
- Golden-image rendering suite with explicit tolerances
- Enforced CI gates for peak memory, startup p95, benchmark absolute targets,
  and crash-free reliability (100 clean process launches, 10,000 native
  round trips)
- Runtime proof on real minimum-OS hardware, not just deployment-target
  compilation

The full audit trail — anchors, blockers, owner decisions, and the evidence
map — is in `docs/PROJECT_STATE.md` and `artifacts/r4/`. The audited baseline
is tagged `pre-phase5-remediation`.

Hosted CI runs on GitHub's `macos-15` runners. Benchmark absolute targets are
blocking everywhere; ratio-based regression detection is blocking on
reference hardware and informational on shared runners (measured 2–3× hosted
hardware variance makes fixed-ratio gates non-discriminating there — the
comparison data is still published with every run).

## Roadmap (Phase 5)

- Delta / command-inverse history (replacing bounded snapshots)
- Per-object and tile-based render caching
- A real user interface
- Notarized distribution
- PDF import/export (capability decision pending)

## License

License to be determined. Until a LICENSE file is present, all rights
reserved; the source is public for transparency and review.
