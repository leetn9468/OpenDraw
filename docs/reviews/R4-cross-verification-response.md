# R4 cross-verification response — ISSUE-01 through ISSUE-11

Prepared: 2026-07-13  
Branch: `remediation/pre-phase5`  
Final implementation/gate revision: `2884a54`  
Complete-battery revision: `b01364b`  
Evidence/documentation revision: `7cfbf00`

Platform-floor follow-up: the complete battery was subsequently rerun at
`f6ec81a`; BLOCK-002 is closed by the same-session
`macos15-reliability-100x100.txt` and `macos15-startup-p95.txt` artifacts.

Overall verdict remains **FAILED — PHASE 5 BLOCKED**. No
`pre-phase5-remediation` tag exists.

## ISSUE-01 — Fuzz seed hex/decimal mismatch

Source: `Tests/DocumentFormatsTests/AdversarialCorpusTests.swift:9`:

```swift
var state: UInt64 = 0xA110_F00D
```

The executed value was always hexadecimal `0xA110F00D`, decimal
`2,702,241,805`. The source constant did not change across `52c3295`,
`f854389`, or `6de4bce`; those runs therefore used the same value. The incorrect
decimal existed only in documentation. Potential `CORPUS_FAILURE` output embeds
the correct hex and no decimal, and retained passing artifacts contain no failure
record requiring correction.

Commit `7cfbf00` corrects:

- `docs/phase-4/fuzz-results.md`
- `docs/reviews/R4-A6-A7-A8-review-package.md`

The adversarial filter was rerun on `b01364b`; output is
`artifacts/r4/adversarial-tests.txt`.

RESOLVED

## ISSUE-02 — A6 VERIFY / numeric-policy classification

Commit `b01364b` pins the computation sites; commit `7cfbf00` records the
classification and declaration.

| Numeric logic | Classification | Exact pinned policy |
|---|---|---|
| Startup percentile | Gate/test-side | Nearest rank, one-based `ceil(p*n)`. For 20 values p95 is sorted item 19. |
| BENCH percentile | Gate/test-side | Same nearest-rank rule. For 300 values p95 is item 285; one sample selects item 1. |
| Ratio arithmetic | Gate/test-side | Exact decimal strings; inclusive `observed <= baseline * 1.25`; six-decimal ratio is display-only. Exact-boundary fixture passes. |
| Golden tolerance | Gate/test-side | Maximum 92 differing pixels and channel delta 12, both inclusive; zero is the degenerate pass; 93 pixels or delta 13 fails. |
| Mutation LCG | Test-side | Fixed UInt64 seed and wrapping multiplication/addition, used only to regenerate hostile inputs. |

Computation-site excerpts:

```swift
// Sources/RenderBenchmark/main.swift:17–22
// Gate/test-side numeric policy: nearest-rank percentile, one-based rank
func nearestRank(_ samples: [Double], percentile: Double) -> Double {
    let rank = max(1, Int(ceil(percentile * Double(samples.count))))
    return samples[min(samples.count - 1, rank - 1)]
}
```

```sh
# scripts/check-benchmark-regression.sh
# Compare parsed decimal strings exactly and inclusively.
observed <= baseline * allowed
```

```swift
// Tests/CanvasRenderTests/GoldenRenderingTests.swift:72–80
maxChannelDelta <= 12 && differingPixels <= 96 * 96 / 100
```

The permanent golden boundary test is
`goldenToleranceBoundaryPolicyIsInclusive`. `docs/phase-4/ci-policy.md` gives
three percentile examples, boundary/degenerate golden examples, ratio boundary
behavior, and LCG classification.

`docs/remediation/A6-R3-checkpoint.md` now explicitly declares that no new
production mathematical behavior was introduced after VERIFY-020/021. These
policies do not change geometry or document semantics, so VERIFY-022 is not
required. VERIFY-001–021 were not modified.

RESOLVED

## ISSUE-03 — Peak-memory gate validity

The original linked images were placeholders and were not decoded. That defect
is corrected in `b01364b`.

Production-path excerpt from `Sources/R4GateHarness/main.swift:58–65,83–93`:

```swift
let imageData = try embeddedImageData()
let loader = RasterResourceLoader()
var image = try loader.embedded(data: imageData, frame: frame)
// ... ten embedded images ...

let cache = ApprovedImageCache()
try await cache.approve(document)
let approvedImages = await cache.snapshot()
precondition(approvedImages.count == 10)
precondition(awaitedPixelCount == 50_000_000)
CoreGraphicsRenderer().render(document, in: context, approvedImages: approvedImages)
```

The ten embedded images are each 2,500×2,000, decoded through
`RasterResourceLoader` and `ApprovedImageCache`, retained in the settled
scenario, and passed to the renderer.

| Scenario | Observed peak | PRD ceiling | Headroom/result |
|---|---:|---:|---:|
| Settled decoded render | 214,433,792 bytes | 524,288,000 | 309,854,208 bytes |
| PNG export | 224,395,264 bytes | 681,574,400 | 457,179,136 bytes |
| Forced 550 MiB extra allocation | 791,822,336 bytes | 524,288,000 | Expected FAIL/nonzero exit |

The ceilings remain the original PRD-derived 500 MiB/650 MiB values.
`scripts/test-peak-memory-gate.sh` proves failure behavior. Evidence:

- `artifacts/r4/peak-memory.txt`
- `artifacts/r4/peak-memory-failure-fixture.txt`

BLOCK-003 remains `OPEN — LOCAL PASS, HOSTED PENDING` solely because its first
hosted CI execution has not occurred.

RESOLVED

## ISSUE-04 — Reliability-run plausibility

The 100 processes run sequentially. `VectorFoundry --smoke` branches before
`NSApplication.shared`: it initializes the native codec/sample document and
executes 100 encode/decode cycles, but does not initialize AppKit UI, a window,
toolbar, canvas, autosave timer, or activation. It is therefore not comparable
to the full UI startup probe.

Commit `2884a54` records external process-wall duration correctly with
`/usr/bin/time -p`. The artifact begins:

```text
execution=sequential smoke_path=codec-only ui_initialized=false wall_clock=aggregate-loop-elapsed
launch=1 pid=96436 process_wall_ms=20.000 smoke_ms=16.331 exit=0 round_trips=100
launch=2 pid=96451 process_wall_ms=20.000 smoke_ms=16.688 exit=0 round_trips=200
```

and ends:

```text
launch=100 pid=98144 process_wall_ms=20.000 smoke_ms=17.131 exit=0 round_trips=10000
summary launches=100 distinct_pids=100 round_trips=10000 crashes=0 nonzero_exits=0 timeouts=0 corruption_failures=0 wall_clock_seconds=5 result=PASS
```

The five seconds are aggregate wall-clock time for the sequential shell loop,
not a sum of inner smoke durations. The exact same script semantics, watchdog,
PID checks, and output format apply to the future macOS 15 run, making the
artifacts comparable.

Evidence: `artifacts/r4/reliability-100x100.txt`.

RESOLVED

## ISSUE-05 — A6 test existence and per-item exact names

The full fourteen-row table is reproduced verbatim from
`docs/remediation/A6-R3-checkpoint.md`:

| # | Required feature | Exact production symbol and file | Exact permanent integration test(s) | Implementation commits | Result |
|---:|---|---|---|---|---|
| 1 | Precise selection, visibility and locking | `SelectionTool.hitTest` in `Sources/EditorTools/SelectionTool.swift`; `CanvasView.mouseDown` in `Sources/VectorFoundryApp/main.swift` | `Tests/EditorToolsTests/EditorToolsTests.swift::preciseSelectionRejectsBoundsFalsePositiveAndRespectsLockedLayers`; `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport` | `f12920f`, `3815904` | PASS |
| 2 | Direct selection: anchors, handles, multi-drag, delete, toolbar | `SceneCommands.moveAnchor`, `moveControl`, `deleteAnchor` in `Sources/EditorCommands/SceneCommands.swift`; `CanvasView.mouseDown/mouseDragged` | `Tests/DocumentModelTests/DirectAnchorVerifyTests.swift::verify019DocumentDeltaIncludesOwnAndAncestorTransforms`; `Tests/DocumentModelTests/DirectAnchorVerifyTests.swift::directAnchorDeletionIsUndoable`; `Tests/DocumentModelTests/DirectAnchorVerifyTests.swift::directionHandleMovementUsesDocumentDeltaAndIsUndoable`; `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport` | `8ed6d00`, `73b16bf`, `95fd622`, `b99aa94`, `8df64e4` | PASS |
| 3 | Pen corner/smooth anchors, preview, close/open finish | `SmoothPenToolState.addCorner/addSmooth/preview/finish` in `Sources/EditorTools/CreationTools.swift`; `CanvasView.mouseDown/mouseDragged/keyDown` | `Tests/EditorToolsTests/EditorToolsTests.swift::smoothPenCreatesMirroredHandlesPreviewAndClosedPath`; `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport` | `455eac7`, `d416162` | PASS |
| 4 | Eight-handle scale and pivot rotation | `TransformInteractions.scale/rotation/snappedRotation` in `Sources/EditorTools/TransformInteractions.swift`; `EditorDocument.applyDocumentTransform` in `Sources/DocumentModel/Document.swift` | `Tests/EditorToolsTests/EditorToolsTests.swift::testVerify013PivotRotationAndHalfAwaySnapping`; `Tests/EditorToolsTests/EditorToolsTests.swift::testVerify016EightHandleScaleMapping`; `Tests/DocumentModelTests/DocumentTransformVerifyTests.swift::verify020NestedDocumentTransformComposition`; `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport` | `9fdd523`, `21051fb`, `d85ae4b` | PASS |
| 5 | Guide/grid/object snapping, indicators and toggle | `SnapPolicy.snap` in `Sources/EditorTools/CreationTools.swift`; `CanvasView.snappedPoint/toggleSnapping` | `Tests/EditorToolsTests/EditorToolsTests.swift::testVerify018ScreenSpaceSnappingTolerance`; `Tests/EditorToolsTests/EditorToolsTests.swift::verify021AxisSnapCandidates`; `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport` | `1731c6a`, `72bd44d` | PASS |
| 6 | Validated New-document flow | `AppDelegate.newDocument/promptForNewDocument` in `Sources/VectorFoundryApp/main.swift`; `EditorDocument.init` in `Sources/DocumentModel/Document.swift` | `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport` | `32c110a` | PASS |
| 7 | Complete implemented path-properties panel | `CanvasView.editSelectedProperties` in `Sources/VectorFoundryApp/main.swift`; `EditorDocument.mutatePath` | `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport`; `Tests/DocumentModelTests/DocumentModelTests.swift::advancedResourceInvariants` | `ef052fc`, `d416162` | PASS |
| 8 | Layer list/reorder/rename/visibility/lock/active layer | `CanvasView.editLayers` in `Sources/VectorFoundryApp/main.swift`; `Layer` in `Sources/DocumentModel/Document.swift` | `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport`; `Tests/EditorToolsTests/EditorToolsTests.swift::preciseSelectionRejectsBoundsFalsePositiveAndRespectsLockedLayers` | `c4135bd` | PASS |
| 9 | Alignment UI | `CanvasView.alignSelectedLeft`; `AlignmentCommands.align` in `Sources/EditorCommands/AlignmentCommands.swift` | `Tests/DocumentModelTests/DocumentModelTests.swift::alignmentIsUndoable`; `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport` | `3815904` | PASS |
| 10 | Gradient assignment and stop editor | `CanvasView.editGradient`; `GradientResource/ColorStop` in `Sources/DocumentModel/Document.swift` | `Tests/DocumentModelTests/DocumentModelTests.swift::advancedResourceInvariants`; `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport` | `9e75ed4` | PASS |
| 11 | Point-text creation and font/size editing | `CanvasView.createText/editSelectedProperties`; `TextObject` in `Sources/DocumentModel/Document.swift` | `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport`; `Tests/CanvasRenderTests/CanvasRenderTests.swift::expandedAppearanceTextAndImageRender` | `ef052fc`, `d416162` | PASS |
| 12 | Safe linked/embedded image placement | `AppDelegate.placeImage`; `CanvasView.placeEmbeddedImage/placeLinkedImage`; `ApprovedImageCache` and `LinkedResourceResolver` | `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport`; `Tests/DocumentFormatsTests/DocumentFormatsTests.swift::rasterLoaderEnforcesLimitsAndSafeLinks`; `Tests/CanvasRenderTests/CanvasRenderTests.swift::rendererUsesOnlyApprovedImagesOrPlaceholder` | `ef052fc`, `c4135bd`, `b05a149` | PASS |
| 13 | Group/Ungroup and Make/Release Compound | `CanvasView.groupSelected/ungroupSelected/makeCompoundSelected/releaseCompoundSelected`; corresponding `SceneCommands` | `Tests/DocumentModelTests/DocumentModelTests.swift::directAnchorGroupUngroupAndCompoundCommandsAreUndoable`; `Tests/DocumentModelTests/DirectAnchorVerifyTests.swift::groupUngroupAndCompoundReleasePreserveVisualBounds`; `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport` | `8ed6d00`, `3815904`, `c4135bd`, `95fd622` | PASS |
| 14 | Zoom/pan: commands, cursor zoom, pinch/scroll and space drag | `CanvasView.setZoom/zoomIn/zoomOut/actualSize/zoomToFit/scrollWheel/magnify/keyDown`; `TransformInteractions.zoomAbout` | `Tests/EditorToolsTests/EditorToolsTests.swift::testVerify014ZoomAboutPointDomainAndInvariant`; `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport` | `ce4b329`, `bf9daa0` | PASS |

`artifacts/r4/a6-test-existence.txt` contains one successful `rg -n` result with
file and line for every unique test name above. The exact combined filter is
retained in the command record and `artifacts/r4/a6-filtered-tests.txt` reports:

```text
Test run with 19 tests passed
```

Rows 6/7/8/11/12 now use exact file/function names, not descriptive aliases.

RESOLVED

## ISSUE-06 — Revision accounting and artifact stamps

`artifacts/r4/revision-scope-proof.txt` contains the requested `git show --stat`
output. It confirms:

- `6de4bce` changed only
  `Tests/DocumentFormatsTests/AdversarialCorpusTests.swift`;
- `f44b7e4` changed README/docs and committed `artifacts/r4`, with no
  `Sources`, `Tests`, scripts, `Package.swift`, or workflow change;
- `b01364b` contains the corrected source/test/script/CI gate work;
- `2884a54` changes only `scripts/nightly-reliability.sh`.

Every retained artifact is mapped in `artifacts/r4/revision-map.md`. The full
battery ran on `b01364b`; only the reliability log was invalidated by
`2884a54`, and it was rerun on that revision.

Lineage command result:

```text
git merge-base --is-ancestor 14de9b3 f44b7e4
exit=0
```

The previously reviewed candidate remains an ancestor; no rebase or history
rewrite occurred.

RESOLVED

## ISSUE-07 — Hosted execution closure language

Commit `7cfbf00` changes `docs/PROJECT_STATE.md`, the checkpoint, CI policy and
review package so:

- BLOCK-003 is `OPEN — LOCAL PASS, HOSTED PENDING`;
- BLOCK-004 is `OPEN — LOCAL PASS, HOSTED PENDING`;
- BLOCK-005 is `OPEN — LOCAL PASS, HOSTED PENDING`.

At this response revision, BLOCK-006 required the first hosted run to show
`startup-memory`, `nightly-reliability`, `benchmark`, and
`adversarial-golden` green, retaining all artifacts and the run URL. Hosted CI
#1 later ran at `834526c` but did not qualify. The current closure requirement
is one manually dispatched all-eight-jobs-green run; it closes the hosted
execution components of BLOCK-003/004/005 simultaneously.

RESOLVED

## ISSUE-08 — AUDIT-005/006 test existence and pass

Existence proof in `artifacts/r4/audit-005-006-test-existence.txt`:

```text
Tests/DocumentModelTests/DocumentModelTests.swift:61:@Test func failedFirstGestureDoesNotCorruptLaterCoalescing() throws {
Tests/DocumentModelTests/DocumentModelTests.swift:73:@Test func unsavedCoordinatorsAreIndependentAndCancelPreventsReplacement() throws {
```

Focused command:

```sh
swift test --filter 'unsavedCoordinatorsAreIndependentAndCancelPreventsReplacement|failedFirstGestureDoesNotCorruptLaterCoalescing'
```

`artifacts/r4/audit-005-006-filtered-tests.txt` records two tests passed on
`b01364b`.

RESOLVED

## ISSUE-09 — Startup boundary exclusion

Commit `7cfbf00`, `docs/phase-4/ci-policy.md`, states:

> The start boundary explicitly excludes exec, dyld, runtime loading and all
> other pre-main/static-initializer work, so it is not a click-to-window
> measurement.

RESOLVED

## ISSUE-10 — Baseline naming and hosted variance

Commit `b01364b` renames the baseline to:

```text
benchmarks/owner-reference-macos15-arm64-baseline.tsv
```

Its header says `source=owner-reference-MacBookPro18,2-not-hosted`.
`docs/phase-4/ci-policy.md` records that GitHub-hosted timing can vary and that
the 1.25 threshold may only change through an explicit owner decision with
rationale and review. It cannot be silently loosened.

RESOLVED

## ISSUE-11 — BENCH-2b forced-exposure assertion

`Sources/RenderBenchmark/main.swift:115–117` contains:

```swift
let current = stripCache.redrawnStripCount
precondition(current > priorStripCount, "BENCH-2b must redraw a nonzero strip every frame")
priorStripCount = current
```

The assertion runs inside the closure used for all 60 warm-up plus 300 measured
frames. Any zero-strip frame triggers a precondition failure and nonzero harness
exit. The following metadata line is only a report after all assertions pass:

```text
BENCH-2b strip_redraw_frames=360 nonzero_every_frame=true
```

RESOLVED

## Remaining external blockers

The issue resolutions above do not close:

- BLOCK-003/004/005 hosted-execution components;
- BLOCK-006 — hosted run, hosted baseline/comparison artifact and run URL;
- BLOCK-012 — prohibited tag while blockers remain.

Final verdict: **FAILED — PHASE 5 BLOCKED**.
