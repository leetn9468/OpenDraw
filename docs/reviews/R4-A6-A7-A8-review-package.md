# A6 / R4 / A7 / A8 consolidated review package

Prepared: 2026-07-13  
Branch: `remediation/pre-phase5`  
Documentation revision at preparation: `f44b7e4`

## Executive verdict

The locally executable engineering work is complete and passing, but R4/A7 is
not accepted. A8 and Phase 5 entry remain blocked because two required external
proofs do not exist:

1. A 100-launch reliability run on real macOS 13.x Apple Silicon hardware.
2. A hosted-CI benchmark baseline and comparison run with retained artifacts and
   a run URL.

The annotated tag `pre-phase5-remediation` has therefore not been created.

## Acceptance state

| Acceptance | State | Evidence / reason |
|---|---|---|
| A6 — R3/R3-B checkpoint package | `CLOSED` | The original 14 feature groups are mapped to exact production symbols, tests and commits in `docs/remediation/A6-R3-checkpoint.md`. |
| A7 — R4 CI/reliability acceptance | `NOT ACCEPTED` | BLOCK-002 and BLOCK-006 remain open. |
| A8 — Phase 5 entry | `BLOCKED` | The required entry tag cannot exist while a hard blocker remains. |

## BLOCK-001–012 status

| ID | Requirement | State | Direct evidence / required action |
|---|---|---|---|
| BLOCK-001 | Restore the exact 14-item A6 package | `CLOSED` | `docs/remediation/A6-R3-checkpoint.md` |
| BLOCK-002 | Real macOS 13 Apple Silicon runtime proof | **OPEN** | Run `scripts/nightly-reliability.sh artifacts/r4/macos13-reliability-100x100.txt` on qualifying hardware and retain its environment header and results. |
| BLOCK-003 | Peak-memory assertions | `CLOSED` | `scripts/check-peak-memory.sh`; `artifacts/r4/peak-memory.txt` |
| BLOCK-004 | Startup-p95 enforcement | `CLOSED` | `scripts/check-startup-p95.sh`; `artifacts/r4/startup-p95.txt` |
| BLOCK-005 | 100 launches / 10,000 round trips | `CLOSED` | `scripts/nightly-reliability.sh`; `artifacts/r4/reliability-100x100.txt` |
| BLOCK-006 | Hosted benchmark ratio proof | **OPEN** | Enforcement exists, but no Git remote, hosted run, hosted baseline artifact or run URL is available. |
| BLOCK-007 | Fresh final-revision battery | `CLOSED` | Revision-accounted debug/release/ASan/coverage and targeted reruns under `artifacts/r4/` |
| BLOCK-008 | Reproducibility metadata | `CLOSED` | `docs/phase-4/fuzz-results.md`; environment and benchmark artifacts |
| BLOCK-009 | Audit traceability | `CLOSED` | `docs/audits/findings-closure-matrix.md` |
| BLOCK-010 | Correct R4 documentation | `CLOSED` | Incorrect unconditional pass language was removed. |
| BLOCK-011 | Exact revision accounting | `CLOSED` | `52c3295`, `f854389`, `6de4bce`, `f44b7e4` |
| BLOCK-012 | Phase 5 entry tag | **OPEN** | `pre-phase5-remediation` is intentionally absent. |

## Revision model

| Commit | Purpose | Rerun consequence |
|---|---|---|
| `52c3295` | Added memory, startup, reliability and ratio gates; expanded the headless journey; added CI jobs and representative memory harness. | Complete initial battery executed. |
| `f854389` | Corrected Swift toolchain metadata capture in four scripts. | Startup, memory, reliability, benchmark and ratio checks rerun. |
| `6de4bce` | Added reproducible mutation failure-index records. | Debug/release/ASan/coverage and adversarial filters rerun. |
| `f44b7e4` | Restored project tracker/A6 record, corrected documents and committed raw artifacts. | Documentation-only checks executed; no build input changed. |

## Environment

| Field | Value |
|---|---|
| Model | MacBook Pro `MacBookPro18,2` |
| SoC | Apple M1 Max |
| RAM | 64 GB (`68,719,476,736` bytes) |
| OS | macOS 15.7.5 build 24G624 |
| Architecture | arm64 |
| Swift | Apple Swift 6.1.2 (`swiftlang-6.1.2.1.2`, clang 1700.0.13.5) |
| Xcode selection | Full Xcode not selected; Command Line Tools active |

This environment is not a substitute for the required macOS 13 runtime test.

## Final local verification results

| Gate | Exact command | Observed result | Artifact |
|---|---|---|---|
| Debug build | `swift build -c debug` | PASS | `artifacts/r4/debug-build.txt` |
| Debug tests | `swift test` | 88/88, 2.421 s | `artifacts/r4/debug-tests.txt` |
| Release build | `swift build -c release` | PASS | `artifacts/r4/release-build.txt` |
| Release tests | `swift test -c release` | 88/88, 1.113 s | `artifacts/r4/release-tests.txt` |
| AddressSanitizer | `swift test --sanitize=address` | 88/88, 11.270 s | `artifacts/r4/asan-tests.txt` |
| Coverage | `swift test --enable-code-coverage`; `scripts/check-coverage.sh 55` | 87.93% versus 55% floor | `coverage-tests.txt`, `coverage-summary.txt` |
| Formatting | `xcrun swift-format lint --recursive --strict Sources Tests Package.swift` | PASS | `format.txt` |
| Module direction | `scripts/check-module-dependencies.sh` | PASS | `module-dependencies.txt` |
| Clean room | `scripts/check-clean-room.sh` | PASS | `clean-room.txt` |
| macOS 13 deployment compile | `MACOSX_DEPLOYMENT_TARGET=13.0 swift build -c release` | PASS compile only | `macos13-deployment-build.txt` |
| Symbol graph | `swift package dump-symbol-graph` plus emitted-file assertion | PASS | `symbol-graph.txt` |
| Adversarial corpus | `swift test --filter 'deterministicNativeAndSVG|fixedAdversarial'` | PASS | `adversarial-tests.txt` |
| Golden rendering | `swift test --filter compositeSceneMatchesProjectGolden` | PASS | `golden-test.txt` |
| UI/accessibility | `swift test --filter 'headlessUIJourney|accessibilityTreeExposes'` | PASS | `ui-accessibility-tests.txt` |
| Release integrity | `scripts/build-release-app.sh`; `codesign -dvvv dist/OpenDraw.app` | arm64, ad-hoc hardened-runtime signature | `release-integrity.txt` |
| Startup | `scripts/check-startup-p95.sh 20 artifacts/r4/startup-p95.txt` | PASS | `startup-p95.txt` |
| Peak memory | `scripts/check-peak-memory.sh artifacts/r4/peak-memory.txt` | PASS | `peak-memory.txt` |
| Reliability | `scripts/nightly-reliability.sh artifacts/r4/reliability-100x100.txt` | PASS | `reliability-100x100.txt` |
| Benchmark | `scripts/run-render-benchmark.sh artifacts/r4/render-benchmark.txt` | All absolute targets pass | `render-benchmark.txt` |
| Ratio gate | `scripts/check-benchmark-regression.sh ...`; `scripts/test-benchmark-regression-gate.sh` | Local comparison passes; above-threshold fixture fails as intended | `benchmark-comparison.txt`, `benchmark-gate-fixtures.txt` |

## Startup gate

### Measurement definition

- Source target: Phase 1 PRD, document ready in at most 2,000 ms at p95 over
  at least 20 runs.
- Start timestamp: process static initializer in `Sources/VectorFoundryApp/main.swift`.
- Stop timestamp: sample document, canvas, window, toolbar and autosave timer are
  initialized and the window is ordered front.
- Policy: a new process and fresh HOME for each sample. Application state is
  cold; OS/framework/filesystem caches are not purged.
- Samples: 20.
- Failure: p95 greater than 2,000 ms or any launch/output failure exits nonzero.

### Result

| p50 | p95 | Maximum | Target | Result |
|---:|---:|---:|---:|---|
| 140.815 ms | 151.433 ms | 163.861 ms | p95 <= 2,000 ms | PASS |

### Code area

- `Sources/VectorFoundryApp/main.swift`
  - `processStartupStart`
  - `startupProbeEnabled`
  - `AppDelegate.applicationDidFinishLaunching`
- `scripts/check-startup-p95.sh`
- `.github/workflows/ci.yml`, job `startup-memory`

## Peak-memory gate

### Scenario and ceilings

The representative gate document contains 1,000 objects, exactly 10,000 cubic
anchors and ten image objects totalling 50,000,000 declared pixels. Measurement
uses `/usr/bin/time -l` maximum resident set size.

The pre-existing Phase 1 PRD supplies the ceilings; they were not chosen from the
observed result:

- settled representative render: 500 MiB (`524,288,000` bytes);
- production Core Graphics/ImageIO PNG export: 650 MiB (`681,574,400` bytes).

| Scenario | Observed peak | Ceiling | Result |
|---|---:|---:|---|
| Settled render | 9,109,504 bytes | 524,288,000 bytes | PASS |
| PNG export | 19,939,328 bytes | 681,574,400 bytes | PASS |

### Code area

- `Sources/R4GateHarness/main.swift`
  - `representativeDocument()`
  - `settle(_:)`
  - `exportPNG(_:)`
- `scripts/check-peak-memory.sh`
- `Package.swift`, executable product/target `R4GateHarness`
- `.github/workflows/ci.yml`, job `startup-memory`

## Reliability gate

### Policy

- 100 separate application processes.
- Each process executes `VectorFoundry --smoke` and performs 100 native
  encode/decode cycles.
- Aggregate requirement: exactly 10,000 cycles.
- Watchdog: 30 seconds per process.
- Any crash, timeout, nonzero exit, missing success marker or codec/data error
  fails the script.

### Result

| Launches | Round trips | Crashes | Nonzero exits | Timeouts | Corruption failures | Duration |
|---:|---:|---:|---:|---:|---:|---:|
| 100 | 10,000 | 0 | 0 | 0 | 0 | 3 s |

### Code area

- `Sources/VectorFoundryApp/main.swift`, `--smoke` branch
- `scripts/nightly-reliability.sh`
- `.github/workflows/ci.yml`, job `nightly-reliability`

The local result was produced on macOS 15.7.5. BLOCK-002 requires the same script
and result on actual macOS 13.x Apple Silicon hardware.

## Benchmark and ratio gate

### Fresh BENCH-R3.5 result

The current-tree run uses the sealed BENCH-R3.5 definitions and targets, rather
than reusing its old measurements. Each timed scenario uses a 60-frame warm-up
and 300 measured frames through production rendering/cache paths.

| Scenario | p50 | p95 | Maximum/settle | Target | Result |
|---|---:|---:|---:|---:|---|
| BENCH-1 drag | 4.764 ms | 5.056 ms | 5.508 ms | p95 <= 16.7 ms | PASS |
| BENCH-2 pan | 0.087 ms | 0.108 ms | 0.181 ms | p95 <= 16.7 ms | PASS |
| BENCH-2b forced exposure | 5.203 ms | 5.827 ms | 8.853 ms | p95 <= 16.7 ms | PASS |
| BENCH-3 zoom | 2.408 ms | 8.763 ms | 10.214 ms | p95 <= 33 ms | PASS |
| BENCH-3 settle | — | — | 2.833 ms | <= 100 ms | PASS |
| BENCH-4 cold full redraw | — | — | 8.166 ms | Informational | RECORDED |
| Warm full redraw | — | — | 4.724 ms | Informational | RECORDED |

BENCH-2b recorded nonzero strip redraws for all 360 warm-up and measured frames.

### Ratio enforcement

- Threshold: every BENCH-1/2/2b/3 p95 and BENCH-3 settle value must be at most
  1.25 times baseline.
- Missing, empty, unknown or expired baselines fail closed.
- The committed baseline expires on 2026-10-10.
- The passing fixture remains below threshold.
- The failing fixture produces BENCH-1 ratio `1.314801` and exits nonzero.
- Baseline updates require a reviewed known-good hosted run, source URL/artifact,
  unchanged scenario semantics, date and 90-day expiry.

### Code area

- `Sources/RenderBenchmark/main.swift`
- `scripts/run-render-benchmark.sh`
- `scripts/check-benchmark-regression.sh`
- `scripts/test-benchmark-regression-gate.sh`
- `scripts/fixtures/benchmark-regression-pass.txt`
- `scripts/fixtures/benchmark-regression-fail.txt`
- `benchmarks/macos15-arm64-baseline.tsv`
- `.github/workflows/ci.yml`, job `benchmark`

The committed baseline came from the accepted owner-reference run at `d68f415`.
It is not represented as a hosted-runner baseline. BLOCK-006 needs a real hosted
run, retained artifact and run URL.

## Adversarial corpus reproducibility

### Generator

- Seed for each corpus: `UInt64(0x00000000A110F00D)` = `2,703,229,965`.
- LCG: `state = state * 6,364,136,223,846,793,005 + 1`, wrapping UInt64.
- Each mutation index `i` performs `1 + i % 8` byte edits.
- Position: `state % input.count`.
- Mutation byte: truncating low byte of `state >> 24`, XORed with input.
- 256 native mutations plus 256 SVG mutations.
- Seven directly enumerated fixed cases in
  `fixedAdversarialClassesFailSafely`; structural boundary tests add further
  JSON/XML/image cases elsewhere.

Failure record format:

```text
CORPUS_FAILURE kind=<native|svg> index=<0-based> seed=0x00000000A110F00D
```

The input is reproduced from the base fixture, seed and index. The two-second
parser wrapper is cooperative and in-process; it is not process isolation and
cannot hard-kill non-cooperative synchronous code.

### Code area

- `Sources/DocumentFormats/AdversarialParserHarness.swift`
- `Tests/DocumentFormatsTests/AdversarialCorpusTests.swift`
- `.github/workflows/ci.yml`, job `adversarial-golden`
- `docs/phase-4/fuzz-results.md`

## Golden rendering boundary

The 96×96 project-created composite covers dashed strokes, caps/joins/miter,
gradients, opacity, transformed paths, Core Text baseline and mixed z-order.

Tolerance:

- per-channel delta up to 3 is ignored;
- maximum channel delta is 12;
- at most 1% of pixels may exceed the ignored delta.

The comparison remains sensitive to material regressions while allowing
documented renderer drift. It does not prove every subpixel or color-managed
difference will fail.

Code/test area:

- `Tests/CanvasRenderTests/GoldenRenderingTests.swift`
- `compositeSceneMatchesProjectGoldenWithExplicitTolerance`
- `docs/verification/GOLDEN_RENDERING.md`

## A6 — fourteen R3-B feature groups

| # | Feature group | Principal production area | Permanent evidence | Key commits |
|---:|---|---|---|---|
| 1 | Precise selection, visibility and locking | `SelectionTool.hitTest`; `CanvasView.mouseDown` | `preciseSelectionRejectsBoundsFalsePositiveAndRespectsLockedLayers`; headless journey | `f12920f`, `3815904` |
| 2 | Direct selection | `SceneCommands.moveAnchor/moveControl/deleteAnchor`; canvas drag paths | VERIFY-019, anchor delete/control tests, headless journey | `8ed6d00`, `73b16bf`, `95fd622`, `b99aa94`, `8df64e4` |
| 3 | Pen completion | `SmoothPenToolState`; canvas pen handlers | `smoothPenCreatesMirroredHandlesPreviewAndClosedPath`; headless journey | `455eac7`, `d416162` |
| 4 | Scale and rotate | `TransformInteractions`; `applyDocumentTransform` | VERIFY-013/016/020; headless journey | `9fdd523`, `21051fb`, `d85ae4b` |
| 5 | Snapping | `SnapPolicy`; canvas snap indicator/toggle | VERIFY-018/021; headless journey | `1731c6a`, `72bd44d` |
| 6 | New document | `AppDelegate.newDocument/promptForNewDocument` | headless journey | `32c110a` |
| 7 | Properties | `CanvasView.editSelectedProperties`; `mutatePath` | headless journey; `advancedResourceInvariants` | `ef052fc`, `d416162` |
| 8 | Layers | `CanvasView.editLayers`; `Layer` | headless journey; locked/hidden selection test | `c4135bd` |
| 9 | Alignment | `CanvasView.alignSelectedLeft`; `AlignmentCommands.align` | `alignmentIsUndoable`; headless journey | `3815904` |
| 10 | Gradients | `CanvasView.editGradient`; gradient resources | `advancedResourceInvariants`; headless journey | `9e75ed4` |
| 11 | Text | `CanvasView.createText`; `TextObject` | headless journey; expanded rendering test | `ef052fc`, `d416162` |
| 12 | Images | safe placement and approval pipeline | raster-loader, approved-cache, placeholder and headless tests | `ef052fc`, `c4135bd`, `b05a149` |
| 13 | Group and compound | canvas commands; `SceneCommands` | undo and exact visual-invariance tests; headless journey | `8ed6d00`, `3815904`, `c4135bd`, `95fd622` |
| 14 | Zoom and pan | canvas zoom/pan methods; `zoomAbout` | VERIFY-014; headless journey | `ce4b329`, `bf9daa0` |

The exact fully qualified files and test function names are expanded in
`docs/remediation/A6-R3-checkpoint.md`.

## Findings closure matrix

| Finding | Closed by | Exact evidence location |
|---|---|---|
| AUDIT-001 transformed bounds | `6ca6ce1`, `8e98346` | VERIFY-004/005 and transformed-ink test |
| AUDIT-002 lossy SVG export | `b05a149` | deterministic export, structured loss, headless journey |
| AUDIT-003 unbounded native load | `b05a149`, `65cfb1a` | bounded-reader and VERIFY-011 tests |
| AUDIT-004 incomplete validation | `8e98346`, `2f6d3d6` | strict validation and VERIFY-007/008 tests |
| AUDIT-005 unsaved open loss | `f12920f` | `unsavedCoordinatorsAreIndependentAndCancelPreventsReplacement` |
| AUDIT-006 unsafe coalescing | `f12920f` | `failedFirstGestureDoesNotCorruptLaterCoalescing` and history/change-stream tests |
| AUDIT-007 mixed stacking | `8e98346` | v4 mixed-order round trip and visual invariance |
| AUDIT-008 unsafe images | `b05a149` | loader/cache/path/placeholder tests |

Full paths and functions are in `docs/audits/findings-closure-matrix.md`.

## Files changed for rejected-checkpoint remediation

### Code, package and CI

- `.github/workflows/ci.yml`
- `Package.swift`
- `Sources/R4GateHarness/main.swift`
- `Sources/RenderBenchmark/main.swift`
- `Sources/VectorFoundryApp/main.swift`
- `Tests/DocumentFormatsTests/UIJourneyTests.swift`
- `Tests/DocumentFormatsTests/AdversarialCorpusTests.swift`

### Gate scripts and fixtures

- `scripts/check-benchmark-regression.sh`
- `scripts/check-peak-memory.sh`
- `scripts/check-startup-p95.sh`
- `scripts/nightly-reliability.sh`
- `scripts/run-render-benchmark.sh`
- `scripts/test-benchmark-regression-gate.sh`
- `scripts/fixtures/benchmark-regression-pass.txt`
- `scripts/fixtures/benchmark-regression-fail.txt`
- `benchmarks/macos15-arm64-baseline.tsv`

### Corrected records

- `README.md`
- `docs/PROJECT_STATE.md`
- `docs/remediation/A6-R3-checkpoint.md`
- `docs/phase-4/R4-checkpoint.md`
- `docs/phase-4/README.md`
- `docs/phase-4/ci-policy.md`
- `docs/phase-4/fuzz-results.md`
- `docs/phase-4/performance-dashboard.md`
- `docs/verification/GOLDEN_RENDERING.md`
- `docs/audits/R4-final-reaudit.md`
- `docs/audits/findings-closure-matrix.md`
- `artifacts/r4/*`

## Explicit non-automated boundaries

These remain visible and are not represented as automated passes:

- Developer ID distribution signing and notarization require owner credentials.
- Manual VoiceOver review.
- Multi-display review.
- Long-duration Instruments/leak observation.
- The parser deadline is cooperative/in-process, not a hard process-isolation timeout.

## Required operator work to unblock Phase 5

### BLOCK-002 — macOS 13 runtime

On a real macOS 13.x Apple Silicon Mac:

```sh
git switch remediation/pre-phase5
git rev-parse HEAD
swift --version
sw_vers
system_profiler SPHardwareDataType
scripts/nightly-reliability.sh artifacts/r4/macos13-reliability-100x100.txt
```

Before committing the artifact, remove serial number, hardware UUID,
provisioning UDID and similar device identifiers. Retain model identifier, SoC,
RAM, macOS build, toolchain, revision, command, 100 launch rows and summary.

### BLOCK-006 — hosted benchmark proof

1. Configure/push to the intended Git remote.
2. Run the `benchmark` CI job on the final candidate revision.
3. Retain `benchmark-results` and `benchmark-comparison` artifacts and the run URL.
4. Replace/bootstrap the baseline only from that reviewed green hosted run,
   recording source commit, URL/artifact, date and 90-day expiry.
5. Rerun the ratio gate against the hosted baseline.
6. Commit the proof and update BLOCK-006.

### Final closure sequence

Only after both proofs pass:

1. Update A7 and A8 to `CLOSED` and BLOCK-002/006/012 to `CLOSED`.
2. Update the checkpoint/re-audit with the exact hosted and macOS 13 results.
3. Rerun every gate affected by any code/script/CI change.
4. Commit the final evidence.
5. Create annotated tag `pre-phase5-remediation` on the proven revision.
6. Record the exact tag target in `docs/PROJECT_STATE.md` and the checkpoint.

## Review conclusion

Current verdict: **FAILED — PHASE 5 REMAINS BLOCKED**.
