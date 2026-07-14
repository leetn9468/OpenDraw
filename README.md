# OpenDraw

OpenDraw is an original, open-source clean-room vector editor for macOS.

Phase 1 defines the product, Phase 2 the foundation, Phase 3 the editing slice,
and Phase 4 verification/release hardening. No legacy decompiler output belongs here.

## Current status

- Phase: 4 — verification remediation; **Phase 5 entry blocked**
- Product posture: open-source learning project with a usable personal-tool MVP
- Platform: macOS 15 or newer, Apple Silicon (`arm64`) only
- Foundation: Swift 6, AppKit, Core Graphics, Core Text, Swift Package
  Manager, Swift Testing
- Compatibility: SVG 1.1 subset for interchange; deterministic OpenDraw v4 native format

Local R4 gates and the real minimum-OS macOS 15 runtime proofs pass. Project
acceptance still requires a manually dispatched all-eight-jobs-green hosted run
and hosted benchmark baseline/comparison artifact.
See [the authoritative project state](docs/PROJECT_STATE.md). No Phase 5 entry
tag exists while those blockers remain.

Phase reviews: [Phase 1](docs/phase-1/README.md), [Phase 2](docs/phase-2/README.md),
[Phase 3](docs/phase-3/README.md), and [Phase 4](docs/phase-4/README.md).

## Clean-room rule

Restricted research artifacts must not be copied into, included by, linked to, or
used as implementation source for this repository. See
[docs/phase-1/clean-room-policy.md](docs/phase-1/clean-room-policy.md).
