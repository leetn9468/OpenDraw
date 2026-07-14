# Hosted CI run #5 benchmark triage

Date: 2026-07-14

Run: <https://github.com/leetn9468/OpenDraw/actions/runs/29340697610>

Run revision: `9471562ce54a7d326599fe349ab2eba382fb281b`

Workflow corrections: `b57293c444695984ae71f7ad385b1186d046ac24`,
`59eec994261768eba53488bfd075bb101bf5d8f0`

Disposition: CI #5 is a failed, non-qualifying push run. Seven jobs executed;
six passed, benchmark failed, and nightly-reliability was skipped as expected
for a push. No qualifying run was dispatched during this correction.

## Diagnosis

`run-render-benchmark.sh` passed every unchanged absolute target. The later
workflow step nevertheless called the shared ratio checker with
`benchmarks/owner-reference-macos15-arm64-baseline.tsv`, comparing a shared
GitHub-hosted VM against the owner-reference MacBookPro18,2. That
cross-hardware substitution contradicted the already recorded baseline
provenance/bootstrap policy.

| Metric | Owner-local baseline | Hosted observed | Ratio | Old workflow result |
|---|---:|---:|---:|---|
| `bench1_p95` | 5.324 | 13.049 | 2.450977 | FAIL |
| `bench2_p95` | 0.109 | 0.282 | 2.587156 | FAIL |
| `bench2b_p95` | 5.831 | 13.164 | 2.257589 | FAIL |
| `bench3_p95` | 8.853 | 10.686 | 1.207048 | PASS |
| `bench3_settle` | 2.778 | 3.117 | 1.122030 | PASS |

The hosted absolute results remained within the frozen targets, including
13.049 ≤ 16.7 ms for BENCH-1 and 13.164 ≤ 16.7 ms for BENCH-2b.

## Workflow-only correction

The shared `scripts/check-benchmark-regression.sh` is unchanged. Local runs
continue comparing against the owner-reference baseline. The hosted workflow
now has two explicit modes:

- `ENFORCE`: if `benchmarks/hosted-macos15-arm64-baseline.tsv` exists, call the
  unchanged shared checker and block above the inclusive 1.25 ratio.
- `BOOTSTRAP`: if that hosted baseline is absent, keep absolute targets
  blocking, write `mode=BOOTSTRAP ratio_enforcement=OFF`, publish the current
  hosted measurements as a candidate baseline, and exit successfully.

The first bootstrap comparison is definitionally 1.0 and is not represented as
meaningful regression evidence. Meaningful hosted ratio enforcement starts
with the subsequent run after the reviewed hosted candidate is committed.

Bootstrap comparison format:

```text
mode=BOOTSTRAP ratio_enforcement=OFF
candidate=hosted-baseline-candidate.tsv
run_url=https://github.com/leetn9468/OpenDraw/actions/runs/<run-id>
bench1_p95 baseline_ms=<hosted> observed_ms=<hosted> ratio=1.000000 allowed_ratio=1.25 result=BOOTSTRAP
...
```

Candidate baseline format:

```text
# mode=BOOTSTRAP_CANDIDATE
# source_commit=<qualifying SHA>
# source=github-hosted-macos15-arm64
# runner_image=macos-15
# run_url=https://github.com/leetn9468/OpenDraw/actions/runs/<run-id>
# measured_on=<UTC date>
# valid_until=<UTC date + 90 days>
bench1_p95	<hosted p95>	1.25
...
```

Enforcement comparison begins with:

```text
mode=ENFORCE ratio_enforcement=ON
baseline=benchmarks/hosted-macos15-arm64-baseline.tsv
run_url=https://github.com/leetn9468/OpenDraw/actions/runs/<run-id>
```

## Falsifiability proof

The workflow still runs `scripts/test-benchmark-regression-gate.sh` before its
mode decision. That permanent fixture accepts exact 1.25 and requires the
1.314801 case to fail. A dry-run of the actual extracted workflow block also
proved both branches:

- absent baseline: exit 0, `mode=BOOTSTRAP ratio_enforcement=OFF`, all five
  ratios exactly 1.000000, candidate provenance and 90-day expiry present;
- present baseline plus `benchmark-regression-fail.txt`: exit 1,
  `mode=ENFORCE ratio_enforcement=ON`, BENCH-1 ratio 1.314801 marked `FAIL`.

Both modes additionally require exactly one row for each of the five named
metrics; missing, duplicate, or extra data rows fail before publication or
ratio comparison.

No shared script changed, so no local gate rerun was required by the directive.

## Variance watch

Hosted BENCH-1 p95 was at most approximately 6.6 ms in runs #3/#4, then
13.049 ms in run #5—roughly 2× run-to-run variation despite identical benchmark
semantics. The unchanged 1.25 hosted-vs-hosted ratio is therefore a likely flap
risk. N-of-M, a hosted-specific threshold, or an informational hosted ratio
would each require a future explicit owner decision supported by multiple
qualifying-run samples. None is implemented here.

## Carried-over gate confirmation

The post-`ce3b4b3` complete local battery explicitly reran and retained:

| Gate | Producing revision | Evidence commit | Result |
|---|---|---|---|
| Dependency direction | `ce3b4b3` | `8da5ee8` | PASS |
| Clean room | `ce3b4b3` | `8da5ee8` | PASS |
| Symbol graph | `ce3b4b3` | `8da5ee8` | PASS |
| Release assembly/signature | `ce3b4b3` | `8da5ee8` | PASS; arm64 hardened-runtime ad-hoc signature |

No `Sources/`, `Tests/`, script, threshold, target, tolerance, ceiling, retry
policy, fixture value, or VERIFY entry changed in the CI #5 correction.
