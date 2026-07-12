# R4 checkpoint report

Checkpoint date: 2026-07-13
Tested implementation commit: `14de9b3`

## Result

R4 is complete. R4.1 adversarial parsing, R4.2 golden rendering, R4.3 UI and
accessibility coverage, R4.4 CI/release integrity, and R4.5 re-audit all pass.
VERIFY-001 through VERIFY-021 remain verified and frozen, with no open queue
entry and no new mathematical surface requiring verification.

## R4 commits

| Work | Commit |
|---|---|
| Deterministic parser corpus and deadline harness | `a627b17` |
| Composite project-created golden and tolerance policy | `53b0aff` |
| Headless UI journey and accessibility tree | `9a2e0e8` |
| CI coverage, reliability, benchmark and signed-release gates | `546dd29` |
| Final re-audit, clean-room gate and CI command corrections | `14de9b3` |

## Checkpoint gate

| Gate | Result |
|---|---|
| Debug build and tests | Pass; 88/88 in 2.468 s |
| Release build and tests | Pass; 88/88 in 1.151 s |
| AddressSanitizer tests | Pass; 88/88 in 11.218 s |
| Line coverage | Pass; 87.60% versus 55% floor |
| Strict Swift format | Pass |
| Module dependency direction | Pass |
| Clean-room build-input and tracked-artifact scan | Pass |
| macOS 13 deployment-target release compile | Pass |
| Public symbol-graph emission | Pass |
| Release app assembly/signature/arm64 integrity | Pass |
| Application smoke | Pass; 100 deterministic native round trips |

The adversarial corpus executes 256 fixed-seed native mutations and 256 SVG
mutations plus fixed hostile classes through production parser paths. The golden
test uses only project-created content and the documented pixel tolerance.

## Release benchmark

| Scenario | p50 | p95 | max | Target | Result |
|---|---:|---:|---:|---:|---|
| BENCH-1 drag | 4.954 ms | 5.519 ms | 7.961 ms | p95 <= 16.7 ms | Pass |
| BENCH-2 pan | 0.089 ms | 0.110 ms | 0.140 ms | p95 <= 16.7 ms | Pass |
| BENCH-2b forced exposure | 5.330 ms | 5.936 ms | 10.161 ms | p95 <= 16.7 ms | Pass |
| BENCH-3 continuous zoom | 2.469 ms | 8.978 ms | 10.611 ms | p95 <= 33 ms | Pass |

BENCH-3 settle was 2.791 ms against the 100 ms target. Informational BENCH-4
cold-open was 12.051 ms; warm full redraw was 4.512 ms. Per-object/tile caching
remains deferred by the sealed BENCH-R3.5 decision.

## Re-audit disposition

All eight pre-Phase-5 findings are closed. The final re-audit found no open
in-scope correctness, security, architecture, verification, or clean-room issue.
Credentialed Developer ID signing/notarization, manual VoiceOver and multi-display
checks, and long-duration Instruments observation remain clearly identified
operator/environment gates and are not represented as automated passes.
