# R4 checkpoint — owner rejection remediation

Status: **A7 ACCEPTED — PHASE 5 ENTRY TAG AUTHORIZED**

The prior checkpoint claim at `c5072e0` was rejected. This report supersedes it.
All technical proof is closed and the mandatory named-human inspection is now
recorded; tag creation is the remaining final action.

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
| `b57293c` | Workflow-only hosted benchmark bootstrap/enforcement selection after CI #5 | No local rerun by directive; actual workflow block dry-run in BOOTSTRAP and failing ENFORCE modes |
| `59eec99` | Workflow-only fail-closed validation for exactly five unique hosted baseline metrics | No local rerun by directive; BOOTSTRAP/ENFORCE extraction and syntax dry-runs repeated |
| `e01ac1b` | Retain CI #5 logs/artifacts, mode proof, policy, and triage report | Evidence/documentation only |
| `5d2ea50` | Isolate the unchanged adversarial wall-clock test from unrelated ASan-suite scheduling after CI #6 | Shared local/hosted ASan gate rerun: 89/89 plus isolated 1/1 PASS |
| `bd4524f` | Retain CI #6 protected log, API metadata, corrective ASan output, policy, and triage report | Evidence/documentation only |
| `e8724aa` | Correct all-eight-job closure wording and ADR-011 artifact commit accounting | Pre-evaluation documentation only |
| `88c3d58` | Retain qualifying CI #8 artifacts/logs and commit the hosted benchmark baseline | All eight hosted jobs green; baseline/ratio fixtures validated |
| `6303428` | Close hosted R4 gates and record the then-outstanding human acceptance blocker | Documentation only; no build input changed |
| Acceptance evidence commit | Record TN LEE's direct three-file inspection and accept A6/A7 | Documentation/evidence only; authorizes the Phase 5 entry tag |

The current final build-input/evidence revision is `88c3d58`; the current complete local
battery revision is `ce3b4b3`. Hosted-only CI #5 inputs required no local rerun.
The later shared ASan input was rerun at `5d2ea50`; no other local gate input
changed. CI #8 passed all eight jobs at `94fb0f0`; `88c3d58` adds only its
hosted baseline/evidence and reruns the affected ratio validation. Frozen
targets, ceilings, tolerances, retry policy, shared ratio
semantics, and VERIFY-001–021 are unchanged. Evidence commits `8da5ee8`,
`e01ac1b`, `bd4524f`, and `88c3d58` retain the local battery and hosted history.

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
| `scripts/run-address-sanitizer-tests.sh` | PASS at `5d2ea50`; 89/89 in 11.232 s plus isolated deadline test 1/1 in 0.036 s | `asan-tests-run6-fix.txt` |
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

## Hosted closure and final acceptance

- BLOCK-002 remains closed and was revalidated at `ce3b4b3`: the same MacBookPro18,2/macOS 15.7.5
  session produced `macos15-reliability-100x100.txt` and
  `macos15-startup-p95.txt`, satisfying frozen owner decision Option A.
- BLOCK-003/004/005/006 are closed by qualifying CI #8 at `94fb0f0`, retained
  by `88c3d58`. All eight jobs executed successfully, the hosted baseline has
  exact provenance, and the bootstrap-only first-run caveat is explicit.
- CI #5 is also a retained failed attempt: absolute benchmarks passed, but the
  workflow compared hosted observations with the owner-local baseline.
  Workflow-only fixes `b57293c`/`59eec99` now bootstrap and validate a hosted candidate and preserve
  blocking 1.25 enforcement once that candidate is reviewed and committed.
- CI #6 is also a retained failed attempt: the benchmark bootstrap passed, but
  the ASan whole-suite scheduler consumed the first mutation's wall-clock
  deadline. Revision `5d2ea50` preserves the unchanged 3/10-second assertions
  and runs that test in an isolated ASan invocation after the other 89 tests.
- TN LEE directly opened `a6-test-existence.txt`, `revision-map.md`, and the
  exact 14-row table in `A6-R3-checkpoint.md` on 2026-07-15 at 00:38 UTC+08:00.
  Existence-proof format, per-artifact revision accounting, and exact per-row
  test names were confirmed. The record is `artifacts/r4/a7-human-spot-check.md`.
- A6 and A7 are accepted. BLOCK-012 is ready for the authorized annotated tag;
  its exact target will be recorded immediately after tag creation.

Developer ID/notarization, manual VoiceOver, multi-display review and
long-duration Instruments checks remain explicit operator/environment boundaries;
they are not automated-pass claims.
