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
| `f6ec81a` | Owner-directed minimum-platform revision to macOS 15 in package, release plist and CI; no production source, test, frozen value or VERIFY change | Complete local battery rerun; all retained R4 artifacts regenerated |
| `b6cee43` | Portable POSIX shell assertions, manually dispatched reliability lane, and Node.js 24 action majors after CI #1 | Affected dependency, clean-room, benchmark/ratio/fixture, peak-memory/failure-fixture, and 100×100 reliability gates rerun |
| `ce3b4b3` | Eliminate the durable-writer stale-descriptor cleanup race and make the unchanged 550 MiB forced-memory allocation incompressible after CI #4 | Complete local battery rerun; focused pre/post regression and 30-run release stress retained |
| `8da5ee8` | Retain CI #4 logs, corrective battery, stress evidence, and triage report | Evidence only; no later build-input change |
| Documentation closure commit | Project state, A6 package, audit/checkpoint/policy corrections and retained logs only | Outside `Sources`, `Tests`, `Package.swift`, scripts and CI build inputs; formatting/diff/link checks rerun |

The current final build-input and complete-battery revision is `ce3b4b3`.
Frozen targets, ceilings, tolerances, retry policy, workflow semantics, and
VERIFY-001–021 are unchanged. Evidence commit `8da5ee8` retains the exact
corrective battery and CI #4 triage.

## Exact local environment

- Model: MacBook Pro `MacBookPro18,2`
- SoC/RAM: Apple M1 Max, 64 GB
- OS: macOS 15.7.5 build 24G624, arm64
- Toolchain: Apple Swift 6.1.2 (`swiftlang-6.1.2.1.2`, clang 1700.0.13.5),
  Command Line Tools active; full Xcode is not selected
- Raw metadata: `artifacts/r4/environment.txt` and the header of each performance log

This is the owner-approved real minimum-OS runtime-proof environment.

## Final local battery

| Gate and exact command | Observed result | Artifact |
|---|---|---|
| `swift build -c debug`; `swift test` | PASS; 90 tests in 2.409 s | `debug-build.txt`, `debug-tests.txt` |
| `swift build -c release`; `swift test -c release` | PASS; 90 tests in 1.109 s | `release-build.txt`, `release-tests.txt` |
| `swift test --sanitize=address` | PASS; 90 tests in 11.082 s | `asan-tests.txt` |
| `swift test --enable-code-coverage`; `scripts/check-coverage.sh 55` | PASS; 87.94% versus 55% floor | `coverage-tests.txt`, `coverage-summary.txt` |
| `xcrun swift-format lint --recursive --strict Sources Tests Package.swift` | PASS | `format.txt` |
| `scripts/check-module-dependencies.sh`; `scripts/check-clean-room.sh` | PASS | `module-dependencies.txt`, `clean-room.txt` |
| `MACOSX_DEPLOYMENT_TARGET=15.0 swift build -c release` | PASS compile only; not runtime evidence | `macos15-deployment-build.txt` |
| `swift package dump-symbol-graph` plus emitted-file assertion | PASS | `symbol-graph.txt` |
| adversarial test filter | PASS; 512 mutations plus seven directly enumerated fixed cases | `adversarial-tests.txt` |
| golden filter | PASS | `golden-test.txt` |
| headless UI/accessibility filter | PASS | `ui-accessibility-tests.txt` |
| `scripts/build-release-app.sh` and `codesign -dvvv` | PASS; arm64, ad-hoc hardened runtime | `release-integrity.txt` |
| `scripts/check-startup-p95.sh 20 ...` | PASS at `ce3b4b3`; nearest-rank p50 137.502, p95 143.960, max 170.319 ms; target 2,000 ms | `macos15-startup-p95.txt`, `startup-p95.txt` |
| `scripts/check-peak-memory.sh ...` | PASS at `ce3b4b3`; ten embedded 5 MP images decoded/retained/rendered; settle 214,564,864 bytes; PNG export 224,821,248 bytes | `peak-memory.txt` |
| `scripts/test-peak-memory-gate.sh ...` | PASS at `ce3b4b3`; unchanged forced 550 MiB allocation reaches 791,560,192 bytes and the unchanged 500 MiB gate exits nonzero | `peak-memory-failure-fixture.txt`, `memory-fixture-stress.txt` |
| `scripts/nightly-reliability.sh ...` | PASS at `ce3b4b3`; sequential 100 distinct PIDs, 10,000 cycles, zero crashes/nonzero exits/timeouts/corruption, 4 s aggregate wall clock | `macos15-reliability-100x100.txt`, `reliability-100x100.txt` |
| benchmark ratio gate and fixtures | LOCAL PASS; exact 1.25 boundary passes and 1.314801 fails | `benchmark-comparison.txt`, `benchmark-gate-fixtures.txt` |

## Fresh current-tree BENCH-R3.5 result

This fresh run uses the sealed BENCH-R3.5 scenario definitions and targets; old
measurements were not reused. Command: `scripts/run-render-benchmark.sh
artifacts/r4/render-benchmark.txt`. Configuration: release, 60 warm-up plus 300
measured frames per timed scenario, display sleep inhibited, production paths.

| Scenario | p50 | p95 | max / settle | Target | Result |
|---|---:|---:|---:|---:|---|
| BENCH-1 drag | 5.024 ms | 5.403 ms | 5.642 ms | p95 <= 16.7 ms | PASS |
| BENCH-2 pan | 0.087 ms | 0.107 ms | 0.171 ms | p95 <= 16.7 ms | PASS |
| BENCH-2b forced exposure | 5.394 ms | 5.915 ms | 6.304 ms | p95 <= 16.7 ms; nonzero strips every frame | PASS; source precondition covers 360/360 frames |
| BENCH-3 zoom | 2.434 ms | 8.880 ms | 10.292 ms | p95 <= 33 ms | PASS |
| BENCH-3 settle | — | — | 3.044 ms | <= 100 ms | PASS |
| BENCH-4 cold full redraw | — | — | 10.291 ms | informational | RECORDED |
| Warm full redraw | — | — | 4.860 ms | informational | RECORDED |

## Open blockers

- BLOCK-002 remains closed and was revalidated at `ce3b4b3`: the same MacBookPro18,2/macOS 15.7.5
  session produced `macos15-reliability-100x100.txt` and
  `macos15-startup-p95.txt`, satisfying frozen owner decision Option A.
- BLOCK-006: CI #1 and CI #4 are retained failed attempts. CI #4 exposed the
  stale-descriptor race and compressible failure fixture; both are corrected at
  `ce3b4b3` with a complete green local battery. A new manually dispatched run
  on the final pushed revision must execute all eight jobs green and provide
  the hosted baseline/comparison artifact and run URL. The committed baseline
  remains truthfully labelled owner-reference, not hosted proof.
- BLOCK-003/004/005: corrected local gates pass, but their hosted-CI execution
  components remain open until the qualifying manual dispatch shows `startup-memory`,
  `nightly-reliability`, `benchmark`, and `adversarial-golden` green with a run
  URL and retained artifacts.
- BLOCK-012: `pre-phase5-remediation` is absent by rule while blockers remain.

Developer ID/notarization, manual VoiceOver, multi-display review and
long-duration Instruments checks remain explicit operator/environment boundaries;
they are not automated-pass claims.
