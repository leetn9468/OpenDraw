# R4 CI and reliability policy

## Platform lanes

Every hosted arm64 job is pinned to the GitHub Actions `macos-15` runner image.
CI also compiles with
`MACOSX_DEPLOYMENT_TARGET=15.0`, but that is not a macOS 15 runtime test. ADR-011
requires runtime evidence on real macOS 15 Apple Silicon before A7/R4
acceptance. Frozen owner decision Option A (TN LEE, 2026-07-13) requires both
the 100-launch codec reliability script and the 20-launch full-app startup gate
from the same machine/session; codec-only Option B was rejected. Both ran on
the owner-reference MacBookPro18,2 and were revalidated at complete-battery
revision `ce3b4b3` (the later `b57293c`/`59eec99` chain is
hosted-workflow-only), so
BLOCK-002 is closed by `macos15-reliability-100x100.txt` and
`macos15-startup-p95.txt`.

The workflow supports `workflow_dispatch`. The scheduled reliability job also
runs for a manual dispatch, so a single qualifying BLOCK-006 run executes all
eight jobs. Push and pull-request runs may still skip that scheduled-only lane;
they are not qualifying closure runs.

Workflow JavaScript actions are pinned to Node.js 24-based current majors:
`actions/checkout@v6` and `actions/upload-artifact@v7`. Shared shell gates use
POSIX `/bin/sh` utilities and do not require Homebrew or ripgrep. This keeps
local and hosted commands, thresholds, artifact formats, and failure behavior
identical without runner provisioning.

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

The frozen absolute BENCH-R3.5 targets remain blocking wherever the benchmark
runs, including hosted CI. Local ratio checks use
`owner-reference-macos15-arm64-baseline.tsv`. Hosted ratio checks must never use
that owner-local baseline: they use only
`hosted-macos15-arm64-baseline.tsv`. Each BENCH-1/2/2b/3 p95 and BENCH-3 settle
value must be <= 1.25 times the provenance-matched baseline. Equality at
exactly 1.25 is accepted using exact decimal arithmetic; the six-decimal
printed ratio is display-only. Missing, empty, unknown, or past-`valid_until`
committed baselines fail closed. The comparison log is uploaded even on
failure. `scripts/test-benchmark-regression-gate.sh` proves a below-threshold
fixture passes, exact 1.25 passes, and a 1.314801 ratio fails.

The clearly named `owner-reference-macos15-arm64-baseline.tsv` records the
accepted owner-reference run at `d68f415`; it is explicitly not a hosted-runner
artifact and remains the local baseline only. When no committed hosted baseline
exists, the hosted workflow enters explicit bootstrap mode after the absolute
gate passes: it writes `mode=BOOTSTRAP ratio_enforcement=OFF`, emits
definitionally 1.000000 comparisons, and uploads a candidate TSV whose header
contains the source SHA, `macos-15` runner image, run URL, measurement date, and
90-day expiry. This first comparison establishes a candidate and is not
independent regression evidence. After review and commit as
`hosted-macos15-arm64-baseline.tsv`, subsequent hosted runs enter
`mode=ENFORCE ratio_enforcement=ON` and invoke the unchanged shared checker.
Baseline updates require a green known-good hosted run and unchanged
scenario/sample semantics.

GitHub-hosted macOS timing can have high variance, so 1.25 may flap. It must not
be loosened silently: any threshold change requires an explicit owner decision,
rationale, and reviewed baseline-policy update.

Variance watch recorded from CI #5: hosted BENCH-1 p95 was at most about 6.6 ms
in runs #3/#4 and 13.049 ms in run #5, approximately 2× variation. Therefore a
1.25 hosted-vs-hosted threshold is a plausible future flap risk. N-of-M,
hosted-specific thresholds, or informational-only hosted ratios are not
implemented; each remains owner-decision-only after more qualifying samples.

The qualifying manually dispatched hosted run must execute and pass every job
defined by the workflow on the final revision, including `startup-memory`,
`nightly-reliability`, `benchmark`, and `adversarial-golden`, and retain their
artifact IDs and run URL. Partial-green runs do not qualify and are recorded as
failed attempts with their URLs. A qualifying run closes the hosted-execution
components of BLOCK-003/004/005 while the hosted baseline/comparison closes
BLOCK-006.

Hosted run CI #1 at commit `834526c` did not qualify. Benchmark and
startup-memory completed their substantive production measurements but their
final failure-fixture assertions exited 127 because they invoked `rg`, which is
not provided by the `macos-15` runner image. The dependency and clean-room
scripts also used `rg` inside shell conditionals, which could mask the missing
command, and the skipped reliability lane was limited to scheduled events.
The portability correction replaces those uses with POSIX `grep`; it does not
change any matching expression or gate decision.

Hosted run CI #4 at commit `8c157cb` also did not qualify. It executed code
identical to the preceding green push run but exposed two real defects:
release-mode concurrent tests could trigger stale file-descriptor cleanup in
`DurableFileWriter`, and the forced-memory fixture's uniform `0xA5` pages could
compress enough to stay below the ceiling. Corrective revision `ce3b4b3`
tracks descriptor ownership and makes the unchanged 550 MiB fixture allocation
incompressible. The complete local battery passes at that revision. This was
not a timing flap: hosted startup p95 remained at most 234.344 ms against the
unchanged 2,000 ms target. No retry or hosted-specific policy was introduced.

Hosted run CI #5 at commit `9471562` did not qualify. Every absolute benchmark
target passed, but the workflow incorrectly compared hosted observations to
the owner-local baseline, producing ratios 2.450977, 2.587156, and 2.257589 for
BENCH-1/2/2b. Workflow-only corrections `b57293c`/`59eec99` implement the
previously ratified hosted bootstrap/enforcement split and require exactly the
five named metrics without changing the shared ratio script or any numeric
policy.

Hosted run CI #6 at commit `2cfa845` did not qualify. The benchmark bootstrap
path passed, but the ASan job ran the adversarial per-mutation wall-clock gate
inside the contended whole suite. The first mutation was charged 7.901786791
seconds while many unrelated trivial tests simultaneously reported about 8.52
seconds. No ASan diagnostic occurred. Revision `5d2ea50` keeps every corpus
count and the unchanged 3/10-second deadlines, but runs the deadline-sensitive
test in an isolated ASan invocation after the other 89 instrumented tests.
`make sanitize` and hosted CI use the same script; no retry or gate waiver was
introduced.

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
