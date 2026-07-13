# A6 — R3/R3-B checkpoint closure package

Status: **CLOSED locally at final implementation/gate revision `6de4bce`**

The original owner directive defines fourteen R3-B feature groups. This table
uses those groups without merging them into R4 labels. Swift Testing functions
are file-scope tests, so the exact test file and function name are given instead
of inventing an XCTest class.

| # | Required feature | Exact production symbol and file | Exact permanent integration test(s) | Implementation commits | Result |
|---:|---|---|---|---|---|
| 1 | Precise selection, visibility and locking | `SelectionTool.hitTest` in `Sources/EditorTools/SelectionTool.swift`; `CanvasView.mouseDown` in `Sources/VectorFoundryApp/main.swift` | `Tests/EditorToolsTests/EditorToolsTests.swift::preciseSelectionRejectsBoundsFalsePositiveAndRespectsLockedLayers`; `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport` | `f12920f`, `3815904` | PASS |
| 2 | Direct selection: anchors, handles, multi-drag, delete, toolbar | `SceneCommands.moveAnchor`, `moveControl`, `deleteAnchor` in `Sources/EditorCommands/SceneCommands.swift`; `CanvasView.mouseDown/mouseDragged` | `Tests/DocumentModelTests/DirectAnchorVerifyTests.swift::verify019DocumentDeltaIncludesOwnAndAncestorTransforms`, `directAnchorDeletionIsUndoable`, `directionHandleMovementUsesDocumentDeltaAndIsUndoable`; headless UI journey | `8ed6d00`, `73b16bf`, `95fd622`, `b99aa94`, `8df64e4` | PASS |
| 3 | Pen corner/smooth anchors, preview, close/open finish | `SmoothPenToolState.addCorner/addSmooth/preview/finish` in `Sources/EditorTools/CreationTools.swift`; `CanvasView.mouseDown/mouseDragged/keyDown` | `Tests/EditorToolsTests/EditorToolsTests.swift::smoothPenCreatesMirroredHandlesPreviewAndClosedPath`; headless UI journey | `455eac7`, `d416162` | PASS |
| 4 | Eight-handle scale and pivot rotation | `TransformInteractions.scale/rotation/snappedRotation` in `Sources/EditorTools/TransformInteractions.swift`; `EditorDocument.applyDocumentTransform` in `Sources/DocumentModel/Document.swift` | `Tests/EditorToolsTests/EditorToolsTests.swift::testVerify013PivotRotationAndHalfAwaySnapping`, `testVerify016EightHandleScaleMapping`; `Tests/DocumentModelTests/DocumentTransformVerifyTests.swift::verify020NestedDocumentTransformComposition`; headless UI journey | `9fdd523`, `21051fb`, `d85ae4b` | PASS |
| 5 | Guide/grid/object snapping, indicators and toggle | `SnapPolicy.snap` in `Sources/EditorTools/CreationTools.swift`; `CanvasView.snappedPoint/toggleSnapping` | `Tests/EditorToolsTests/EditorToolsTests.swift::testVerify018ScreenSpaceSnappingTolerance`, `verify021AxisSnapCandidates`; headless UI journey | `1731c6a`, `72bd44d` | PASS |
| 6 | Validated New-document flow | `AppDelegate.newDocument/promptForNewDocument` in `Sources/VectorFoundryApp/main.swift`; `EditorDocument.init` in `Sources/DocumentModel/Document.swift` | `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport` | `32c110a` | PASS |
| 7 | Complete implemented path-properties panel | `CanvasView.editSelectedProperties` in `Sources/VectorFoundryApp/main.swift`; `EditorDocument.mutatePath` | headless UI journey; `Tests/DocumentModelTests/DocumentModelTests.swift::advancedResourceInvariants` | `ef052fc`, `d416162` | PASS |
| 8 | Layer list/reorder/rename/visibility/lock/active layer | `CanvasView.editLayers` in `Sources/VectorFoundryApp/main.swift`; `Layer` in `Sources/DocumentModel/Document.swift` | headless UI journey; `preciseSelectionRejectsBoundsFalsePositiveAndRespectsLockedLayers` | `c4135bd` | PASS |
| 9 | Alignment UI | `CanvasView.alignSelectedLeft`; `AlignmentCommands.align` in `Sources/EditorCommands/AlignmentCommands.swift` | `Tests/DocumentModelTests/DocumentModelTests.swift::alignmentIsUndoable`; headless UI journey | `3815904` | PASS |
| 10 | Gradient assignment and stop editor | `CanvasView.editGradient`; `GradientResource/ColorStop` in `Sources/DocumentModel/Document.swift` | `Tests/DocumentModelTests/DocumentModelTests.swift::advancedResourceInvariants`; headless UI journey | `9e75ed4` | PASS |
| 11 | Point-text creation and font/size editing | `CanvasView.createText/editSelectedProperties`; `TextObject` in `Sources/DocumentModel/Document.swift` | headless UI journey; `Tests/CanvasRenderTests/CanvasRenderTests.swift::expandedAppearanceTextAndImageRender` | `ef052fc`, `d416162` | PASS |
| 12 | Safe linked/embedded image placement | `AppDelegate.placeImage`; `CanvasView.placeEmbeddedImage/placeLinkedImage`; `ApprovedImageCache` and `LinkedResourceResolver` | headless UI journey; `Tests/DocumentFormatsTests/DocumentFormatsTests.swift::rasterLoaderEnforcesLimitsAndSafeLinks`; `Tests/CanvasRenderTests/CanvasRenderTests.swift::rendererUsesOnlyApprovedImagesOrPlaceholder` | `ef052fc`, `c4135bd`, `b05a149` | PASS |
| 13 | Group/Ungroup and Make/Release Compound | `CanvasView.groupSelected/ungroupSelected/makeCompoundSelected/releaseCompoundSelected`; corresponding `SceneCommands` | `Tests/DocumentModelTests/DocumentModelTests.swift::directAnchorGroupUngroupAndCompoundCommandsAreUndoable`; `Tests/DocumentModelTests/DirectAnchorVerifyTests.swift::groupUngroupAndCompoundReleasePreserveVisualBounds`; headless UI journey | `8ed6d00`, `3815904`, `c4135bd`, `95fd622` | PASS |
| 14 | Zoom/pan: commands, cursor zoom, pinch/scroll and space drag | `CanvasView.setZoom/zoomIn/zoomOut/actualSize/zoomToFit/scrollWheel/magnify/keyDown`; `TransformInteractions.zoomAbout` | `Tests/EditorToolsTests/EditorToolsTests.swift::testVerify014ZoomAboutPointDomainAndInvariant`; headless UI journey | `ce4b329`, `bf9daa0` | PASS |

## A6 final-revision gates

Final implementation/gate revision `6de4bce` was tested on `MacBookPro18,2`, Apple
M1 Max, 64 GB RAM, macOS 15.7.5 build 24G624, arm64, Apple Swift 6.1.2.

| Gate | Result |
|---|---|
| Debug build/tests | PASS; 88 tests, 2.421 s |
| Release build/tests | PASS; 88 tests, 1.113 s |
| AddressSanitizer | PASS; 88 tests, 11.270 s |
| Module dependency and forbidden-import scripts | PASS |
| VERIFY-020 / VERIFY-021 | PASS in the all-tests runs; values unchanged |

No additional production mathematical surface was introduced after
VERIFY-020/021. R4 numeric CI/test policies are documented separately and do
not alter product geometry or document semantics.

## Fresh current-tree BENCH-R3.5 run

The run uses the sealed scenario definitions and targets; it does not reuse the
sealed measurements. Command: `scripts/run-render-benchmark.sh
artifacts/r4/render-benchmark.txt`. Every timed scenario used 60 warm-up frames
and 300 measured frames.

| Scenario | p50 | p95 | max / settle | Target | Result |
|---|---:|---:|---:|---:|---|
| BENCH-1 drag | 4.764 ms | 5.056 ms | 5.508 ms | p95 <= 16.7 ms | PASS |
| BENCH-2 pan | 0.087 ms | 0.108 ms | 0.181 ms | p95 <= 16.7 ms | PASS |
| BENCH-2b forced exposure | 5.203 ms | 5.827 ms | 8.853 ms | p95 <= 16.7 ms and strips every frame | PASS; 360/360 frames redrew strips |
| BENCH-3 zoom | 2.408 ms | 8.763 ms | 10.214 ms | p95 <= 33 ms | PASS |
| BENCH-3 settle | — | — | 2.833 ms | <= 100 ms | PASS |
| BENCH-4 cold full redraw | — | — | 8.166 ms | informational | RECORDED |
| Warm full redraw | — | — | 4.724 ms | informational | RECORDED |

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
