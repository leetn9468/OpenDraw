# Findings closure matrix

Re-audit date: 2026-07-13. Product-code findings AUDIT-001–008 are closed;
external R4 acceptance blockers are tracked separately in `docs/PROJECT_STATE.md`.

| Finding | Status | Fixing commits | Exact permanent regression evidence | Verification |
|---|---|---|---|---|
| AUDIT-001 transformed bounds | Closed | `6ca6ce1`, `8e98346` | `Tests/DocumentModelTests/VisualBoundsVerifyTests.swift::verify004VisualBoundsFrozenExamples`; `Tests/CanvasRenderTests/CanvasRenderTests.swift::transformedStrokeInkIsContainedByVisualBounds` | VERIFY-004/005 |
| AUDIT-002 lossy SVG export | Closed | `b05a149` | `Tests/DocumentFormatsTests/DocumentFormatsTests.swift::svgExportIsDeterministicAndEscaped`, `svgReportsFeatureLoss`; `Tests/DocumentFormatsTests/UIJourneyTests.swift::headlessUIJourneyCreateStyleTransformSaveReopenAndExport` | VERIFY-010 |
| AUDIT-003 unbounded native load | Closed | `b05a149`, `65cfb1a` | `Tests/DocumentFormatsTests/DocumentFormatsTests.swift::boundedReaderRejectsMetadataBeforeReadAndTruncation`, `nativeDecoderDeterministicMalformedCorpus`; `Tests/DocumentFormatsTests/InputLimitsVerifyTests.swift::verify011JSONDepthAndValueBoundaries`, `verify011SVGElementAndNodeBoundaries`, `verify011SVGStringBoundaries` | VERIFY-011 |
| AUDIT-004 incomplete validation | Closed | `8e98346`, `2f6d3d6` | `Tests/DocumentModelTests/StrictValidationTests.swift::strictValidationRejectsGeometryStyleAndReferences`, `strictValidationEnforcesGlobalIDsAndImageStructure`, `strictValidationPinsNodeCountCeiling`; `Tests/DocumentModelTests/DocumentLimitsVerifyTests.swift::verify008DocumentLimitsFrozenExamples`, `verify008DirectAggregateAssetBoundaryFixtures` | VERIFY-007/008 |
| AUDIT-005 unsaved open loss | Closed | `f12920f` | `Tests/DocumentModelTests/DocumentModelTests.swift::unsavedCoordinatorsAreIndependentAndCancelPreventsReplacement` | Exact permanent test; no separate product-math VERIFY entry |
| AUDIT-006 unsafe drag coalescing | Closed | `f12920f` | `Tests/DocumentModelTests/DocumentModelTests.swift::failedFirstGestureDoesNotCorruptLaterCoalescing`, `historyDirtyCoalescingRollbackAndLimit`, `revisionGestureAndChangeStreamSemantics` | Exact permanent tests; no separate product-math VERIFY entry |
| AUDIT-007 mixed stacking impossible | Closed | `8e98346` | `Tests/DocumentFormatsTests/DocumentFormatsTests.swift::v4RoundTripPreservesMixedOrderGroupsAndCompoundPaths`; `Tests/DocumentModelTests/DirectAnchorVerifyTests.swift::groupUngroupAndCompoundReleasePreserveVisualBounds` | VERIFY-005/009 |
| AUDIT-008 unsafe embedded images | Closed | `b05a149` | `Tests/DocumentFormatsTests/DocumentFormatsTests.swift::rasterLoaderEnforcesLimitsAndSafeLinks`; `Tests/DocumentFormatsTests/ApprovedImageCacheVerifyTests.swift::approvedImageCacheDecodesOffActorAndPublishesSnapshot`; `Tests/CanvasRenderTests/CanvasRenderTests.swift::rendererUsesOnlyApprovedImagesOrPlaceholder` | VERIFY-007/012 |

All exact tests above passed in the 89-test debug, release, and AddressSanitizer
runs on complete-battery revision `b01364b`. VERIFY-001 through VERIFY-021 remain
frozen and verified. This matrix does not close the external macOS 13 runtime or
hosted-CI evidence blockers.

Grep-level existence proof and the focused two-test pass for AUDIT-005/006 are
retained at `artifacts/r4/audit-005-006-test-existence.txt` and
`artifacts/r4/audit-005-006-filtered-tests.txt`.
