# ADR-011 — OpenDraw platform support

- Status: Accepted — revised 2026-07-13
- Date: 2026-07-12
- Decision owner: Project owner

## Original decision — 2026-07-12

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

## Revision — 2026-07-13

> **2026-07-13 — ADR-1 REVISED.** Minimum supported platform is raised from
> macOS 13.0 to **macOS 15.0 (Sequoia)**, Apple Silicon only (unchanged).
> Rationale: macOS 13 has exited Apple's security-update window; no macOS 13
> hardware is available or worth provisioning for a pre-release product; the
> owner's reference machine (MacBookPro18,2, macOS 15.x) becomes the
> minimum-OS runtime-proof environment. The 2026-07-13 Option A decision
> (BLOCK-002 requires BOTH codec reliability AND full-app startup runs at the
> minimum OS) is **retained in substance** and retargeted from macOS 13 to
> macOS 15; it is superseded only in its OS number, not its scope.

The active package floor is `.macOS(.v15)`. The release Info.plist declares
`LSMinimumSystemVersion` 15.0, and hosted jobs are pinned to `macos-15`. This
revision changes only the platform floor; it does not authorize new APIs,
refactoring, or changes to any frozen constant, tolerance, ceiling, benchmark
target, or VERIFY entry.
