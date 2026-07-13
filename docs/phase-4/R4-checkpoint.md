# R4 checkpoint — owner rejection remediation

Status: **FAILED — external proof blockers remain**

The prior checkpoint claim at `c5072e0` was rejected. This report supersedes it;
no conditional pass and no Phase 5 entry tag is claimed.

## Revision accounting

| Revision | Content | Verification accounting |
|---|---|---|
| `52c3295` | Memory/startup/reliability/benchmark gates, CI jobs, representative memory harness, expanded 14-group UI journey | Complete initial battery and all raw artifacts |
| `f854389` | Script-only correction so Swift toolchain metadata captures stderr and is retained correctly | Startup, memory, 100-process reliability, fresh benchmark, ratio gate and failure fixture rerun |
| `6de4bce` | Test-only reproducible mutation failure-index logging | Debug/release/ASan/coverage and adversarial filters rerun |
| Documentation closure commit | Project state, A6 package, audit/checkpoint/policy corrections and retained logs only | Outside `Sources`, `Tests`, `Package.swift`, scripts and CI build inputs; formatting/diff/link checks rerun |

The final implementation/gate revision is `6de4bce`. Documentation commits do
not conceal later code/config changes.

## Exact local environment

- Model: MacBook Pro `MacBookPro18,2`
- SoC/RAM: Apple M1 Max, 64 GB
- OS: macOS 15.7.5 build 24G624, arm64
- Toolchain: Apple Swift 6.1.2 (`swiftlang-6.1.2.1.2`, clang 1700.0.13.5),
  Command Line Tools active; full Xcode is not selected
- Raw metadata: `artifacts/r4/environment.txt` and the header of each performance log

This is not macOS 13 runtime evidence.

## Final local battery

| Gate and exact command | Observed result | Artifact |
|---|---|---|
| `swift build -c debug`; `swift test` | PASS; 88 tests in 2.421 s | `debug-build.txt`, `debug-tests.txt` |
| `swift build -c release`; `swift test -c release` | PASS; 88 tests in 1.113 s | `release-build.txt`, `release-tests.txt` |
| `swift test --sanitize=address` | PASS; 88 tests in 11.270 s | `asan-tests.txt` |
| `swift test --enable-code-coverage`; `scripts/check-coverage.sh 55` | PASS; 87.93% versus 55% floor | `coverage-tests.txt`, `coverage-summary.txt` |
| `xcrun swift-format lint --recursive --strict Sources Tests Package.swift` | PASS | `format.txt` |
| `scripts/check-module-dependencies.sh`; `scripts/check-clean-room.sh` | PASS | `module-dependencies.txt`, `clean-room.txt` |
| `MACOSX_DEPLOYMENT_TARGET=13.0 swift build -c release` | PASS compile only; not runtime evidence | `macos13-deployment-build.txt` |
| `swift package dump-symbol-graph` plus emitted-file assertion | PASS | `symbol-graph.txt` |
| adversarial test filter | PASS; 512 mutations plus seven directly enumerated fixed cases | `adversarial-tests.txt` |
| golden filter | PASS | `golden-test.txt` |
| headless UI/accessibility filter | PASS | `ui-accessibility-tests.txt` |
| `scripts/build-release-app.sh` and `codesign -dvvv` | PASS; arm64, ad-hoc hardened runtime | `release-integrity.txt` |
| `scripts/check-startup-p95.sh 20 ...` | PASS; p50 140.815, p95 151.433, max 163.861 ms; target 2,000 ms | `startup-p95.txt` |
| `scripts/check-peak-memory.sh ...` | PASS; settle 9,109,504 bytes <= 500 MiB; PNG export 19,939,328 bytes <= 650 MiB | `peak-memory.txt` |
| `scripts/nightly-reliability.sh ...` | PASS; 100 clean processes, 10,000 cycles, zero crashes/nonzero exits/timeouts/corruption, 3 s | `reliability-100x100.txt` |
| benchmark ratio gate and failure fixture | PASS locally; 1.25 threshold enforced and 1.314801 fixture fails | `benchmark-comparison.txt`, `benchmark-gate-fixtures.txt` |

## Fresh current-tree BENCH-R3.5 result

This fresh run uses the sealed BENCH-R3.5 scenario definitions and targets; old
measurements were not reused. Command: `scripts/run-render-benchmark.sh
artifacts/r4/render-benchmark.txt`. Configuration: release, 60 warm-up plus 300
measured frames per timed scenario, display sleep inhibited, production paths.

| Scenario | p50 | p95 | max / settle | Target | Result |
|---|---:|---:|---:|---:|---|
| BENCH-1 drag | 4.764 ms | 5.056 ms | 5.508 ms | p95 <= 16.7 ms | PASS |
| BENCH-2 pan | 0.087 ms | 0.108 ms | 0.181 ms | p95 <= 16.7 ms | PASS |
| BENCH-2b forced exposure | 5.203 ms | 5.827 ms | 8.853 ms | p95 <= 16.7 ms; nonzero strips every frame | PASS; 360/360 strip frames |
| BENCH-3 zoom | 2.408 ms | 8.763 ms | 10.214 ms | p95 <= 33 ms | PASS |
| BENCH-3 settle | — | — | 2.833 ms | <= 100 ms | PASS |
| BENCH-4 cold full redraw | — | — | 8.166 ms | informational | RECORDED |
| Warm full redraw | — | — | 4.724 ms | informational | RECORDED |

## Open blockers

- BLOCK-002: no 100-launch log from real macOS 13.x Apple Silicon exists.
  The ready command is `scripts/nightly-reliability.sh
  artifacts/r4/macos13-reliability-100x100.txt` on that machine.
- BLOCK-006: ratio enforcement exists, but this checkout has no Git remote and
  therefore no hosted macOS 15 run/baseline artifact or CI run URL. The committed
  baseline is truthfully labelled owner-reference, not hosted proof.
- BLOCK-012: `pre-phase5-remediation` is absent by rule while blockers remain.

Developer ID/notarization, manual VoiceOver, multi-display review and
long-duration Instruments checks remain explicit operator/environment boundaries;
they are not automated-pass claims.
