# ADR-011 macOS 15 platform-floor revision and R4 rerun report

Prepared: 2026-07-13  
Branch: `remediation/pre-phase5`  
Final build-input and battery revision: `f6ec81a88bee6a6b3055da850d08a6243061d090`  
Owner-reference environment: MacBookPro18,2, Apple M1 Max, 64 GB,
macOS 15.7.5 build 24G624, arm64, Apple Swift 6.1.2

Post-report revision note (2026-07-14): CI #4 exposed a durable-writer
descriptor race and compressible memory-fixture allocation. Corrective
build-input revision `ce3b4b3` changes no platform floor or frozen gate value;
the complete battery was rerun there and retained by `8da5ee8`. The original
`f6ec81a` platform-floor history below is preserved rather than rewritten.

## C1 — Build configuration

Commit `f6ec81a` changes only the supported platform floor and related active
configuration/documentation:

```swift
// Package.swift
platforms: [.macOS(.v15)]
```

```xml
<!-- resources/Info.plist -->
<key>LSMinimumSystemVersion</key><string>15.0</string>
```

```yaml
# .github/workflows/ci.yml
runs-on: macos-15
run: MACOSX_DEPLOYMENT_TARGET=15.0 swift build -c release
```

All eight hosted jobs are pinned to the `macos-15` image. Release proof in
`artifacts/r4/release-integrity.txt` records binary `minos 15.0`, SDK 15.5,
and plist minimum 15.0. No macOS 14/15-only API was adopted.

RESOLVED

## C2 — Documentation and artifact-name sweep

Tracked grep line count for the former floor patterns:

| Stage | Matching tracked lines |
|---|---:|
| Before sweep | 58 |
| After sweep and evidence refresh | 18 |

Every remaining line is intentionally historical:

- `artifacts/r4/revision-scope-proof.txt` lines 7 and 35: immutable diff proof
  showing the old deployment artifact being deleted/renamed.
- `docs/PROJECT_STATE.md` lines 42–55: the original frozen Option A wording and
  the verbatim owner-directed ADR revision; history must not be rewritten.
- `docs/adr/ADR-011-platform-support.md` lines 9–33: the original accepted ADR
  followed by its dated superseding revision.
- `docs/audits/pre-phase5-code-audit.md` lines 381 and 437: historical findings
  from the audited revision, explicitly identified as superseded nearby.
- `docs/phase-1/requirements-ledger.md` line 24: append-only superseded REQ-015;
  active REQ-017 records the new floor.

Active artifact names are `macos15-deployment-build.txt`,
`macos15-reliability-100x100.txt`, and `macos15-startup-p95.txt`. No active
operator command, package setting, plist value, workflow setting, project-state
row, or release document targets the former floor.

RESOLVED

## C3 — BLOCK-002 redefinition and evidence

`docs/PROJECT_STATE.md` records the owner decision verbatim and defines the
minimum-OS proof as both codec reliability and full-app startup on real macOS
15.x Apple Silicon hardware.

Both artifacts were produced in the same MacBookPro18,2/macOS 15.7.5 session
at `f6ec81a`:

| Artifact | Result |
|---|---|
| `artifacts/r4/macos15-reliability-100x100.txt` | 100 launches, 100 distinct PIDs, 10,000 round trips, zero crashes/nonzero exits/timeouts/corruption; 5 s aggregate wall clock |
| `artifacts/r4/macos15-startup-p95.txt` | 20 full-app launches; p50 142.652 ms, p95 152.286 ms, max 183.569 ms; p95 target 2,000 ms; PASS |

Both retain revision, model, chip, memory, OS version/build, architecture, Swift
toolchain, and policy metadata. BLOCK-002 is `CLOSED`.

RESOLVED

## C4 — BLOCK-011 complete rerun

The complete battery ran at exact revision
`f6ec81a88bee6a6b3055da850d08a6243061d090`. No later build-input change is
included in the evidence/state commit.

| Gate | Exact command | Observed result | Artifact |
|---|---|---|---|
| Debug build | `swift build -c debug` | PASS | `debug-build.txt` |
| Debug tests | `swift test` | 89/89, 2.419 s | `debug-tests.txt` |
| Release build | `swift build -c release` | PASS | `release-build.txt` |
| Release tests | `swift test -c release` | 89/89, 1.136 s | `release-tests.txt` |
| AddressSanitizer | `swift test --sanitize=address` | 89/89, 11.715 s | `asan-tests.txt` |
| Coverage | `swift test --enable-code-coverage`; `scripts/check-coverage.sh 55` | 87.93% ≥ 55% | `coverage-tests.txt`, `coverage-summary.txt` |
| Formatting | `xcrun swift-format lint --recursive --strict Sources Tests Package.swift` | PASS | `format.txt` |
| Dependency direction | `scripts/check-module-dependencies.sh` | PASS | `module-dependencies.txt` |
| Clean room | `scripts/check-clean-room.sh` | PASS | `clean-room.txt` |
| Minimum-target compile | `MACOSX_DEPLOYMENT_TARGET=15.0 swift build -c release` | PASS | `macos15-deployment-build.txt` |
| Symbol graph | `swift package dump-symbol-graph` plus emitted-file assertion | PASS | `symbol-graph.txt` |
| Adversarial corpus | `swift test --filter 'deterministicNativeAndSVG|fixedAdversarial'` | 2/2 PASS; seed remains `0xA110F00D` | `adversarial-tests.txt` |
| Golden rendering | `swift test --filter compositeSceneMatchesProjectGolden` | 1/1 PASS | `golden-test.txt` |
| UI/accessibility | `swift test --filter 'headlessUIJourney|accessibilityTreeExposes'` | 2/2 PASS | `ui-accessibility-tests.txt` |
| A6 named filter | Combined exact 19-method filter | 19/19 PASS | `a6-filtered-tests.txt`, `a6-test-existence.txt` |
| AUDIT-005/006 | Exact two-test filter | 2/2 PASS | `audit-005-006-filtered-tests.txt`, `audit-005-006-test-existence.txt` |
| Release assembly/signature | `scripts/build-release-app.sh`; `codesign -dvvv`; binary/plist minimum check | PASS; arm64, hardened-runtime ad-hoc signature, minos/plist 15.0 | `release-integrity.txt` |
| Startup | `scripts/check-startup-p95.sh 20 artifacts/r4/macos15-startup-p95.txt` | p50 142.652, p95 152.286, max 183.569 ms; PASS | `macos15-startup-p95.txt`, `startup-p95.txt` |
| Memory settle/export | `scripts/check-peak-memory.sh artifacts/r4/peak-memory.txt` | 214,548,480 / 524,288,000 bytes; 225,280,000 / 681,574,400 bytes; PASS | `peak-memory.txt` |
| Memory failure fixture | `scripts/test-peak-memory-gate.sh` | 790,740,992 > 524,288,000; expected nonzero gate failure; fixture PASS | `peak-memory-failure-fixture.txt` |
| Reliability | `scripts/nightly-reliability.sh artifacts/r4/macos15-reliability-100x100.txt` | 100 distinct PIDs, 10,000 cycles, zero failures; PASS | `macos15-reliability-100x100.txt`, `reliability-100x100.txt` |
| BENCH ratio | Exact-decimal comparison plus boundary/failure fixtures | Current ratios PASS; exact 1.25 PASS; 1.314801 FAIL as required | `benchmark-comparison.txt`, `benchmark-gate-fixtures.txt` |

### BENCH-R3.5 results

| Scenario | p50 | p95 | Max/settle | Frozen target | Result |
|---|---:|---:|---:|---:|---|
| BENCH-1 drag | 5.029 ms | 5.408 ms | 5.611 ms | p95 ≤ 16.7 ms | PASS |
| BENCH-2 pan | 0.087 ms | 0.107 ms | 0.133 ms | p95 ≤ 16.7 ms | PASS |
| BENCH-2b forced exposure | 5.415 ms | 5.815 ms | 6.161 ms | p95 ≤ 16.7 ms; nonzero strips every frame | PASS; 360/360 asserted |
| BENCH-3 zoom | 2.391 ms | 9.162 ms | 10.436 ms | p95 ≤ 33 ms | PASS |
| BENCH-3 settle | — | — | 2.776 ms | ≤ 100 ms | PASS |
| BENCH-4 cold open | — | — | 8.326 ms | Informational | RECORDED |
| Warm full redraw | — | — | 4.871 ms | Informational | RECORDED |

`artifacts/r4/revision-map.md` maps the complete-battery artifacts to `f6ec81a`.
A later hosted-portability correction at `b6cee43` reran and remapped only the
affected dependency, clean-room, benchmark, memory, and reliability artifacts.
`artifacts/r4/revision-scope-proof.txt` records the commit scope, ancestry,
runner pins, minimum-platform inputs, and zero changes under `Sources`, `Tests`,
or the frozen verification queue.

RESOLVED

## Consolidated code-area inventory

This inventory is the review index for the platform-floor decision and its R4
proof. It distinguishes build inputs from runtime measurement paths,
gate/test-side policy, permanent product tests, documentation, and artifacts.

### Platform and release build inputs

| Area | File and symbol/location | Reviewed behavior |
|---|---|---|
| Swift package platform | `Package.swift:7`, `Package.platforms` | Declares `.macOS(.v15)`; controls SwiftPM deployment target. |
| App bundle floor | `resources/Info.plist:9`, `LSMinimumSystemVersion` | Declares 15.0 for the assembled OpenDraw app. |
| Hosted runner | `.github/workflows/ci.yml`, every `runs-on` | All eight jobs are pinned to `macos-15`. |
| Explicit target build | `.github/workflows/ci.yml:22–23` | Runs `MACOSX_DEPLOYMENT_TARGET=15.0 swift build -c release`. |
| Release assembly | `scripts/build-release-app.sh` | Builds release, creates the `.app`, copies the plist, signs with hardened runtime, verifies signature, and asserts arm64. |
| Binary minimum proof | `artifacts/r4/release-integrity.txt` | `LC_BUILD_VERSION minos 15.0`; plist value 15.0; SDK 15.5. |

No `Sources/` file changed for the platform revision. In particular, no newer
framework API, availability assumption, editor behavior, geometry behavior, or
document-format behavior was introduced.

### Full-app startup path

| Area | File and symbol/location | Reviewed behavior |
|---|---|---|
| Probe selection | `Sources/VectorFoundryApp/main.swift:13`, `startupProbeEnabled` | Enables the dedicated full-app startup probe through `--startup-probe`. |
| Ready boundary | `Sources/VectorFoundryApp/main.swift:849–852` | Emits `STARTUP_READY_MS` only after sample document, canvas, window, toolbar, autosave timer, and window-front work. |
| Measurement driver | `scripts/check-startup-p95.sh` | Builds release, creates a fresh HOME per launch, runs 20 clean processes, parses the ready marker, and fails above 2,000 ms. |
| Percentile policy | `scripts/check-startup-p95.sh:30–41` | Nearest-rank one-based index; 20-sample p95 selects sorted item 19. |
| Minimum-OS evidence | `artifacts/r4/macos15-startup-p95.txt` | Same-session 20-launch result: p50 142.652, p95 152.286, max 183.569 ms. |
| CI consumer | `.github/workflows/ci.yml`, `startup-memory` | Runs the same production startup script on the hosted `macos-15` lane. |

The measurement begins at the Swift static initializer and excludes exec,
dyld, and other pre-main work. This boundary is recorded in
`docs/phase-4/ci-policy.md` and is not represented as click-to-window time.

### Codec reliability path

| Area | File and symbol/location | Reviewed behavior |
|---|---|---|
| Smoke entry | `Sources/VectorFoundryApp/main.swift:1099`, `--smoke` branch | Runs native encode/decode reliability before AppKit UI initialization. |
| Process driver | `scripts/nightly-reliability.sh` | Launches 100 sequential processes under 30-second watchdogs; requires unique PIDs and 100 round trips each. |
| Per-process proof | `scripts/nightly-reliability.sh:23–60` | Retains PID, external process-wall time, inner smoke time, exit code, cumulative cycles, and failure counters. |
| Minimum-OS evidence | `artifacts/r4/macos15-reliability-100x100.txt` | 100 distinct PIDs, 10,000 cycles, zero crashes, nonzero exits, timeouts, or corruption failures. |
| CI consumer | `.github/workflows/ci.yml`, `nightly-reliability` | Scheduled execution of the same script on `macos-15`. |

The codec path and full-app path are intentionally distinct. Frozen Option A
requires both, preventing codec-only smoke from substituting for UI runtime
proof.

### Peak-memory path

| Area | File and symbol/location | Reviewed behavior |
|---|---|---|
| Representative document | `Sources/R4GateHarness/main.swift`, `representativeDocument()` | Creates 1,000 objects, 10,000 anchors, and ten embedded 2,500×2,000 images. |
| Production decode/cache | `Sources/R4GateHarness/main.swift:58–93`, `settle(_:)` | Uses `RasterResourceLoader` and `ApprovedImageCache`; asserts ten decoded images and 50,000,000 pixels; renders the approved snapshot. |
| Export path | `Sources/R4GateHarness/main.swift:96–105`, `exportPNG(_:)` | Exercises production Core Graphics/ImageIO PNG export. |
| Failure injection | `Sources/R4GateHarness/main.swift:112–117`, `R4_MEMORY_EXTRA_BYTES` | Retains an explicit extra allocation so the gate can be proven to fail. |
| Ceiling enforcement | `scripts/check-peak-memory.sh` | Enforces unchanged 500 MiB settle and 650 MiB export ceilings. |
| Failure fixture | `scripts/test-peak-memory-gate.sh` | Forces 550 MiB extra and requires the underlying settle gate to exit nonzero. |
| Evidence | `artifacts/r4/peak-memory.txt`; `peak-memory-failure-fixture.txt` | Settle/export pass; forced allocation exceeds the unchanged ceiling and fails. |

### Rendering and benchmark path

| Area | File and symbol/location | Reviewed behavior |
|---|---|---|
| Reference scene | `Sources/RenderBenchmark/main.swift:41–71`, `referenceDocument()` | Fixed unique-ID, mixed-node 1,000-object document. |
| Statistics | `Sources/RenderBenchmark/main.swift:17–35`, `nearestRank`/`measure` | 60 warm-up plus 300 measured frames; nearest-rank p50/p95. |
| Drag and cached pan | `Sources/RenderBenchmark/main.swift:92–106` | BENCH-1 and BENCH-2 use production document translation and bitmap-cache paths. |
| Forced-exposure pan | `Sources/RenderBenchmark/main.swift:108–120` | BENCH-2b zoom/pan construction; per-frame precondition requires strip count to increase for all 360 frames. |
| Strip redraw implementation | `Sources/CanvasRender/ViewportStripCache.swift` | Production retained-bitmap pan and exposed-strip redraw path. |
| Retained cache budget | `Sources/DocumentModel/Document.swift:31`, `maximumRetainedBitmapPixels`; `Sources/CanvasRender/SceneBitmapCache.swift:34–44` | Independent 67,108,864-pixel retained-bitmap budget; separate concern from the image cap. |
| Benchmark driver | `scripts/run-render-benchmark.sh` | Builds release, records environment/revision, and executes the production benchmark. |
| Ratio enforcement | `scripts/check-benchmark-regression.sh` | Exact-decimal inclusive `observed <= baseline × 1.25`; display ratio does not decide pass/fail. |
| Ratio fixtures | `scripts/test-benchmark-regression-gate.sh`; `scripts/fixtures/benchmark-regression-*.txt` | Below-boundary and exact-boundary cases pass; 1.314801 case fails. |
| Owner baseline | `benchmarks/owner-reference-macos15-arm64-baseline.tsv` | Explicit owner-reference/non-hosted provenance and unchanged 1.25 ratios. |
| Evidence | `artifacts/r4/render-benchmark.txt`; `benchmark-comparison.txt`; `benchmark-gate-fixtures.txt` | All absolute and current ratio gates pass; BENCH-2b reports 360/360 asserted strip frames. |

### Test and verification areas

| Area | File/artifact | Reviewed behavior |
|---|---|---|
| Full permanent suite | `Tests/`; `debug-tests.txt`, `release-tests.txt`, `asan-tests.txt` | 89 tests pass in debug, release, and ASan configurations. |
| Adversarial seed | `Tests/DocumentFormatsTests/AdversarialCorpusTests.swift:6–18` | Seed remains `0xA110F00D`; fixed wrapping LCG; no expected value changed. |
| Golden boundaries | `Tests/CanvasRenderTests/GoldenRenderingTests.swift:70–80` | Inclusive 92-pixel/channel-12 boundaries remain unchanged. |
| A6 exact names | `docs/remediation/A6-R3-checkpoint.md`; `a6-test-existence.txt`; `a6-filtered-tests.txt` | Every named method exists; combined 19-test filter passes. |
| AUDIT-005/006 | `audit-005-006-test-existence.txt`; `audit-005-006-filtered-tests.txt` | Both exact regression methods exist and pass. |
| Frozen queue | `docs/verification/VERIFICATION_QUEUE.md` | VERIFY-001–021 unchanged; no new production math was introduced. |
| Scope proof | `artifacts/r4/revision-scope-proof.txt` | Zero changes under `Sources`, `Tests`, or the frozen verification queue in build-input commit `f6ec81a`. |

### State, decision, and review records

| Record | Purpose |
|---|---|
| `docs/adr/ADR-011-platform-support.md` | Preserves the original ADR and appends the dated macOS 15 supersession verbatim. |
| `docs/PROJECT_STATE.md` | Authoritative frozen owner decisions and BLOCK-001–012 state; BLOCK-002 closed, BLOCK-006 open. |
| `docs/phase-4/ci-policy.md` | Runner image, startup boundary, memory rules, reliability semantics, ratio policy, and hosted closure procedure. |
| `docs/phase-4/R4-checkpoint.md` | Current complete-battery and BENCH tables plus open hosted blockers. |
| `docs/reviews/R4-A6-A7-A8-review-package.md` | Operator and human-acceptance package, including the mandatory A7 artifact spot-check. |
| `artifacts/r4/revision-map.md` | Maps complete-battery artifacts to `f6ec81a` and portability-affected reruns to `b6cee43`. |

### Explicitly unchanged areas

- No production file under `Sources/` changed.
- No permanent test under `Tests/` changed.
- No script changed; existing gate semantics were rerun unchanged.
- No VERIFY entry or frozen worked value changed.
- No startup, memory, benchmark, ratio, coverage, golden, timeout, or document
  limit changed.
- No new macOS-only API was adopted.
- No Phase 5 tag was created.

## C5 — State and verdict

`docs/PROJECT_STATE.md` now records:

- BLOCK-002: `CLOSED` with both same-session minimum-OS artifacts;
- BLOCK-003/004/005: `OPEN — LOCAL PASS, HOSTED PENDING`;
- BLOCK-006: `OPEN` pending a manually dispatched all-eight-jobs-green run, hosted
  baseline bootstrap, comparison artifact, and run URL;
- BLOCK-012: `OPEN`; no Phase 5 tag exists.

Overall verdict remains **FAILED — PHASE 5 BLOCKED** until BLOCK-006 and the
hosted components close.

No pinned constant, VERIFY-001–021 entry, benchmark target, tolerance, memory
ceiling, startup target, ratio threshold, or expected value changed. Commit
scope proof reports zero changes under `Sources`, `Tests`, or
`docs/verification/VERIFICATION_QUEUE.md`.

RESOLVED
