# A6 — R3/R3-B checkpoint closure package

Status: **CLOSED locally and revalidated at final build-input revision `f6ec81a`**

The original owner directive defines fourteen R3-B feature groups. This table
uses those groups without merging them into R4 labels. Swift Testing functions
are file-scope tests, so the exact test file and function name are given instead
of inventing an XCTest class.

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

Grep-level existence proof for every unique method named above is retained at
`artifacts/r4/a6-test-existence.txt`. The exact combined filter and its 19-test
pass output are retained at `artifacts/r4/a6-filtered-tests.txt`, both produced
on `f6ec81a`.

## A6 final-revision gates

The complete battery reran on `f6ec81a` after the owner-directed macOS 15
platform-floor change. Environment: `MacBookPro18,2`, Apple
M1 Max, 64 GB RAM, macOS 15.7.5 build 24G624, arm64, Apple Swift 6.1.2.

| Gate | Result |
|---|---|
| Debug build/tests | PASS; 89 tests, 2.419 s |
| Release build/tests | PASS; 89 tests, 1.136 s |
| AddressSanitizer | PASS; 89 tests, 11.715 s |
| Module dependency and forbidden-import scripts | PASS |
| VERIFY-020 / VERIFY-021 | PASS in the all-tests runs; values unchanged |

### VERIFY / numeric-policy declaration

No additional production mathematical surface was introduced after
VERIFY-020/021. The startup/benchmark nearest-rank percentile, exact-decimal
inclusive ratio threshold, inclusive/floored golden tolerance, and wrapping LCG
are explicitly classified as gate/test-side numeric policies. Their computation
sites contain policy comments and their worked boundary/degenerate examples are
documented in `docs/phase-4/ci-policy.md`. They do not alter product geometry or
document semantics and therefore do not require VERIFY-022.

## Fresh current-tree BENCH-R3.5 run

The run uses the sealed scenario definitions and targets; it does not reuse the
sealed measurements. Command: `scripts/run-render-benchmark.sh
artifacts/r4/render-benchmark.txt`. Every timed scenario used 60 warm-up frames
and 300 measured frames.

| Scenario | p50 | p95 | max / settle | Target | Result |
|---|---:|---:|---:|---:|---|
| BENCH-1 drag | 5.029 ms | 5.408 ms | 5.611 ms | p95 <= 16.7 ms | PASS |
| BENCH-2 pan | 0.087 ms | 0.107 ms | 0.133 ms | p95 <= 16.7 ms | PASS |
| BENCH-2b forced exposure | 5.415 ms | 5.815 ms | 6.161 ms | p95 <= 16.7 ms and strips every frame | PASS; precondition covers 360/360 frames |
| BENCH-3 zoom | 2.391 ms | 9.162 ms | 10.436 ms | p95 <= 33 ms | PASS |
| BENCH-3 settle | — | — | 2.776 ms | <= 100 ms | PASS |
| BENCH-4 cold full redraw | — | — | 8.326 ms | informational | RECORDED |
| Warm full redraw | — | — | 4.871 ms | informational | RECORDED |

## R3/R3-B audit-finding closure mapping

| Audited finding group | Closure evidence |
|---|---|
| Unbounded history / embedded-asset snapshot multiplication | `snapshotHistorySharesEmbeddedAssetsAndHonorsMemorySafetyNet`, `historyLimitIsImmutableAndCappedAtThirty` |
| Cache identity, locking, resolution and allocation | revision-keyed `SceneBitmapCache`; dependency/ASan runs; `representativeDocumentRenderBenchmark` |
| Damage ambiguity/disconnection and slow interaction | VERIFY-015, `damageRegionStatesAreExplicit`, BENCH-1/2/2b/3 artifact |
| Precise selection and hidden/locked behavior | R3-B row 1 |
| Direct selection, toolbar and enabled-state gaps | R3-B row 2 and `CanvasView` validation paths |
| Pen completion | R3-B row 3 and VERIFY-017 |
| Transform and snapping gaps | R3-B rows 4–5 and VERIFY-013/014/016/018/020/021 |
| Missing New/properties/layers/alignment/gradient/text/image/group/compound/zoom/pan flows | R3-B rows 6–14 and expanded headless UI journey |
| No end-to-end UI journey | `headlessUIJourneyCreateStyleTransformSaveReopenAndExport` |
| Accessibility tree absent | `accessibilityTreeExposesDocumentLayersSelectionAndFrames` |
