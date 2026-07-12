# ADR-011 — OpenDraw platform support

- Status: Accepted
- Date: 2026-07-12
- Decision owner: Project owner

## Decision

OpenDraw supports Apple Silicon (`arm64`) only, with macOS 13.0 as the minimum
deployment target. Intel, Windows, and Linux are out of scope. Swift Package Manager
continues to declare `.macOS(.v13)`. No universal or `x86_64` release configuration
may be introduced without a superseding owner-approved ADR.

## Consequences

- Source APIs must be available on macOS 13 or protected by availability checks and
  tested fallbacks.
- CI must test macOS 13 arm64 and the latest arm64 environment when runners exist.
  Until a macOS 13 arm64 hosted runner is available, deployment-target compilation
  plus a real-hardware macOS 13 smoke test is a mandatory release gate.
- Existing Intel requirements and risks are superseded; historical audit text remains
  unchanged as evidence of the state it audited.
