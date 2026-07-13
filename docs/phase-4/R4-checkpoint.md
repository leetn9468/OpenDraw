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
| `b01364b` | Corrected decoded-image memory gate, failure fixture, numeric-policy pinning, PID evidence and baseline rename | Complete local battery rerun; all artifacts except the later reliability log |
| `2884a54` | Reliability-script-only correction for external per-process wall duration | 100-process/10,000-cycle reliability gate rerun |
| Documentation closure commit | Project state, A6 package, audit/checkpoint/policy corrections and retained logs only | Outside `Sources`, `Tests`, `Package.swift`, scripts and CI build inputs; formatting/diff/link checks rerun |

The final implementation/gate revision is `2884a54`. Documentation commits do
not conceal later code/config changes.

## Exact local environment

- Model: MacBook Pro `MacBookPro18,2`
- SoC/RAM: Apple M1 Max, 64 GB
- OS: macOS 15.7.5 build 24G624, arm64
- Toolchain: Apple Swift 6.1.2 (`swiftlang-6.1.2.1.2`, clang 1700.0.13.5),
  Command Line Tools active; full Xcode is not selected
- Raw metadata: `artifacts/r4/environment.txt` and the header of each performance log

This is not macOS 15 runtime evidence.

## Final local battery

| Gate and exact command | Observed result | Artifact |
|---|---|---|
| `swift build -c debug`; `swift test` | PASS; 89 tests in 2.427 s | `debug-build.txt`, `debug-tests.txt` |
| `swift build -c release`; `swift test -c release` | PASS; 89 tests in 1.135 s | `release-build.txt`, `release-tests.txt` |
| `swift test --sanitize=address` | PASS; 89 tests in 11.317 s | `asan-tests.txt` |
| `swift test --enable-code-coverage`; `scripts/check-coverage.sh 55` | PASS; 87.93% versus 55% floor | `coverage-tests.txt`, `coverage-summary.txt` |
| `xcrun swift-format lint --recursive --strict Sources Tests Package.swift` | PASS | `format.txt` |
| `scripts/check-module-dependencies.sh`; `scripts/check-clean-room.sh` | PASS | `module-dependencies.txt`, `clean-room.txt` |
| `MACOSX_DEPLOYMENT_TARGET=15.0 swift build -c release` | PASS compile only; not runtime evidence | `macos15-deployment-build.txt` |
| `swift package dump-symbol-graph` plus emitted-file assertion | PASS | `symbol-graph.txt` |
| adversarial test filter | PASS; 512 mutations plus seven directly enumerated fixed cases | `adversarial-tests.txt` |
| golden filter | PASS | `golden-test.txt` |
| headless UI/accessibility filter | PASS | `ui-accessibility-tests.txt` |
| `scripts/build-release-app.sh` and `codesign -dvvv` | PASS; arm64, ad-hoc hardened runtime | `release-integrity.txt` |
| `scripts/check-startup-p95.sh 20 ...` | LOCAL PASS; nearest-rank p50 139.778, p95 147.748, max 162.816 ms; target 2,000 ms | `startup-p95.txt` |
| `scripts/check-peak-memory.sh ...` | LOCAL PASS; ten embedded 5 MP images decoded/retained/rendered; settle 214,433,792 bytes; PNG export 224,395,264 bytes | `peak-memory.txt` |
| `scripts/test-peak-memory-gate.sh ...` | PASS; forced 550 MiB extra allocation reaches 791,822,336 bytes and gate exits nonzero | `peak-memory-failure-fixture.txt` |
| `scripts/nightly-reliability.sh ...` | LOCAL PASS; sequential 100 distinct PIDs, 10,000 cycles, zero crashes/nonzero exits/timeouts/corruption, 5 s aggregate wall clock | `reliability-100x100.txt` |
| benchmark ratio gate and fixtures | LOCAL PASS; exact 1.25 boundary passes and 1.314801 fails | `benchmark-comparison.txt`, `benchmark-gate-fixtures.txt` |

## Fresh current-tree BENCH-R3.5 result

This fresh run uses the sealed BENCH-R3.5 scenario definitions and targets; old
measurements were not reused. Command: `scripts/run-render-benchmark.sh
artifacts/r4/render-benchmark.txt`. Configuration: release, 60 warm-up plus 300
measured frames per timed scenario, display sleep inhibited, production paths.

| Scenario | p50 | p95 | max / settle | Target | Result |
|---|---:|---:|---:|---:|---|
| BENCH-1 drag | 4.960 ms | 5.496 ms | 12.056 ms | p95 <= 16.7 ms | PASS |
| BENCH-2 pan | 0.088 ms | 0.108 ms | 0.180 ms | p95 <= 16.7 ms | PASS |
| BENCH-2b forced exposure | 5.375 ms | 5.950 ms | 23.265 ms | p95 <= 16.7 ms; nonzero strips every frame | PASS; source precondition covers 360/360 frames |
| BENCH-3 zoom | 2.399 ms | 8.953 ms | 10.186 ms | p95 <= 33 ms | PASS |
| BENCH-3 settle | — | — | 2.745 ms | <= 100 ms | PASS |
| BENCH-4 cold full redraw | — | — | 8.236 ms | informational | RECORDED |
| Warm full redraw | — | — | 4.510 ms | informational | RECORDED |

## Open blockers

- BLOCK-002: no qualifying runtime session from real macOS 15.x Apple Silicon
  exists. Frozen owner decision Option A requires both
  `scripts/nightly-reliability.sh
  artifacts/r4/macos15-reliability-100x100.txt` and
  `scripts/check-startup-p95.sh 20 artifacts/r4/macos15-startup-p95.txt` on the
  same machine/session; codec-only Option B was rejected.
- BLOCK-006: ratio enforcement exists, but this checkout has no Git remote and
  therefore no hosted macOS 15 run/baseline artifact or CI run URL. The committed
  baseline is truthfully labelled owner-reference, not hosted proof.
- BLOCK-003/004/005: corrected local gates pass, but their hosted-CI execution
  components remain open until the first push shows `startup-memory`,
  `nightly-reliability`, `benchmark`, and `adversarial-golden` green with a run
  URL and retained artifacts.
- BLOCK-012: `pre-phase5-remediation` is absent by rule while blockers remain.

Developer ID/notarization, manual VoiceOver, multi-display review and
long-duration Instruments checks remain explicit operator/environment boundaries;
they are not automated-pass claims.
