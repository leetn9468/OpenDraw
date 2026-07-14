# Hosted CI run #4 triage

Date: 2026-07-14

Run: <https://github.com/leetn9468/OpenDraw/actions/runs/29327190429>

Run revision: `8c157cbc30f1af7af1ff4e86d16024db6847e25b`

Corrective build-input revision: `ce3b4b32d0b9c0d7a4ba7112dc1dcc67efb3151c`

Disposition: CI #4 is a failed, non-qualifying push run. No qualifying run was
dispatched during this triage. No threshold, target, tolerance, retry policy,
ceiling, gate comparison, or VERIFY value changed.

## STEP-1 — commit scope

Full requested command output:

```text
8c157cb (HEAD -> remediation/pre-phase5, origin/remediation/pre-phase5) docs: correct hosted closure criteria and evidence map
 artifacts/r4/revision-map.md | 44 ++++++++++++++++++++++----------------------
 docs/PROJECT_STATE.md        |  8 ++++----
 docs/phase-4/ci-policy.md    | 11 +++++++----
 3 files changed, 33 insertions(+), 30 deletions(-)
```

Exact paths were limited to `artifacts/r4/revision-map.md`,
`docs/PROJECT_STATE.md`, and `docs/phase-4/ci-policy.md`. The executable/build
input diff from `d1edd2f` to `8c157cb` is empty. Runs #3 and #4 therefore
executed identical workflow, scripts, sources, tests, package, resources, and
thresholds.

## STEP-2 — raw failures

### debug-release, step 7

The debug invocation passed. The release invocation failed in
`atomicSaveAndLoad()` with `DurableWriteError.systemCall("close", 9)` (`EBADF`).
The requested surrounding 20 raw log lines are:

```text
2026-07-14T10:59:08.9741920Z ◇ Test directionHandleMovementUsesDocumentDeltaAndIsUndoable() started.
2026-07-14T10:59:08.9742450Z ◇ Test verify008DirectAggregateAssetBoundaryFixtures() started.
2026-07-14T10:59:08.9742840Z ◇ Test verify005GroupBoundsFrozenExamples() started.
2026-07-14T10:59:08.9743190Z ◇ Test commandUndoRedoAndBranch() started.
2026-07-14T10:59:08.9743500Z ◇ Test alignmentIsUndoable() started.
2026-07-14T10:59:08.9743940Z ◇ Test snapshotHistorySharesEmbeddedAssetsAndHonorsMemorySafetyNet() started.
2026-07-14T10:59:08.9744420Z ◇ Test historyLimitIsImmutableAndCappedAtThirty() started.
2026-07-14T10:59:08.9744900Z ◇ Test groupUngroupAndCompoundReleasePreserveVisualBounds() started.
2026-07-14T10:59:08.9745360Z ◇ Test verify020NestedDocumentTransformComposition() started.
2026-07-14T10:59:08.9745840Z ◇ Test verify019DocumentDeltaIncludesOwnAndAncestorTransforms() started.
2026-07-14T10:59:08.9746520Z ✘ Test atomicSaveAndLoad() recorded an issue at DocumentFormatsTests.swift:40:2: Caught error: systemCall("close", 9)
2026-07-14T10:59:08.9747160Z ✔ Test testVerify016EightHandleScaleMapping() passed after 0.491 seconds.
2026-07-14T10:59:08.9747630Z ✔ Test testVerify017SmoothAnchorSymmetry() passed after 0.491 seconds.
2026-07-14T10:59:08.9748160Z ✔ Test testVerify013PivotRotationAndHalfAwaySnapping() passed after 0.491 seconds.
2026-07-14T10:59:08.9749030Z ✔ Test preciseSelectionRejectsBoundsFalsePositiveAndRespectsLockedLayers() passed after 0.491 seconds.
2026-07-14T10:59:08.9749690Z ✔ Test testVerify018ScreenSpaceSnappingTolerance() passed after 0.491 seconds.
2026-07-14T10:59:08.9750470Z ✔ Test accessibilityTreeExposesDocumentLayersSelectionAndFrames() passed after 0.491 seconds.
2026-07-14T10:59:08.9751070Z ✔ Test spatialIndexReturnsNearbyCandidates() passed after 0.491 seconds.
2026-07-14T10:59:08.9751550Z ✔ Test penStateCreatesOpenAndClosedPaths() passed after 0.491 seconds.
2026-07-14T10:59:08.9752110Z ✔ Test smoothPenCreatesMirroredHandlesPreviewAndClosedPath() passed after 0.491 seconds.
```

### startup-memory, step 5

The normal settle and export gates passed. The forced-overallocation fixture
expected its unchanged 550 MiB allocation to make the unchanged 500 MiB settle
ceiling fail, but observed only 442,613,760 bytes and therefore returned
success. The wrapper correctly rejected that unexpected success.

```text
2026-07-14T10:57:59.2035940Z ##[group]Run scripts/check-peak-memory.sh artifacts/r4/peak-memory.txt
2026-07-14T10:57:59.2036620Z scripts/check-peak-memory.sh artifacts/r4/peak-memory.txt
2026-07-14T10:57:59.2074580Z shell: /bin/bash -e {0}
2026-07-14T10:57:59.2074930Z ##[endgroup]
2026-07-14T10:58:01.8760320Z R4_MEMORY_SCENARIO=settle objects=1000 anchors=10000 decodedImages=10 decodedPixels=50000000 extraBytes=0
2026-07-14T10:58:01.8834890Z settle peak_bytes=214220800 limit_bytes=524288000 result=PASS
2026-07-14T10:58:02.1025070Z R4_MEMORY_SCENARIO=export objects=1000 anchors=10000 decodedImages=10 decodedPixels=50000000 extraBytes=0
2026-07-14T10:58:02.1087340Z export peak_bytes=222429184 limit_bytes=681574400 result=PASS
2026-07-14T10:58:02.1354000Z ##[group]Run scripts/test-peak-memory-gate.sh artifacts/r4/peak-memory-failure-fixture.txt
2026-07-14T10:58:02.1354660Z scripts/test-peak-memory-gate.sh artifacts/r4/peak-memory-failure-fixture.txt
2026-07-14T10:58:02.1387630Z shell: /bin/bash -e {0}
2026-07-14T10:58:02.1387830Z ##[endgroup]
2026-07-14T10:58:03.8743220Z R4_MEMORY_SCENARIO=settle objects=1000 anchors=10000 decodedImages=10 decodedPixels=50000000 extraBytes=576716800
2026-07-14T10:58:03.8919620Z settle peak_bytes=442613760 limit_bytes=524288000 result=PASS
2026-07-14T10:58:04.2560430Z R4_MEMORY_SCENARIO=export objects=1000 anchors=10000 decodedImages=10 decodedPixels=50000000 extraBytes=576716800
2026-07-14T10:58:04.2652330Z export peak_bytes=593100800 limit_bytes=681574400 result=PASS
2026-07-14T10:58:04.2692220Z Expected forced over-allocation scenario to fail
2026-07-14T10:58:04.2708440Z ##[error]Process completed with exit code 1.
2026-07-14T10:58:04.2993550Z ##[group]Run actions/upload-artifact@v7
2026-07-14T10:58:04.2993840Z with:
```

## STEP-3 — classification and root causes

Both failures are Branch A defects.

### Descriptor ownership race

`DurableFileWriter.write` closed its temporary-file descriptor successfully,
then a later injected fault entered `catch`, which unconditionally closed the
same integer again. Because descriptors are process-global and tests execute
concurrently, another writer could reuse that integer between the first and
second close. The stale cleanup then closed the other writer's live descriptor.

This reproduced locally on unchanged `8c157cb`: a 30-run release stress stopped
at iteration 15 when `linkedResourceResolverRejectsTraversalAndSymlinkEscape`
failed with an underlying POSIX `EBADF`. A focused regression that opens a
sentinel descriptor in the post-close fault hook failed on the old code because
`Darwin.write` returned `-1` instead of `1`.

Fix `ce3b4b3` tracks whether the writer still owns the descriptor and only
closes it during error cleanup while it remains open. The focused regression
then passed, followed by 30/30 complete release-suite repetitions with 90 tests
and no `EBADF`.

### Compressible forced-memory allocation

The failure fixture used `[UInt8](repeating: 0xA5, count: 550 MiB)`. Uniform
pages are highly compressible, so hosted maximum RSS did not reliably include
the requested resident increment:

| Hosted run | Startup p95 | Normal settle/export | Forced settle versus 500 MiB | Fixture outcome |
|---|---:|---:|---:|---|
| #1, `834526c` | 234.344 ms | 214,351,872 / 223,985,664 | 709,771,264 | required FAIL reached |
| #3, `d1edd2f` | 113.375 ms | 213,991,424 / 223,526,912 | 540,475,392 | required FAIL reached |
| #4, `8c157cb` | 97.533 ms | 214,220,800 / 222,429,184 | 442,613,760 | unexpected PASS |

The production memory results were stable; only the artificial uniform
allocation's observed residency varied. Fix `ce3b4b3` keeps the exact 550 MiB
allocation and every ceiling unchanged, but fills those pages through
`arc4random_buf` so they cannot collapse into a highly compressible uniform
pattern. Five focused post-fix local runs all reached 791,412,736–791,904,256
bytes and produced the required gate failure.

No timing gate flapped: all three hosted startup p95 values were at most
234.344 ms against 2,000 ms. The two run-#4 failures were therefore not the
owner-only hosted timing-policy branch.

## Corrective local battery at `ce3b4b3`

| Gate | Result |
|---|---|
| Formatting; debug/release build | PASS |
| Debug/release tests | 90/90 PASS |
| AddressSanitizer | 90/90 PASS |
| Coverage | 87.94% ≥ 55% |
| Dependency direction; clean room | PASS |
| macOS 15 target; symbol graph | PASS |
| Adversarial; golden; UI/accessibility | 2/2, 1/1, 2/2 PASS |
| A6 exact filter; AUDIT-005/006 | 19/19, 2/2 PASS |
| Release assembly/signature | PASS; arm64, hardened-runtime ad-hoc |
| Startup | p50 137.502, p95 143.960, max 170.319 ms; PASS |
| Memory settle/export | 214,564,864 / 224,821,248 bytes; PASS |
| Forced-memory fixture | 791,560,192 > 524,288,000; required failure reached; PASS |
| Reliability | 100 processes, 10,000 cycles, zero failures; PASS |
| BENCH-1/2/2b/3 p95 | 5.403 / 0.107 / 5.915 / 8.880 ms; PASS |
| BENCH-3 settle | 3.044 ms; PASS |
| BENCH-2b strips | 360/360 nonzero; PASS |
| Benchmark ratios/fixtures | largest current ratio 1.095752; exact 1.25 PASS; 1.314801 FAIL as required |

Frozen VERIFY-001–021, benchmark targets, memory ceilings, startup target,
coverage floor, ratio, tolerances, retry policy, and workflow semantics are
unchanged.

## STEP-4 — qualifying-run plan

After this evidence is committed, the operator must push the final evidence
revision and manually dispatch `CI` on `remediation/pre-phase5`. The resulting
run must report event `workflow_dispatch`, execute all eight jobs, and make all
eight green. Push-triggered partial runs do not qualify. BLOCK-003/004/005/006,
A7/A8, and the Phase 5 tag remain untouched until that external result is
independently verified.
