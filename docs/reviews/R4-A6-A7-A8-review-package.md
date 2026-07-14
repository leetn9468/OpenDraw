# A6 / R4 / A7 / A8 consolidated review package

Prepared: 2026-07-13  
Branch: `remediation/pre-phase5`  
Documentation revision at preparation: `f44b7e4`

## Executive verdict

The locally executable engineering work is complete and passing, but R4/A7 is
not accepted. A8 and Phase 5 entry remain blocked because one required external
proof does not exist:

1. A hosted-CI benchmark baseline and comparison run with retained artifacts and
   a run URL.

The annotated tag `pre-phase5-remediation` has therefore not been created.

## Acceptance state

| Acceptance | State | Evidence / reason |
|---|---|---|
| A6 — R3/R3-B checkpoint package | `CLOSED` | The original 14 feature groups are mapped to exact production symbols, tests and commits in `docs/remediation/A6-R3-checkpoint.md`. |
| A7 — R4 CI/reliability acceptance | `NOT ACCEPTED` | BLOCK-003/004/005 hosted components and BLOCK-006 remain open. |
| A8 — Phase 5 entry | `BLOCKED` | The required entry tag cannot exist while a hard blocker remains. |

## BLOCK-001–012 status

| ID | Requirement | State | Direct evidence / required action |
|---|---|---|---|
| BLOCK-001 | Restore the exact 14-item A6 package | `CLOSED` | `docs/remediation/A6-R3-checkpoint.md` |
| BLOCK-002 | Real minimum-OS macOS 15 Apple Silicon runtime proof | **CLOSED** | Revalidated at `ce3b4b3` on the owner-reference MacBookPro18,2/macOS 15.7.5: 100 distinct PIDs/10,000 round trips/zero failures and 20 launches with p95 143.960 ms ≤ 2,000 ms. |
| BLOCK-003 | Peak-memory assertions | `OPEN — LOCAL PASS, HOSTED PENDING` | Corrected decoded-image gate passes locally; qualifying dispatch must pass `startup-memory`. |
| BLOCK-004 | Startup-p95 enforcement | `OPEN — LOCAL PASS, HOSTED PENDING` | Local 20-process gate passes; qualifying dispatch must pass `startup-memory`. |
| BLOCK-005 | 100 launches / 10,000 round trips | `OPEN — LOCAL PASS, HOSTED PENDING` | Local sequential process proof passes; qualifying dispatch must execute and pass `nightly-reliability`. |
| BLOCK-006 | Hosted benchmark ratio proof | **OPEN** | CI #1/#4/#5/#6 are retained failed attempts. Corrections through `5d2ea50` address CI #5 baseline provenance and CI #6 ASan deadline isolation; a manually dispatched all-eight-jobs-green bootstrap run plus artifacts and URL is still required. |
| BLOCK-007 | Fresh final-revision battery | `CLOSED` | Complete local battery at `ce3b4b3`; hosted-only CI #5 inputs required no local rerun, and the affected ASan gate passed 89/89 plus isolated 1/1 at `5d2ea50`. |
| BLOCK-008 | Reproducibility metadata | `CLOSED` | `docs/phase-4/fuzz-results.md`; environment and benchmark artifacts |
| BLOCK-009 | Audit traceability | `CLOSED` | `docs/audits/findings-closure-matrix.md` |
| BLOCK-010 | Correct R4 documentation | `CLOSED` | Incorrect unconditional pass language was removed. |
| BLOCK-011 | Exact revision accounting | `CLOSED` | Complete battery `ce3b4b3`/`8da5ee8`; CI #5 evidence `e01ac1b`; affected ASan rerun `5d2ea50` with evidence `bd4524f`; see `revision-map.md`. |
| BLOCK-012 | Phase 5 entry tag | **OPEN** | `pre-phase5-remediation` is intentionally absent. |

## Revision model

| Commit | Purpose | Rerun consequence |
|---|---|---|
| `52c3295` | Added memory, startup, reliability and ratio gates; expanded the headless journey; added CI jobs and representative memory harness. | Complete initial battery executed. |
| `f854389` | Corrected Swift toolchain metadata capture in four scripts. | Startup, memory, reliability, benchmark and ratio checks rerun. |
| `6de4bce` | Added reproducible mutation failure-index records. | Debug/release/ASan/coverage and adversarial filters rerun. |
| `f44b7e4` | Restored project tracker/A6 record, corrected documents and committed raw artifacts. | Documentation-only checks executed; no build input changed. |
| `b01364b` | Corrected decoded-image memory gate, failure fixture, numeric policies, PID evidence and baseline naming. | Complete local battery rerun. |
| `2884a54` | Reliability-only external process-duration correction. | 100-process/10,000-cycle reliability gate rerun. |
| `f6ec81a` | Raised only the platform floor to macOS 15 in package/release/CI inputs and swept active documentation. | Complete local battery and every retained R4 artifact regenerated. |
| `b6cee43` | Replaced unavailable ripgrep calls with equivalent POSIX grep, added dispatch reliability, and updated actions to Node.js 24 majors. | Affected dependency, clean-room, benchmark/ratio/fixture, memory/failure-fixture, and reliability gates rerun. |
| `ce3b4b3` | Fixed stale descriptor cleanup and the compressible forced-memory allocation exposed by CI #4. | Complete local battery plus focused and 30-run release stress rerun. |
| `8da5ee8` | Retained CI #4 logs, stress proof, and the complete corrective battery. | Evidence only; no build input changed. |
| `b57293c` | Added hosted-only bootstrap/enforcement baseline selection without changing the shared ratio checker. | No local battery rerun; new hosted run required. |
| `59eec99` | Added fail-closed completeness validation for the five hosted baseline metrics. | No local battery rerun; actual workflow block revalidated in both modes. |
| `e01ac1b` | Retained CI #5 evidence, variance record, and actual workflow-mode dry-run proof. | Evidence only; no build input changed. |
| `5d2ea50` | Isolated the unchanged adversarial deadline test within the shared ASan gate. | Affected local gate rerun: 89/89 plus isolated 1/1 PASS. |
| `bd4524f` | Retained CI #6 failure and exact-revision corrective evidence. | Evidence only; no build input changed. |

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

This is the owner-approved minimum-OS runtime-proof environment.

## Final local verification results

| Gate | Exact command | Observed result | Artifact |
|---|---|---|---|
| Debug build | `swift build -c debug` | PASS | `artifacts/r4/debug-build.txt` |
| Debug tests | `swift test` | 89/89, 2.419 s | `artifacts/r4/debug-tests.txt` |
| Release build | `swift build -c release` | PASS | `artifacts/r4/release-build.txt` |
| Release tests | `swift test -c release` | 89/89, 1.136 s | `artifacts/r4/release-tests.txt` |
| AddressSanitizer | `scripts/run-address-sanitizer-tests.sh` | 89/89 plus isolated deadline test 1/1 at `5d2ea50` | `artifacts/r4/asan-tests-run6-fix.txt` |
| Coverage | `swift test --enable-code-coverage`; `scripts/check-coverage.sh 55` | 87.93% versus 55% floor | `coverage-tests.txt`, `coverage-summary.txt` |
| Formatting | `xcrun swift-format lint --recursive --strict Sources Tests Package.swift` | PASS | `format.txt` |
| Module direction | `scripts/check-module-dependencies.sh` | PASS | `module-dependencies.txt` |
| Clean room | `scripts/check-clean-room.sh` | PASS | `clean-room.txt` |
| macOS 15 deployment compile | `MACOSX_DEPLOYMENT_TARGET=15.0 swift build -c release` | PASS compile only | `macos15-deployment-build.txt` |
| Symbol graph | `swift package dump-symbol-graph` plus emitted-file assertion | PASS | `symbol-graph.txt` |
| Adversarial corpus | `swift test --filter 'deterministicNativeAndSVG|fixedAdversarial'` | PASS | `adversarial-tests.txt` |
| Golden rendering | `swift test --filter compositeSceneMatchesProjectGolden` | PASS | `golden-test.txt` |
| UI/accessibility | `swift test --filter 'headlessUIJourney|accessibilityTreeExposes'` | PASS | `ui-accessibility-tests.txt` |
| Release integrity | `scripts/build-release-app.sh`; `codesign -dvvv dist/OpenDraw.app` | arm64, ad-hoc hardened-runtime signature | `release-integrity.txt` |
| Startup | `scripts/check-startup-p95.sh 20 artifacts/r4/macos15-startup-p95.txt` | PASS; minimum-OS runtime proof; hosted job pending separately | `macos15-startup-p95.txt`, `startup-p95.txt` |
| Peak memory | `scripts/check-peak-memory.sh artifacts/r4/peak-memory.txt` | LOCAL PASS at `b6cee43` with decoded images; hosted pending | `peak-memory.txt` |
| Memory failure fixture | `scripts/test-peak-memory-gate.sh artifacts/r4/peak-memory-failure-fixture.txt` | PASS: underlying gate fails as required | `peak-memory-failure-fixture.txt` |
| Reliability | `scripts/nightly-reliability.sh artifacts/r4/reliability-100x100.txt` | PASS at `b6cee43` with 100 distinct PIDs; minimum-OS proof remains retained separately | `reliability-100x100.txt`, `macos15-reliability-100x100.txt` |
| Benchmark | `scripts/run-render-benchmark.sh artifacts/r4/render-benchmark.txt` | All absolute targets pass at `b6cee43` | `render-benchmark.txt` |
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

The start boundary excludes exec, dyld and all pre-main/static-initializer work;
it is not click-to-window timing. Percentiles use nearest rank, so p95 of 20 is
the 19th sorted value.

### Result

| p50 | p95 | Maximum | Target | Result |
|---:|---:|---:|---:|---|
| 142.652 ms | 152.286 ms | 183.569 ms | p95 <= 2,000 ms | PASS |

### Code area

- `Sources/VectorFoundryApp/main.swift`
  - `processStartupStart`
  - `startupProbeEnabled`
  - `AppDelegate.applicationDidFinishLaunching`
- `scripts/check-startup-p95.sh`
- `.github/workflows/ci.yml`, job `startup-memory`

## Peak-memory gate

### Scenario and ceilings

The corrected representative gate document contains 1,000 objects, exactly
10,000 cubic anchors and ten embedded 2,500×2,000 images. Each image is created
through `RasterResourceLoader.embedded`, all ten are decoded and retained by
`ApprovedImageCache.approve`, the cache asserts exactly 50,000,000 approved
pixels, and `CoreGraphicsRenderer.render` receives the approved snapshot.
Measurement uses `/usr/bin/time -l` maximum resident set size.

The pre-existing Phase 1 PRD supplies the ceilings; they were not chosen from the
observed result:

- settled representative render: 500 MiB (`524,288,000` bytes);
- production Core Graphics/ImageIO PNG export: 650 MiB (`681,574,400` bytes).

| Scenario | Observed peak | Ceiling | Result |
|---|---:|---:|---|
| Settled render | 215,400,448 bytes | 524,288,000 bytes | LOCAL PASS; 308,887,552-byte headroom |
| PNG export | 224,149,504 bytes | 681,574,400 bytes | LOCAL PASS; 457,424,896-byte headroom |
| Forced 550 MiB extra allocation | 791,642,112 bytes | 524,288,000 bytes | Expected FAIL/nonzero exit |

### Code area

- `Sources/R4GateHarness/main.swift`
  - `representativeDocument()`
  - `settle(_:)`
  - `exportPNG(_:)`
- `scripts/check-peak-memory.sh`
- `scripts/test-peak-memory-gate.sh`
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
| 100 distinct PIDs | 10,000 | 0 | 0 | 0 | 0 | 5 s aggregate wall clock |

### Code area

- `Sources/VectorFoundryApp/main.swift`, `--smoke` branch
- `scripts/nightly-reliability.sh`
- `.github/workflows/ci.yml`, job `nightly-reliability`

The loop is sequential. `--smoke` bypasses AppKit window/UI initialization and
runs only 100 codec cycles, explaining why its roughly 16–17 ms inner duration
differs from the roughly 140 ms UI startup probe. The artifact records every
PID, external process-wall duration and inner smoke duration. This result was
produced on the owner-approved minimum-OS environment, macOS 15.7.5, in the
same session as the full-app startup artifact and closes BLOCK-002. The separate
hosted reliability job remains pending.

## Benchmark and ratio gate

### Fresh BENCH-R3.5 result

The current-tree run uses the sealed BENCH-R3.5 definitions and targets, rather
than reusing its old measurements. Each timed scenario uses a 60-frame warm-up
and 300 measured frames through production rendering/cache paths.

| Scenario | p50 | p95 | Maximum/settle | Target | Result |
|---|---:|---:|---:|---:|---|
| BENCH-1 drag | 5.030 ms | 5.518 ms | 7.496 ms | p95 <= 16.7 ms | PASS |
| BENCH-2 pan | 0.088 ms | 0.113 ms | 0.166 ms | p95 <= 16.7 ms | PASS |
| BENCH-2b forced exposure | 5.443 ms | 5.987 ms | 7.352 ms | p95 <= 16.7 ms | PASS |
| BENCH-3 zoom | 2.450 ms | 9.043 ms | 10.428 ms | p95 <= 33 ms | PASS |
| BENCH-3 settle | — | — | 2.990 ms | <= 100 ms | PASS |
| BENCH-4 cold full redraw | — | — | 9.088 ms | Informational | RECORDED |
| Warm full redraw | — | — | 4.319 ms | Informational | RECORDED |

BENCH-2b recorded nonzero strip redraws for all 360 warm-up and measured frames.
This is an assertion, not observation: `Sources/RenderBenchmark/main.swift`
checks `current > priorStripCount` with `precondition` inside every BENCH-2b
frame. A zero-strip frame traps the harness and produces a nonzero process exit.

### Ratio enforcement

- Threshold: every BENCH-1/2/2b/3 p95 and BENCH-3 settle value must be at most
  1.25 times baseline. Exact decimal arithmetic makes equality inclusive;
  six-decimal ratio rendering is display-only.
- Missing, empty, unknown or expired baselines fail closed.
- The committed baseline expires on 2026-10-10.
- The passing fixture remains below threshold.
- The exact-boundary fixture passes every metric at exactly 1.25.
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
- `benchmarks/owner-reference-macos15-arm64-baseline.tsv`
- `.github/workflows/ci.yml`, job `benchmark`

The committed baseline came from the accepted owner-reference run at `d68f415`.
It is not represented as a hosted-runner baseline. BLOCK-006 needs a real hosted
run, retained artifact and run URL.

GitHub-hosted timing variance may make 1.25 flap. The threshold may only change
through an explicit owner decision; it must never be silently loosened.

## Adversarial corpus reproducibility

### Generator

- Seed for each corpus: `UInt64(0x00000000A110F00D)` = `2,702,241,805`.
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
- `benchmarks/owner-reference-macos15-arm64-baseline.tsv`

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

### BLOCK-002 — macOS 15 runtime — completed at `f6ec81a`

Executed on the owner-reference real macOS 15.x Apple Silicon Mac:

```sh
git switch remediation/pre-phase5
git rev-parse HEAD
swift --version
sw_vers
system_profiler SPHardwareDataType
scripts/nightly-reliability.sh artifacts/r4/macos15-reliability-100x100.txt
scripts/check-startup-p95.sh 20 artifacts/r4/macos15-startup-p95.txt
```

Before committing the artifact, remove serial number, hardware UUID,
provisioning UDID and similar device identifiers from both artifacts. Retain
model identifier, SoC, RAM, macOS build, toolchain, revision and command in both;
retain all 100 reliability launch rows and summary plus all 20 startup samples
and its nearest-rank summary. The startup p95 target remains 2,000 ms.

This is frozen owner decision **Option A**, adopted by TN LEE on 2026-07-13.
BLOCK-002 closed with both artifacts from the same session and machine.
Option B, accepting codec-only smoke as sufficient, was rejected and may not be
substituted without another explicit owner decision.

### BLOCK-003/004/005/006 — qualifying hosted execution and benchmark proof

1. Configure/push to the intended Git remote.
2. Show `startup-memory`, `nightly-reliability`, `benchmark`, and
   `adversarial-golden` green on the final candidate revision.
3. Retain every corresponding artifact, including `benchmark-results`,
   `benchmark-comparison`, startup/memory, reliability and adversarial/golden
   output, plus the run URL.
4. Replace/bootstrap the baseline only from that reviewed green hosted run,
   recording source commit, URL/artifact, date and 90-day expiry.
5. Rerun the ratio gate against the hosted baseline.
6. Commit the proof and update BLOCK-003/004/005/006.

### Final closure sequence

Only after the remaining hosted proof passes:

1. As a mandatory A7 human spot-check, open and inspect
   `artifacts/r4/a6-test-existence.txt`, `artifacts/r4/revision-map.md`, and the
   exact 14-row test-name table in `docs/remediation/A6-R3-checkpoint.md`; do
   not accept a summary in place of these files.
2. Update A7 and A8 to `CLOSED` and BLOCK-003/004/005/006/012 to `CLOSED` as their hosted evidence permits.
3. Update the checkpoint/re-audit with the exact hosted and macOS 15 results.
4. Rerun every gate affected by any code/script/CI change.
5. Commit the final evidence.
6. Create annotated tag `pre-phase5-remediation` on the proven revision.
7. Record the exact tag target in `docs/PROJECT_STATE.md` and the checkpoint.

## Review conclusion

Current verdict: **FAILED — PHASE 5 REMAINS BLOCKED**.
