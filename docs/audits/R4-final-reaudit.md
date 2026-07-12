# R4 final re-audit

Re-audit date: 2026-07-13
Scope: all production modules, tests, package/CI configuration, release scripts,
verification records, benchmark evidence, and repository clean-room boundaries.

## Verdict

No open correctness, security, architecture, verification, or clean-room finding
remains within the implemented R1–R4 scope. The eight pre-Phase-5 findings remain
closed, VERIFY-001 through VERIFY-021 are verified and frozen, and the R4 additions
introduce no new numeric behavior that requires a queue entry.

## Audit results

| Area | Evidence reviewed | Result / residual risk |
|---|---|---|
| Geometry and transforms | Frozen affine, Bézier, bounds, grouping, anchor, transform and snapping tests | Pass. Singular mappings fail without mutation. Floating-point tolerance is explicitly pinned where used. |
| Document integrity | Strict recursive validation, global IDs, count/byte/pixel ceilings, deterministic v4 codec and migrations | Pass. Unsupported future schema versions intentionally reject rather than guess. |
| Input security | Bounded reads, structural JSON/XML limits, active-content rejection, linked-path containment, image budgets, deterministic hostile corpora | Pass. Parsers run in-process, so deadlines are cooperative; bounded inputs and cancellation limit exposure, while process isolation remains outside the selected scope. |
| Persistence | Atomic replacement, backup, recovery, dirty-state and unsaved-operation tests | Pass. Filesystem and power-loss guarantees remain limited to the host filesystem semantics documented by the persistence layer. |
| Rendering | Visual-bounds containment, approved-image path, project-created composite golden, production benchmark paths | Pass. Golden tolerance permits small OS renderer drift by policy; it does not validate color-managed cross-display equivalence. |
| Interaction/UI | Undo/coalescing, direct anchors, grouping/compound invariance, transform gestures, snapping, text/image, zoom/pan, headless journey | Pass. Automated AppKit behavior does not replace operator checks for every hardware/input-device combination. |
| Accessibility | Deterministic document/layer/selection tree and application canvas metadata | Pass automated baseline. Manual VoiceOver interaction remains an explicit release-operator check. |
| Performance | BENCH-R3.5 accepted and sealed; BENCH-2b forces nonzero strip redraws | Pass on owner reference hardware. CI uses regression ratios because hosted-runner absolute timing is not a hardware-equivalent gate. |
| Concurrency/memory | Swift 6 checks, ASan suite, bounded history/cache/parser budgets, nightly repeated smoke path | Pass. Long-duration Instruments profiling remains an operator check rather than an automated claim. |
| Architecture | Package dependency graph and forbidden-import script | Pass. No external package dependency or reverse core-to-UI dependency was found. |
| Public API/release | Symbol-graph emission, macOS 13 compile fallback, arm64 app assembly and hardened-runtime signing verification | Pass. CI signing is ad hoc; Developer ID signing/notarization requires owner credentials. |
| Verification protocol | Queue status review and process-violation record for VERIFY-019 | Pass. No pending/correction-required entry and no unqueued new mathematical reliance. |
| Clean-room | Build-input scan plus tracked-file-name check in `check-clean-room.sh` | Pass. Policy documentation retains the restricted artifact name solely to define and enforce the boundary; production/build inputs contain no reference or copy. |

## Risk disposition

The remaining qualifications above are environmental or explicitly out of scope,
not accepted product defects: credentialed distribution signing/notarization,
manual assistive-technology and multi-display checks, long-duration Instruments
observation, and unsupported advanced features. None changes a frozen value or
weakens an assertion boundary.

## Checkpoint requirements

R4 closes only after the current tree passes debug and release builds/tests, ASan,
coverage, dependency and clean-room checks, release-app integrity, symbol-graph
emission, and the release benchmark. The checkpoint report must record the exact
commit and observed results.
