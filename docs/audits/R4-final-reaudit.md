# R4 final re-audit

Re-audit date: 2026-07-13
Scope: all production modules, tests, package/CI configuration, release scripts,
verification records, benchmark evidence, and repository clean-room boundaries.

## Verdict

The product-code re-audit closes the eight pre-Phase-5 findings, and
VERIFY-001 through VERIFY-021 remain verified and frozen. BLOCK-002 and the
technical hosted requirements BLOCK-003–006 now pass: manually dispatched CI
#8 executed all eight jobs successfully at `94fb0f0`, and its hosted baseline,
artifacts and logs are retained by `88c3d58`. CI #1/#4/#5/#6 did not qualify;
CI #4's defects are corrected with a complete local battery at `ce3b4b3`, and
CI #5's cross-hardware baseline substitution is corrected in the hosted-only
workflow revisions `b57293c`/`59eec99`. CI #6's contended ASan deadline test is
corrected at `5d2ea50` with an exact-revision 89-plus-1 ASan pass and no numeric
gate change.
TN LEE completed the mandatory named-human three-file inspection on 2026-07-15
at 00:38 UTC+08:00. A6/A7 are accepted. Annotated Phase 5 entry tag
`pre-phase5-remediation` targets `6dea372fc90d7474dc1f5db0085dd03bfdc046ea`.

No new production mathematical behavior requires a verification-queue entry.
Numeric CI/test policies are documented separately and do not alter product
geometry or document semantics.

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
| Performance | Sealed BENCH-R3.5 definitions; BENCH-2b forces 360/360 nonzero strip redraws; qualifying hosted CI #8 | Local and hosted absolute targets pass. CI #8 bootstraps the provenance-matched hosted baseline; meaningful 1.25 enforcement begins next run. |
| Concurrency/memory | Swift 6 checks, ASan suite, decoded 50 MP PRD-derived RSS gates, forced-failure fixture, bounded budgets, sequential 100-process/10,000-cycle loop | Local and qualifying hosted gates pass with direct failure/PID evidence. Long-duration Instruments remains an operator check. |
| Architecture | Package dependency graph and forbidden-import script | Pass. No external package dependency or reverse core-to-UI dependency was found. |
| Public API/release | Symbol-graph emission, macOS 15 minimum-target compile, arm64 app assembly and hardened-runtime signing verification | Local checks pass. The release binary and plist declare minimum 15.0, and same-session codec/full-app runtime artifacts close BLOCK-002. CI signing is ad hoc; Developer ID/notarization requires owner credentials. |
| Verification protocol | Queue status review and process-violation record for VERIFY-019 | Pass. No pending/correction-required entry and no unqueued new mathematical reliance. |
| Clean-room | Build-input scan plus tracked-file-name check in `check-clean-room.sh` | Pass. Policy documentation retains the restricted artifact name solely to define and enforce the boundary; production/build inputs contain no reference or copy. |

## Risk and blocker disposition

The remaining operator boundaries are credentialed distribution signing/
notarization, manual assistive-technology and multi-display checks, and
long-duration Instruments observation. The technical hosted blockers are
closed. The required named-human artifact spot-check is recorded and final A7
acceptance is complete. None changes a frozen value or weakens an assertion boundary.

## Checkpoint requirements

The local battery is recorded in `docs/phase-4/R4-checkpoint.md`. R4 is closed;
the named-human A7 spot-check and annotated Phase 5 tag are both recorded.

Final verdict: **PASSED — PHASE 5 ENTRY AUTHORIZED**.
