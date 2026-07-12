# Phase 2 foundation index

Status: **Implemented; local Apple Silicon gates pass, external hardware gates pending**  
Baseline date: 2026-07-12

## Deliverables

- [Architecture overview and module rules](architecture.md)
- [Architecture decision records](architecture-decisions.md)
- [Technical spike report](technical-spikes.md)
- [Test strategy](test-strategy.md)
- [Developer setup](developer-setup.md)
- [Dependency and license inventory](dependencies.md)

## Exit review

| Exit criterion | Result | Evidence |
|---|---|---|
| Clean checkout builds/runs with documented commands | Pass locally | `swift build`, `swift run VectorFoundry` |
| Tests run locally and in CI | Pass locally; CI configured | Swift Testing suites, `.github/workflows/ci.yml` |
| Sample path renders and hit-tests | Pass | `CanvasRenderTests`, `GeometryTests`, application shell |
| Dependency violations detectable/reviewable | Pass | package target graph and `scripts/check-module-dependencies.sh` |
| Document core has no concrete UI dependency | Pass | `DocumentModel` imports only `EditorCore`, `Geometry`, Foundation |
| Stack passes identified risk spikes | Conditional | Apple Silicon automated gates pass; pressure input, VoiceOver and physical-display checks require target hardware/manual execution |

Phase 3 may begin for core/document vertical slices. Accessibility claims remain
blocked until the external gates in `technical-spikes.md` are recorded. Intel was
later placed permanently out of scope by ADR-011. Spikes are test fixtures and
evidence, not production feature promises.
