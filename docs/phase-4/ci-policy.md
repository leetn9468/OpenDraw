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

| Gate | Environment | Policy |
|---|---|---|
| Frozen BENCH-R3.5 absolute targets (BENCH-1/2/2b/3 + settle) | Local and hosted | **BLOCKING**, unchanged |
| BENCH-5a absolute target, p95 <= 16.7 ms | Local and hosted | **BLOCKING**, unchanged |
| BENCH-5b absolute target, p95 <= 1.0 ms | Stable owner-reference hardware | **BLOCKING**, unchanged |
| BENCH-5b measurement | GitHub-hosted `macos-15` | **INFORMATIONAL**, owner decision 2026-07-16 |
| BENCH-6 timing target, p95 <= 8.0 ms | Stable owner-reference hardware | **BLOCKING**, unchanged |
| BENCH-6 timing measurement | GitHub-hosted `macos-15` | **INFORMATIONAL**, owner decision 2026-07-18 |
| BENCH-6 correctness: nonzero hits and exact damage-mapped rendered tiles | Local and hosted | **BLOCKING**, unchanged |
| Owner-reference ratio, inclusive 1.25 | Stable owner-reference hardware | **BLOCKING**, unchanged |
| Hosted-runner ratio versus hosted reference | GitHub-hosted `macos-15` | **INFORMATIONAL**, owner decision 2026-07-15 |
| Absolute-mode and ratio falsifiability fixtures | Local and hosted workflow | **BLOCKING**, unchanged |

Phase 5 P1 extends the artifact with BENCH-5a delta undo/redo apply
(p95 <= 16.7 ms) and BENCH-5b record overhead (p95 <= 1.0 ms). Both absolute
targets remain blocking on owner-reference hardware. BENCH-5a also remains
blocking hosted. Under the 2026-07-16 owner decision, hosted BENCH-5b is
measured and reported with p50/p95/max but is informational. The owner-reference
baseline contains both rows and applies the same unchanged inclusive 1.25 local
ratio. Hosted ratios for the new rows are informational under the 2026-07-15
owner decision, exactly like the five earlier metrics.

Phase 5 P2 retains those exact targets and artifact row names while advancing
the exercised production path from value swaps to structural delete/reinsert:
BENCH-5a alternates structural undo/redo and BENCH-5b measures structural
command construction plus commit. This is an input expansion, not a threshold
or policy change.

The frozen absolute BENCH-R3.5 targets remain blocking wherever the benchmark
runs, including hosted CI. Local ratio checks use
`owner-reference-macos15-arm64-baseline.tsv` and remain blocking at the
unchanged inclusive 1.25 threshold. Equality at exactly 1.25 is accepted using
exact decimal arithmetic; the six-decimal printed ratio is display-only.
Missing, empty, unknown, or past-`valid_until` local baselines fail closed.
`scripts/test-benchmark-regression-gate.sh` remains a blocking workflow step and
proves a below-threshold fixture passes, exact 1.25 passes, and a 1.314801 ratio
fails. Neither the shared checker, owner-reference baseline, nor fixtures were
changed by the informational-hosted decision.

Hosted comparisons must never use the owner-local baseline. They retain
`hosted-macos15-arm64-baseline.tsv` solely as an informational reference and
upload all five original per-metric rows, plus both BENCH-5 rows after their
hosted bootstrap, under this header:

```text
mode=INFORMATIONAL ratio_enforcement=OFF reason=owner-decision-2026-07-15
```

The benchmark wrapper executes redirected Swift output unbuffered. If a
blocking release-mode benchmark precondition exits 133, the wrapper retains
that exit status and appends the last completed BENCH line plus a diagnostic
for the uniquely identifiable BENCH-2b/BENCH-5/BENCH-6 gate. This is evidence
preservation only: the job still fails, and no absolute target, precondition,
ratio policy, retry rule, or hosted/local semantic changes. The rule was added
after dispatched run 17 on 2026-07-16 lost its completed BENCH lines to the
stdout buffer; see `artifacts/phase5/p4/hosted-run-17-triage.md`.

`BENCH5B_ENFORCEMENT` and `BENCH6_TIMING_ENFORCEMENT` are independent policy
mode inputs. Both default to enforcement ON; ordinary local benchmark scripts
do not set either input. Only the hosted benchmark measurement step sets them
to `off`, with the 2026-07-16 and 2026-07-18 owner-decision references beside
the workflow inputs. Hosted artifacts still emit the complete p50/p95/max rows
and add `bench5b_enforcement=off result=INFORMATIONAL` and
`bench6_timing_enforcement=off result=INFORMATIONAL
reason=owner-decision-2026-07-18`. BENCH-2b and BENCH-5a retain their original
trapping preconditions in both modes. The hosted informational comparison
repeats both enforcement annotations; ordinary local output is unchanged.

The BENCH-6 timing guard is separate from its per-frame correctness path. The
mode input governs only the final `bench6.p95 <= 8.0` timing precondition. The
nonzero-hit and exact-damage-mapping preconditions execute unconditionally
inside every measured frame. A superset or subset rendered-tile set therefore
traps in both timing modes. `scripts/test-bench6-gate.sh` proves default timing
overrun exit 133, timing-off overrun exit zero with the informational row,
timing-off isolation from a still-trapping BENCH-5a overrun, and timing-off
over-invalidation exit 133. No workflow step uses `continue-on-error`.

`scripts/test-benchmark-enforcement-modes.sh` is blocking and proves three
cases: absent/default mode traps a forced BENCH-5b overrun with exit 133 and a
retained diagnostic; hosted-off mode records the same class of overrun and
exits zero; and hosted-off mode still traps a forced BENCH-5a overrun. Its
`BENCHMARK_GATE_FIXTURE` selector exists only to inject deterministic
above-boundary observations into this falsifiability harness. It is never set
by the production benchmark step.

The workflow captures the unchanged checker's status for the artifact but
always exits the reporting step successfully. The reference's `valid_until`
value remains provenance/watch metadata and is printed with
`expiry_enforcement=OFF`; it cannot fail the hosted job. Full per-metric rows
continue after that date by using an ephemeral expiry-neutral copy solely for
the informational invocation. The committed reference values and provenance
are unchanged.

The clearly named `owner-reference-macos15-arm64-baseline.tsv` records the
accepted owner-reference run at `d68f415`; it is explicitly not a hosted-runner
artifact and remains the local baseline only. When no committed hosted baseline
exists, the hosted workflow enters explicit bootstrap mode after the absolute
gate passes: it writes `mode=BOOTSTRAP ratio_enforcement=OFF`, emits
definitionally 1.000000 comparisons, and uploads a candidate TSV whose header
contains the source SHA, `macos-15` runner image, run URL, measurement date, and
90-day expiry. This first comparison establishes a candidate and is not
independent regression evidence. After review and commit as
`hosted-macos15-arm64-baseline.tsv`, subsequent hosted runs enter the
informational path. The 90-day date is informational provenance rather than a
hosted failure condition. Reference updates still require a green known-good
hosted run and unchanged scenario/sample semantics.

The committed hosted reference predates BENCH-5. Until it gains the two new
rows, the workflow keeps the original five informational comparisons, emits
BENCH-5a/5b as explicit 1.000000 bootstrap rows, and uploads a seven-row
candidate. That candidate retains the five-row source metadata and adds
separate `phase5_metrics_source_commit` and `phase5_metrics_run_url`
provenance. It requires review before commit and is not independent ratio
evidence.

GitHub-hosted macOS timing has measured hardware variance well beyond 1.25.
Owner decision 2026-07-15 therefore makes the hosted ratio informational; the
numeric reference threshold is retained in the artifact and is not loosened.
Options A (N-of-M retries) and B (a larger hosted ratio) were rejected because
they mask noise without adding detection power. Any future policy change
requires another explicit owner decision.

Variance evidence: CI #5 recorded BENCH-1 p95 13.049 ms, CI #8 recorded 5.259
ms, and the first post-tag ENFORCE attempt
<https://github.com/leetn9468/OpenDraw/actions/runs/29350963872> recorded 14.625
ms. That triggering run passed every frozen absolute benchmark target but
failed hosted ratios at 2.780947 (BENCH-1), 2.701923 (BENCH-2), and 2.343808
(BENCH-2b). BENCH-1 absolute headroom was only about 12.43% (14.625 versus 16.7
ms), so absolute-target variance is now a **WATCH** item. Any absolute-target
adjustment remains owner-only.

BENCH-5b variance evidence: hosted push run #16
<https://github.com/leetn9468/OpenDraw/actions/runs/29498775517> passed at
0.938 ms p95 with about 6% headroom. Dispatched run #17
<https://github.com/leetn9468/OpenDraw/actions/runs/29499008599> trapped at the
same gate but lost its value to redirected stdout buffering. Controlled CPU
contention reproduced line-195 enforcement on the triage revision at 12.277 ms
p95 while BENCH-5a
remained at 0.026 ms and BENCH-2b still redrew 360/360 strips; evidence is in
`artifacts/phase5/p4/hosted-run-17-triage.md`. This >12× range makes hosted
BENCH-5b informational by explicit owner decision. The unchanged 1.0 ms target
remains blocking on stable owner-reference hardware. The standing hosted
BENCH-1 absolute-headroom WATCH remains active.

BENCH-6 variance evidence: manually dispatched run #22
<https://github.com/leetn9468/OpenDraw/actions/runs/29595403869> measured 4.787
and 5.708 ms p95 in its hosted enforcement-mode fixture executions. The next
manual dispatch, run #23 on accepted triage revision `6208f52`,
<https://github.com/leetn9468/OpenDraw/actions/runs/29622813655>, measured
p50 7.540 ms, p95 16.964 ms, and max 113.417 ms while all per-frame BENCH-6
correctness assertions and the BENCH-2b `rendered_regions=728` assertion
passed. Standing variance-watch entry: BENCH-6 p95 4.787 → 16.964 ms, with
the latter run's max at 113.417 ms. The >3.5× p95 swing on identical benchmark
code triggered the 2026-07-18 owner decision: hosted BENCH-6 timing is
informational, the unchanged 8.0 ms p95 remains blocking on stable
owner-reference hardware, and
correctness remains blocking everywhere. Options A (higher hosted target) and
C (N-of-M) were rejected. The standing hosted BENCH-1 absolute-headroom WATCH
remains active unchanged.

CI #8 timing-headroom review found no gate within 10% of its absolute target:
BENCH-1/2/2b/3 and settle retained at least 68.51% headroom, and startup p95
retained 88.70%. No new near-boundary flap risk is recorded. The existing
approximately 2x hosted cross-run variance warning remains in force unchanged.

Manually dispatched CI #8 at `94fb0f0` is the qualifying hosted run: all eight
`macos-15` jobs executed and passed. Its benchmark comparison was explicitly
bootstrap-only (`mode=BOOTSTRAP`, `ratio_enforcement=OFF`), so the 1.000000
ratios are baseline establishment rather than independent regression evidence.
The reviewed candidate is retained as `hosted-macos15-arm64-baseline.tsv` by
`88c3d58`. It remains the informational hosted reference after the 2026-07-15
owner decision; meaningful blocking ratio enforcement remains exclusively on
stable owner-reference hardware.

The qualifying manually dispatched hosted run must execute and pass all jobs
defined by the workflow on the final revision (currently eight), including `startup-memory`,
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
