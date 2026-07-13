# Phase 4 verification, hardening, and release review

Status: **R4 checkpoint rejected; Phase 5 blocked by external proof gaps**
Review date: 2026-07-13

## Completed work

| Area | Acceptance evidence |
|---|---|
| R4.1 adversarial parsing | Fixed-seed 256-case native and 256-case SVG mutation corpora, fixed hostile classes, cancellation and production-path deadline harness |
| R4.2 golden rendering | Project-created composite golden covering gradients, opacity, transforms, dash/cap/join behavior, text baseline and z-order, with a documented tolerance policy |
| R4.3 UI/accessibility | Headless create/draw/style/transform/save/reopen/export journey and a stable accessibility-tree baseline for document, layers and selection |
| R4.4 CI/release | Local gates implemented and passing; real macOS 13 runtime and hosted benchmark proof remain open |
| R4.5 re-audit | Product-code closure matrix passes; acceptance blockers are tracked in `docs/PROJECT_STATE.md` |

The permanent suite contains 89 tests. Coverage is 87.93%, above the enforced
55% line-coverage floor. VERIFY-001 through VERIFY-021 are `VERIFIED` and frozen.

## Release-policy boundaries

- CI is arm64 macOS 15 with a macOS 13 deployment-target compile fallback.
- Intel remains out of scope per ADR-011.
- The signed CI artifact uses an ad-hoc hardened-runtime signature; distribution
  identity signing and notarization require owner-held credentials.
- Manual VoiceOver, multi-display, and long-duration Instruments observation are
  operator release checks. Automated accessibility structure and repeated smoke
  cycles prevent those external checks from being silently represented as complete.

## Exit review

| Criterion | Result |
|---|---|
| Deterministic adversarial corpus and deadline/cancellation behavior | Pass |
| Composite project-owned golden and explicit tolerance | Pass |
| Critical headless UI journey and accessibility tree | Pass |
| Local coverage, dependency, API, benchmark, sanitizer, and release integrity gates | Pass |
| All pre-Phase-5 audit findings closed | Pass |
| Clean-room implementation boundary | Pass; CI enforcement added |
| Verification queue has no open entries | Pass |
| Real macOS 13 Apple Silicon 100-launch runtime proof | **Open — BLOCK-002** |
| Hosted execution of memory/startup/reliability jobs | **Open — BLOCK-003/004/005** |
| Hosted-CI benchmark baseline and run artifact | **Open — BLOCK-006** |

Therefore R4/A7 is not accepted, A8 remains blocked, and the
`pre-phase5-remediation` tag does not exist.
