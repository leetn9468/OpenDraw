# Hosted CI run #8 closure evidence

Evaluation date: 2026-07-15

Post-tag operations note: the 2026-07-15 owner decision makes hosted ratios
informational after shared-runner variance reached 2.3–2.8× in
<https://github.com/leetn9468/OpenDraw/actions/runs/29350963872>. Statements
below about the next run entering blocking ENFORCE mode accurately describe the
policy at R4 closure but are superseded for Phase 5 operations. The closure and
tag remain valid.

Run: <https://github.com/leetn9468/OpenDraw/actions/runs/29347892897>

Run revision: `94fb0f057510639b93d9802fe93ab4aa5f0b18de`

Event/result: `workflow_dispatch` / `success`

Pre-closure documentation corrections: `e8724aa`.

## EVIDENCE-1 — run identity and revision chain

The public API independently reports run 29347892897, CI #8, attempt 1,
`workflow_dispatch`, branch `remediation/pre-phase5`, exact head SHA `94fb0f0`,
and conclusion `success`.

The complete `f6ec81a` to `94fb0f0` chain and scope is:

| Commit | Scope |
|---|---|
| `f6ec81a` | macOS 15 platform floor in package, plist, CI and documentation |
| `4f156b9` | macOS 15 complete-battery artifacts and ADR-011 evidence/state |
| `834526c` | ADR-011 review documentation only |
| `b6cee43` | portable CI shell gates, dispatch reliability, action majors |
| `d1edd2f` | CI #1 evidence and affected local-gate reruns |
| `8c157cb` | closure-criteria and evidence-map documentation only |
| `ce3b4b3` | descriptor-race production/test fix and incompressible memory fixture |
| `8da5ee8` | complete corrective local battery and CI #4 evidence |
| `9471562` | CI #4 state documentation only |
| `b57293c` | hosted benchmark bootstrap/enforcement workflow selection |
| `e01ac1b` | CI #5 evidence and workflow-mode proofs |
| `59eec99` | fail-closed five-metric hosted-baseline validation |
| `2cfa845` | CI #5 state documentation only |
| `5d2ea50` | shared local/hosted ASan deadline-test isolation runner |
| `bd4524f` | CI #6 evidence and exact-revision ASan rerun |
| `94fb0f0` | CI #6 state documentation only |

`git diff --stat ce3b4b3 94fb0f0 -- Sources Tests` is empty. `ce3b4b3` is the
last commit touching `Sources/` or `Tests/`, and its complete local battery is
retained by `8da5ee8`. Later affected-gate accounting is explicit in
`artifacts/r4/revision-map.md`: `b6cee43` to `d1edd2f`, `b57293c`/`59eec99` to
`e01ac1b`/`2cfa845`, and `5d2ea50` to `bd4524f`.

Superseded hosted attempts remain evidence, but none satisfies the all-eight-job
closure rule:

| Attempt | URL | Why it did not qualify |
|---|---|---|
| CI #1 | <https://github.com/leetn9468/OpenDraw/actions/runs/29315797697> | Benchmark and startup-memory failed on missing hosted commands; reliability was skipped. |
| Run #3 | <https://github.com/leetn9468/OpenDraw/actions/runs/29325516216> | Seven push-triggered jobs passed; reliability was skipped. |
| CI #4 | <https://github.com/leetn9468/OpenDraw/actions/runs/29327190429> | Debug-release and startup-memory failed; reliability was skipped. |
| CI #5 | <https://github.com/leetn9468/OpenDraw/actions/runs/29340697610> | Hosted benchmark incorrectly compared against the owner-reference baseline; reliability was skipped. |
| CI #6 | <https://github.com/leetn9468/OpenDraw/actions/runs/29345329291> | Sanitizer failed under cross-suite contention; reliability was skipped. |

## EVIDENCE-2 — all hosted jobs

Every API job carries label `macos-15` and conclusion `success`:

| Job | Duration | Result |
|---|---:|---|
| debug-release | 114 s (1m54s) | success |
| sanitizer | 67 s (1m07s) | success |
| adversarial-golden | 47 s | success |
| benchmark | 29 s | success |
| startup-memory | 62 s (1m02s) | success |
| coverage | 42 s | success |
| release-integrity | 41 s | success |
| nightly-reliability | 38 s | success; executed, not skipped |

## EVIDENCE-3 — hosted baseline

Artifact 8316881233 contains exactly five unique metrics and this provenance:

```text
# mode=BOOTSTRAP_CANDIDATE
# source_commit=94fb0f057510639b93d9802fe93ab4aa5f0b18de
# source=github-hosted-macos15-arm64
# runner_image=macos-15
# run_url=https://github.com/leetn9468/OpenDraw/actions/runs/29347892897
# measured_on=2026-07-14
# valid_until=2026-10-12
```

The validity interval is exactly 90 days. The metrics are `bench1_p95=5.259`,
`bench2_p95=0.104`, `bench2b_p95=4.837`, `bench3_p95=7.867`, and
`bench3_settle=2.622`, each with allowed ratio `1.25`.

The candidate is committed byte-for-byte as
`benchmarks/hosted-macos15-arm64-baseline.tsv`; the owner-reference baseline is
untouched. The next hosted benchmark run therefore enters
`mode=ENFORCE ratio_enforcement=ON` automatically. The permanent fixture still
accepts exact 1.25 and rejects 1.314801, proving the enforce path is falsifiable.

## EVIDENCE-4 — bootstrap comparison caveat

Artifact 8316880628 records:

```text
mode=BOOTSTRAP ratio_enforcement=OFF
```

All five rows are definitionally `ratio=1.000000 result=BOOTSTRAP`. No
meaningful regression comparison occurred in CI #8 because this first run
created the hosted baseline. Meaningful blocking ratio enforcement begins with
the next hosted run; the benchmark job remains required in every qualifying
workflow run.

## EVIDENCE-5 — retained artifacts and logs

Six API artifacts were present. Five non-app archives, extracted benchmark,
startup/memory and reliability evidence, API responses, and all eight
authenticated job logs are committed under `artifacts/r4/hosted/`. The
`OpenDraw-app` archive is not committed; its API/upload SHA-256 is
`1140dc4f1d91190ff2b34c278551a34699e4dd935188cbe5e1f706a5d74905f3`.
The full IDs and hashes are in `ci-8-evidence-manifest.md`.

The startup gate passed at p95 225.979 ms against 2,000 ms. Memory passed at
214,106,112 bytes settle against 524,288,000 and 223,936,512 bytes export
against 681,574,400. The unchanged forced-memory fixture failed as required at
790,921,216 bytes. Reliability records 100 distinct processes, 10,000 round
trips and zero crashes, nonzero exits, timeouts or corruptions.

## EVIDENCE-6 — variance watch

No hosted timing gate was within 10% of its absolute target. Headroom was
68.51% for BENCH-1, 99.38% for BENCH-2, 71.04% for BENCH-2b, 76.16% for
BENCH-3, 97.38% for settle, and 88.70% for startup p95. No new near-boundary
flap warning is required. The existing approximately 2x cross-run hosted
variance warning remains active; any mitigation remains owner-decision-only.

## EVIDENCE-7 — final-revision carried gates

The CI #8 `debug-release` job executed and passed
`scripts/check-module-dependencies.sh`, `scripts/check-clean-room.sh`, public
symbol-graph emission with a nonempty-file assertion, and the macOS 15 release
compile on `94fb0f0`. The `release-integrity` job executed
`scripts/build-release-app.sh`, producing the signed hardened-runtime arm64 app
artifact on the same revision. These hosted steps supplement the local
`ce3b4b3`/`8da5ee8` dependency, clean-room, symbol-graph and release-integrity
entries in `artifacts/r4/revision-map.md`.

## Matrix and acceptance boundary

AUDIT-001 through AUDIT-008 are all `Closed`; the audit findings matrix has
zero open rows. Hosted evidence now satisfies the technical requirements for
BLOCK-003/004/005/006 closure.

A7 acceptance and BLOCK-012 remain separate: a named human must directly open
and inspect `a6-test-existence.txt`, `revision-map.md`, and the exact 14-row
table in `A6-R3-checkpoint.md`, with reviewer and time recorded. This report
does not represent an AI inspection as that required human spot-check.
