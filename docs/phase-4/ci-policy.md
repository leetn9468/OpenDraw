# R4 CI and reliability policy

## Platform lanes

The hosted arm64 lane uses macOS 15. CI also compiles with
`MACOSX_DEPLOYMENT_TARGET=13.0`, but that is not a macOS 13 runtime test. ADR-011
requires runtime evidence on real macOS 13 Apple Silicon before A7/R4
acceptance. Frozen owner decision Option A (TN LEE, 2026-07-13) requires both
the 100-launch codec reliability script and the 20-launch full-app startup gate
from the same machine/session; codec-only Option B was rejected. Both external
runs are currently missing (BLOCK-002).

## Enforced jobs

CI separates debug/release, ASan, adversarial/golden, benchmark, coverage,
startup/memory, release-integrity, and scheduled reliability jobs. Coverage has
a 55% line floor, excluding test and generated runner code. Public symbol-graph
emission, dependency direction, clean-room build inputs, an ad-hoc
hardened-runtime signature, and arm64 binary integrity are enforced.

`scripts/check-startup-p95.sh` launches 20 clean application processes. Start is
the executable's static initializer; stop is after the sample document canvas,
window, toolbar and autosave timer are ready. Each run uses a fresh HOME (cold
application state); OS/framework/filesystem caches are not purged. The target is
the Phase 1 PRD's p95 <= 2,000 ms.
The start boundary explicitly excludes exec, dyld, runtime loading and all other
pre-main/static-initializer work, so it is not a click-to-window measurement.

`scripts/check-peak-memory.sh` uses `/usr/bin/time -l` maximum resident set size
for a 1,000-object/10,000-anchor/10-image representative document. All ten
embedded 5 MP images are decoded through `RasterResourceLoader` and
`ApprovedImageCache`, retained, and supplied to the production renderer. It
enforces the Phase 1 PRD ceilings as binary units: 500 MiB after
settled render and 650 MiB during production Core Graphics/ImageIO PNG export.
Exceeding either value exits nonzero. Raw logs are uploaded.
`scripts/test-peak-memory-gate.sh` additionally retains a forced 550 MiB
over-allocation run and requires the settle gate to exit nonzero.

The scheduled `scripts/nightly-reliability.sh` executes 100 separate application
processes sequentially. The `--smoke` path deliberately bypasses AppKit window/UI
initialization and measures codec reliability, unlike the startup gate. Each
process performs 100 native encode/decode round trips, producing 10,000
aggregate cycles. Every process has a 30-second watchdog. Any crash, timeout,
nonzero exit, missing/duplicate PID, missing success marker or codec error fails
the job; the per-launch PID, process wall duration, inner smoke duration,
and summary log is uploaded.

## Benchmark regression policy

The absolute BENCH-R3.5 targets bind on owner reference hardware. Hosted CI also
runs `scripts/check-benchmark-regression.sh`. Each BENCH-1/2/2b/3 p95 and
BENCH-3 settle value must be <= 1.25 times its baseline. Equality at exactly
1.25 is accepted using exact decimal arithmetic; the six-decimal printed ratio
is display-only. Missing, empty, unknown,
or past-`valid_until` baselines fail closed. The comparison log is uploaded even
on failure. `scripts/test-benchmark-regression-gate.sh` proves a below-threshold
fixture passes and a 1.314801 ratio fails.

The clearly named `owner-reference-macos15-arm64-baseline.tsv` records the
accepted owner-reference run at `d68f415`;
it is explicitly not a hosted-runner artifact. Baseline updates require a reviewed
commit containing a green known-good hosted run, unchanged scenario/sample
semantics, source run URL/artifact, measurement date and 90-day expiry. Since no
remote or hosted run is available in this checkout, BLOCK-006 remains open even
though enforcement and failure behavior are implemented.

GitHub-hosted macOS timing can have high variance, so 1.25 may flap. It must not
be loosened silently: any threshold change requires an explicit owner decision,
rationale, and reviewed baseline-policy update.

The first hosted run must show `startup-memory`, `nightly-reliability`,
`benchmark`, and `adversarial-golden` green and retain their artifact IDs and run
URL. That run closes the hosted-execution components of BLOCK-003/004/005 while
the hosted baseline/comparison closes BLOCK-006.

## Numeric-policy classification

The following are gate/test-side policies, not production editor mathematics:

- Percentiles use nearest rank: one-based `ceil(p * n)`, then zero-based lookup.
  Examples: startup p95 with 20 values selects sorted item 19; benchmark p95
  with 300 values selects item 285; one sample selects item 1 (degenerate).
- Ratio comparison parses decimal strings exactly and accepts
  `observed <= baseline * 1.25`. Exact-boundary fixtures pass; a 1.314801
  fixture fails. Display rounding never controls the decision.
- Golden comparison permits at most 92 differing pixels (integer floor of 1%
  of 9,216) and maximum channel delta 12, both inclusive. Zero differing pixels
  is the degenerate pass; 93 pixels or channel delta 13 fails.
- The mutation LCG uses exact wrapping UInt64 arithmetic solely to regenerate
  test inputs.

None introduces production mathematical behavior or changes VERIFY-001–021.

## Boundaries

The parser deadline harness is cooperative and in-process, not a hard-kill
isolation boundary. Developer ID signing/notarization requires owner credentials.
Manual VoiceOver, multi-display review and long-duration Instruments observation
remain operator checks and are not represented as automated passes.

Swift mutation tooling remains deferred because no maintained Swift 6-compatible
tool is approved here. The substitute is the frozen VERIFY-001–021 suite plus
deterministic property and adversarial mutation tests; those tests are not called
coverage-guided fuzzing.
