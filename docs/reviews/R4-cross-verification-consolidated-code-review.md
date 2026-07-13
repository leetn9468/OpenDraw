# R4 cross-verification — consolidated points and code areas

Prepared: 2026-07-13  
Branch: `remediation/pre-phase5`  
Scope: Claude ISSUE-01–11, the corresponding Codex remediation, affected source/test/gate areas, retained proof, and current blockers  
Implementation and gate revisions: `b01364b`, `2884a54`  
Evidence and state revision: `7cfbf00`  
Detailed issue response revision: `076e1ef`

## Review outcome

All eleven cross-verification issues have committed local resolutions and proof.
This does not authorize Phase 5. The current project verdict remains:

> **FAILED — PHASE 5 BLOCKED**

BLOCK-002 and BLOCK-006 require external execution. Frozen owner decision
Option A requires both codec reliability and full-app startup from the same
real macOS 13 Apple Silicon session; codec-only Option B was rejected.
BLOCK-003/004/005 retain hosted-execution components, and BLOCK-012 prohibits
the Phase 5 tag until the external blockers close. No
`pre-phase5-remediation` tag has been created.

## Commit map

| Commit | Purpose |
|---|---|
| `b01364b` | Decode representative images in the memory harness; demonstrate gate failure; pin percentile, ratio, golden-tolerance and mutation policies; rename the owner-reference benchmark baseline. |
| `2884a54` | Make the reliability run sequential and retain distinct PIDs plus external and inner per-process timing. |
| `7cfbf00` | Record proof artifacts, correct project state, close local evidence gaps, and map artifacts to revisions. |
| `076e1ef` | Commit the mandatory per-issue cross-verification response. |

## ISSUE-01 — Fuzz seed reproducibility

### Finding

Documentation incorrectly equated `0xA110F00D` with `2,703,229,965`. The
actual decimal value is `2,702,241,805`.

### Code area

`Tests/DocumentFormatsTests/AdversarialCorpusTests.swift:6–18`:

```swift
private func mutations(of seed: Data, count: Int) -> [Data] {
    // Test-side deterministic policy: fixed UInt64 seed and wrapping LCG
    // arithmetic. This generator does not define production document behavior.
    var state: UInt64 = 0xA110_F00D
    // ...
    state = state &* 6_364_136_223_846_793_005 &+ 1
}
```

Failure records use the same seed in hexadecimal at line 29:

```swift
print("CORPUS_FAILURE kind=\(kind) index=\(index) seed=0x00000000A110F00D")
```

### Resolution and proof

- Executed seed: `0xA110F00D` / `2,702,241,805`.
- The source constant did not change across `52c3295`, `f854389`, or `6de4bce`.
- The incorrect decimal existed only in documentation; retained failure output
  does not embed it.
- Corrected in `docs/phase-4/fuzz-results.md` and
  `docs/reviews/R4-A6-A7-A8-review-package.md`.
- Final adversarial run: `artifacts/r4/adversarial-tests.txt`.

Status: **RESOLVED**

## ISSUE-02 — A6 numeric-policy and VERIFY classification

### Finding

The initial A6 package omitted the required zero-new-production-math
declaration and did not pin the test/gate-side numeric policies.

### Classification

| Logic | Classification | Frozen rule |
|---|---|---|
| Startup p95 | Gate/test-side | Nearest rank: one-based `ceil(p × n)`; with 20 samples p95 is sorted item 19. |
| Benchmark p50/p95 | Gate/test-side | Same nearest-rank rule; with 300 samples p95 is item 285; one sample selects item 1. |
| Ratio gate | Gate/test-side | Parse decimal strings exactly; accept equality with `observed <= baseline × 1.25`; the six-decimal ratio is display-only. |
| Golden tolerance | Gate/test-side | At most 92 differing pixels and channel delta 12, both inclusive; 93 pixels or delta 13 fails. |
| Mutation LCG | Test-side | Fixed `UInt64` seed with wrapping multiplication/addition; not document behavior. |

No new production mathematical behavior was introduced after VERIFY-020/021.
VERIFY-001–021 were not changed.

### Code areas

`Sources/RenderBenchmark/main.swift:17–35`:

```swift
// Gate/test-side numeric policy: nearest-rank percentile, one-based rank
// ceil(p * sampleCount), converted to a zero-based index.
func nearestRank(_ samples: [Double], percentile: Double) -> Double {
    let rank = max(1, Int(ceil(percentile * Double(samples.count))))
    return samples[min(samples.count - 1, rank - 1)]
}
```

`scripts/check-startup-p95.sh:30–41`:

```sh
# ceil(percent * sampleCount / 100); for 20 samples p95 is item 19.
p50_index=$(((50 * samples + 99) / 100))
p95_index=$(((95 * samples + 99) / 100))
```

`scripts/check-benchmark-regression.sh:31–49`:

```python
from decimal import Decimal
observed, baseline, allowed = map(Decimal, sys.argv[1:])
raise SystemExit(0 if observed <= baseline * allowed else 1)
```

`Tests/CanvasRenderTests/GoldenRenderingTests.swift:70–80`:

```swift
private func goldenDifferencePasses(differingPixels: Int, maxChannelDelta: Int) -> Bool {
    maxChannelDelta <= 12 && differingPixels <= 96 * 96 / 100
}

@Test func goldenToleranceBoundaryPolicyIsInclusive() {
    #expect(goldenDifferencePasses(differingPixels: 0, maxChannelDelta: 0))
    #expect(goldenDifferencePasses(differingPixels: 92, maxChannelDelta: 12))
    #expect(!goldenDifferencePasses(differingPixels: 93, maxChannelDelta: 12))
    #expect(!goldenDifferencePasses(differingPixels: 92, maxChannelDelta: 13))
}
```

### Resolution and proof

- Declaration: `docs/remediation/A6-R3-checkpoint.md`.
- Policy examples and boundaries: `docs/phase-4/ci-policy.md`.
- Exact `1.25` fixture passes; `1.314801` fixture fails.
- Artifact: `artifacts/r4/benchmark-gate-fixtures.txt`.

Status: **RESOLVED**

## ISSUE-03 — Peak-memory gate validity

### Finding

The initial representative images were placeholders and were not decoded, so
the measured memory did not exercise the intended production image path.

### Code area

`Sources/R4GateHarness/main.swift:58–93`:

```swift
let imageData = try embeddedImageData()
let loader = RasterResourceLoader()
for imageIndex in 0..<10 {
    var image = try loader.embedded(data: imageData, frame: frame)
    nodes.append(.image(image))
}

let cache = ApprovedImageCache()
try await cache.approve(document)
let approvedImages = await cache.snapshot()
precondition(approvedImages.count == 10, "All representative images must decode")
precondition(await cache.approvedPixelCount() == 50_000_000)
CoreGraphicsRenderer().render(document, in: context, approvedImages: approvedImages)
```

Failure injection at lines 112–117 retains an optional allocation supplied by
`R4_MEMORY_EXTRA_BYTES`. `scripts/test-peak-memory-gate.sh` uses 550 MiB and
requires the gate to exit nonzero.

### Results

| Scenario | Peak | Ceiling | Headroom/result |
|---|---:|---:|---:|
| Settled decoded render | 214,433,792 bytes | 524,288,000 | 309,854,208 bytes |
| PNG export | 224,395,264 bytes | 681,574,400 | 457,179,136 bytes |
| Forced 550 MiB allocation | 791,822,336 bytes | 524,288,000 | Expected failure/nonzero exit |

The PRD ceilings were not altered. Evidence is retained in
`artifacts/r4/peak-memory.txt` and
`artifacts/r4/peak-memory-failure-fixture.txt`.

Status: **RESOLVED LOCALLY — HOSTED COMPONENT PENDING**

## ISSUE-04 — Reliability-run semantics and timing

### Finding

The original aggregate duration was not sufficiently explained to prove that
100 separate launches occurred or to distinguish codec smoke from UI startup.

### Code area

`scripts/nightly-reliability.sh:8–60` records environment metadata, declares
sequential codec-only execution, launches each process through a 30-second
watchdog, records its PID and durations, rejects duplicate PIDs, and requires
100 successful launches plus 10,000 round trips.

```sh
printf 'execution=sequential smoke_path=codec-only ui_initialized=false ...\n'
line=$(/usr/bin/time -p perl -e '$SIG{ALRM}=sub{exit 124}; alarm shift; exec @ARGV' \
  30 .build/release/VectorFoundry --smoke 2>"$timing")
```

### Resolution and proof

- Execution is sequential.
- `--smoke` branches before `NSApplication.shared`; no window/UI initialization
  occurs.
- Result: 100 distinct PIDs, 10,000 round trips, zero crashes, nonzero exits,
  timeouts, or corruption failures; aggregate wall time 5 seconds.
- The same script and output format must be run on macOS 13 alongside the
  20-launch full-app startup gate in the same machine session.
- Artifact: `artifacts/r4/reliability-100x100.txt`.

Status: **RESOLVED LOCALLY — MACOS 13 RELIABILITY/STARTUP AND HOSTED RUNS PENDING**

## ISSUE-05 — A6 exact permanent-test traceability

### Fourteen required areas

| # | Area | Principal production code | Permanent proof |
|---:|---|---|---|
| 1 | Selection, visibility, locking | `SelectionTool.hitTest`; `CanvasView.mouseDown` | `preciseSelectionRejectsBoundsFalsePositiveAndRespectsLockedLayers`; headless UI journey |
| 2 | Direct anchors and handles | `SceneCommands.moveAnchor/moveControl/deleteAnchor`; canvas drag | VERIFY-019 test; anchor-delete and direction-handle tests; UI journey |
| 3 | Pen corner/smooth behavior | `SmoothPenToolState`; pen canvas events | `smoothPenCreatesMirroredHandlesPreviewAndClosedPath`; UI journey |
| 4 | Eight-handle scale and pivot rotation | `TransformInteractions`; `applyDocumentTransform` | VERIFY-013, VERIFY-016, VERIFY-020; UI journey |
| 5 | Snapping | `SnapPolicy.snap`; `CanvasView.snappedPoint` | VERIFY-018, VERIFY-021; UI journey |
| 6 | New document | `AppDelegate.newDocument/promptForNewDocument`; document initializer | UI journey |
| 7 | Properties panel | `CanvasView.editSelectedProperties`; `mutatePath` | UI journey; `advancedResourceInvariants` |
| 8 | Layers | `CanvasView.editLayers`; `Layer` | UI journey; selection/lock integration test |
| 9 | Alignment | `CanvasView.alignSelectedLeft`; `AlignmentCommands.align` | `alignmentIsUndoable`; UI journey |
| 10 | Gradients | `CanvasView.editGradient`; gradient resources | `advancedResourceInvariants`; UI journey |
| 11 | Text | `CanvasView.createText/editSelectedProperties`; `TextObject` | UI journey; `expandedAppearanceTextAndImageRender` |
| 12 | Images | image placement, `ApprovedImageCache`, `LinkedResourceResolver` | UI journey; raster-loader and approved-image renderer tests |
| 13 | Group and compound operations | canvas commands and `SceneCommands` | undo test; visual-bounds invariance test; UI journey |
| 14 | Zoom and pan | canvas zoom/pan events; `TransformInteractions.zoomAbout` | VERIFY-014; UI journey |

The exact fully qualified test table is retained verbatim in
`docs/remediation/A6-R3-checkpoint.md` and
`docs/reviews/R4-cross-verification-response.md`.

### Resolution and proof

- `artifacts/r4/a6-test-existence.txt`: file-and-line existence proof for every
  unique method.
- `artifacts/r4/a6-filtered-tests.txt`: combined filter, 19 tests passed.
- Rows 6/7/8/11/12 now cite concrete permanent functions rather than prose.

Status: **RESOLVED**

## ISSUE-06 — Revision accounting and artifact freshness

### Finding and code area

Gate evidence must be regenerated whenever a later commit touches its inputs.
The relevant inputs are `Sources/`, `Tests/`, `scripts/`, `Package.swift`, and
`.github/workflows/`.

### Resolution and proof

- `6de4bce` changed only
  `Tests/DocumentFormatsTests/AdversarialCorpusTests.swift`.
- `f44b7e4` changed documentation and retained artifacts only.
- The complete battery ran at `b01364b` after source/test/script/CI changes.
- The reliability log alone was invalidated by `2884a54` and rerun there.
- `14de9b3` is an ancestor of `f44b7e4`; no history rewrite occurred.
- Every artifact is mapped in `artifacts/r4/revision-map.md`.
- Raw scope proof: `artifacts/r4/revision-scope-proof.txt`.

Status: **RESOLVED**

## ISSUE-07 — Hosted-CI closure language

### Finding

With no remote or hosted run, BLOCK-003/004/005 could not be described as
unconditionally closed.

### State area

`docs/PROJECT_STATE.md:23–26` now records:

| Blocker | Current state |
|---|---|
| BLOCK-003 | `OPEN — LOCAL PASS, HOSTED PENDING` |
| BLOCK-004 | `OPEN — LOCAL PASS, HOSTED PENDING` |
| BLOCK-005 | `OPEN — LOCAL PASS, HOSTED PENDING` |
| BLOCK-006 | `OPEN` |

The first hosted run must show `startup-memory`, `nightly-reliability`,
`benchmark`, and `adversarial-golden` green, retain their artifacts and URL,
and bootstrap a clearly hosted baseline. This closes the hosted portions of
BLOCK-003/004/005 simultaneously.

Status: **RESOLVED AS DOCUMENTATION; EXTERNAL EXECUTION REMAINS OPEN**

## ISSUE-08 — AUDIT-005/006 regression proof

### Code areas

`Tests/DocumentModelTests/DocumentModelTests.swift` contains:

```text
failedFirstGestureDoesNotCorruptLaterCoalescing
unsavedCoordinatorsAreIndependentAndCancelPreventsReplacement
```

### Resolution and proof

- Existence: `artifacts/r4/audit-005-006-test-existence.txt`.
- Filtered execution: `artifacts/r4/audit-005-006-filtered-tests.txt`.
- Both permanent tests passed on `b01364b`.

Status: **RESOLVED**

## ISSUE-09 — Startup measurement boundary

### Code and policy areas

- Probe switch: `Sources/VectorFoundryApp/main.swift:13`.
- Probe handling: `Sources/VectorFoundryApp/main.swift:849`.
- Measurement script: `scripts/check-startup-p95.sh`.
- Policy: `docs/phase-4/ci-policy.md`.

The documented start boundary is the Swift static initializer. It explicitly
excludes exec, dyld, runtime loading, and other pre-main work; therefore it is
not a click-to-window metric.

Status: **RESOLVED**

## ISSUE-10 — Baseline provenance and hosted variance

### Code/data areas

- Local baseline:
  `benchmarks/owner-reference-macos15-arm64-baseline.tsv`.
- Exact comparison:
  `scripts/check-benchmark-regression.sh`.
- Policy and hosted-risk record:
  `docs/phase-4/ci-policy.md`.

The baseline header declares
`source=owner-reference-MacBookPro18,2-not-hosted`. GitHub-hosted timing
variance may make a `1.25×` p95 gate flap, but that threshold may change only
through an explicit owner decision with rationale and review.

Status: **RESOLVED**

## ISSUE-11 — BENCH-2b forced-exposure assertion

### Code area

`Sources/RenderBenchmark/main.swift:108–120`:

```swift
let stripCache = ViewportStripCache()
var priorStripCount = 0
let bench2b = measure { index in
    stripCache.render(
        base, revision: 1, in: destination,
        viewport: RenderViewport(zoom: 2, pan: Point(x: -Double(index * 2), y: 0)),
        pixelWidth: 800, pixelHeight: 500)
    let current = stripCache.redrawnStripCount
    precondition(current > priorStripCount,
                 "BENCH-2b must redraw a nonzero strip every frame")
    priorStripCount = current
}
```

The precondition executes for all 60 warm-up and 300 measured frames. A frame
without a strip redraw terminates the harness nonzero. The production strip
implementation is `Sources/CanvasRender/ViewportStripCache.swift`.

Status: **RESOLVED**

## Additional related code areas

| Concern | Code area | Reason for review |
|---|---|---|
| Retained bitmap budget | `Sources/DocumentModel/Document.swift:31`; `Sources/CanvasRender/SceneBitmapCache.swift:34–44` | `maximumRetainedBitmapPixels = 67_108_864` is independent from the image pixel cap even though the current numeric values match. |
| Hosted job definitions | `.github/workflows/ci.yml` | Defines startup/memory, reliability, benchmark, and adversarial/golden jobs whose first hosted execution remains pending. |
| Startup result interpretation | `docs/phase-4/ci-policy.md` | Prevents the static-initializer probe from being represented as click-to-window startup. |
| Performance results | `docs/phase-4/R4-checkpoint.md`; `docs/remediation/A6-R3-checkpoint.md` | Records the final BENCH and startup numbers and distinguishes local proof from hosted enforcement. |
| Project status | `docs/PROJECT_STATE.md` | Authoritative blocker and Phase 5 entry state. |

## Claude verdict addendum — ADD-01 through ADD-03

### ADD-01 — BLOCK-002 Option A

The owner decision is frozen in `docs/PROJECT_STATE.md`: BLOCK-002 requires
both `macos13-reliability-100x100.txt` and `macos13-startup-p95.txt` from the
same real macOS 13.x Apple Silicon machine/session. The startup artifact uses
20 full-app launches and the unchanged 2,000 ms p95 target. Option B,
codec-only runtime proof, was rejected.

Status: **RESOLVED AS PROCEDURE — EXTERNAL RUN OPEN**

### ADD-02 — Optional percentile fixture

No new synthetic fixture was added. The optional work would change a gate
script and trigger a startup-gate rerun under BLOCK-011. The accepted live run
already distinguishes rank 19 from rank 20 (`147.748 ms` versus the
`162.816 ms` maximum), while the exact nearest-rank rule and boundary examples
are pinned in both the script and CI policy. This optional enhancement remains
available if the owner later prioritizes it.

Status: **OPEN — OPTIONAL, NOT REQUIRED FOR CURRENT ACCEPTANCE**

### ADD-03 — A7 human spot-check

The final closure sequence in
`docs/reviews/R4-A6-A7-A8-review-package.md` now requires the human reviewer to
open `artifacts/r4/a6-test-existence.txt`, `artifacts/r4/revision-map.md`, and
the exact 14-row table in `docs/remediation/A6-R3-checkpoint.md`. A summary may
not substitute for this inspection.

Status: **RESOLVED**

## Final local verification snapshot

| Gate | Result |
|---|---|
| Debug | 89 tests passed, 2.427 s |
| Release | 89 tests passed, 1.135 s |
| ASan | 89 tests passed, 11.317 s |
| Coverage | 87.93%, minimum 55% |
| Startup | p50 139.778 ms; p95 147.748 ms; max 162.816 ms; target 2,000 ms |
| Memory settle | 214,433,792 bytes; local pass |
| Memory export | 224,395,264 bytes; local pass |
| Memory failure fixture | 791,822,336 bytes; expected nonzero failure |
| Reliability | 100 processes, 100 distinct PIDs, 10,000 round trips, zero failures |
| BENCH-1 | p50 4.960; p95 5.496; max 12.056 ms |
| BENCH-2 | p50 0.088; p95 0.108; max 0.180 ms |
| BENCH-2b | p50 5.375; p95 5.950; max 23.265 ms; 360/360 strip-redraw frames |
| BENCH-3 | p50 2.399; p95 8.953; max 10.186 ms; settle 2.745 ms |
| Ratio boundary | Exact `1.25×` passes; `1.314801×` fails |

## Remaining actions before Phase 5

1. **BLOCK-002:** on one real macOS 13.x Apple Silicon machine session, run
   `scripts/nightly-reliability.sh
   artifacts/r4/macos13-reliability-100x100.txt` and
   `scripts/check-startup-p95.sh 20
   artifacts/r4/macos13-startup-p95.txt`; retain model, SoC, RAM, OS/build,
   Swift version, revision, all process/sample rows, and summaries after
   identifier stripping. The startup p95 target remains 2,000 ms.
2. **BLOCK-006:** establish a remote and obtain the first hosted CI run with all
   four required jobs green; retain its run URL and artifacts.
3. Bootstrap a clearly identified hosted benchmark baseline and comparison
   artifact without overwriting the owner-reference provenance.
4. Update BLOCK-003/004/005 only after their hosted jobs actually pass.
5. At A7 final acceptance, the human reviewer must open
   `artifacts/r4/a6-test-existence.txt`, `artifacts/r4/revision-map.md`, and the
   exact 14-row table in `docs/remediation/A6-R3-checkpoint.md`.
6. Keep BLOCK-012 open and do not create `pre-phase5-remediation` while any
   prerequisite remains open.

Until those actions are complete, A8 remains blocked and the final verdict is
**FAILED — PHASE 5 BLOCKED**.
