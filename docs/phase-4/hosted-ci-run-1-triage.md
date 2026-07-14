# Hosted CI run #1 triage

Date: 2026-07-14

Run: `CI #1`

Run URL: <https://github.com/leetn9468/OpenDraw/actions/runs/29315797697>

Run commit: `834526c027fd87ae1fa3b2d5fc33d32c0ab9929e`

Portable fix revision: `b6cee435f4d0cc05bf1d475288a39ca68941fd6f`

## Run disposition

The run does not qualify for BLOCK-006. Five jobs passed, benchmark and
startup-memory failed, and nightly-reliability was skipped. No threshold,
target, tolerance, ceiling, fixture expectation, or product behavior was
changed in response.

| Job | Hosted conclusion | API step evidence |
|---|---|---|
| debug-release | PASS | All steps through dependency, clean-room, symbol graph, and minimum-target compile reported success. |
| sanitizer | PASS | AddressSanitizer step reported success. |
| adversarial-golden | PASS | Combined adversarial/golden filter reported success. |
| coverage | PASS | Coverage test and 55% enforcement steps reported success. |
| release-integrity | PASS | Release assembly step reported success. |
| benchmark | FAIL 127 | Benchmark measurement step passed; `scripts/test-benchmark-regression-gate.sh` failed; current comparison step was skipped. |
| startup-memory | FAIL 127 | Startup and peak-memory steps passed; `scripts/test-peak-memory-gate.sh` failed. |
| nightly-reliability | SKIPPED | Push event did not satisfy its schedule-only condition. |

The public job-logs download endpoint returned HTTP 403 without repository
authentication. An authenticated read-only download through the configured Git
credential helper then retained both raw logs under `artifacts/r4/hosted/`.
They explicitly report `rg: command not found` at the final assertion in each
failed script. The official `macos-15` runner software manifest also does not
list ripgrep. The logs prove the production measurements and intended failure
fixtures completed before the missing assertion tool terminated each step.

## FAIL-01 — benchmark exit 127

Failed hosted step:

```text
scripts/test-benchmark-regression-gate.sh
```

The script successfully invoked the unchanged exact-decimal comparison gate for
its pass, exact-1.25 boundary, and intended-failure fixtures. Its final assertion
used a runner-unavailable command:

```text
scripts/test-benchmark-regression-gate.sh: line 15: rg: command not found
Process completed with exit code 127.
```

```sh
rg -q 'bench1_p95 .*result=FAIL' "$directory/fail.txt"
```

Portable replacement:

```sh
grep -Eq 'bench1_p95 .*result=FAIL' "$directory/fail.txt"
```

The ERE and pass/fail condition are unchanged. The hosted benchmark production
path remains identical to the local path.

## FAIL-02 — startup-memory exit 127

Failed hosted step:

```text
scripts/test-peak-memory-gate.sh
```

The startup gate and normal decoded-image settle/export memory gate passed in
the preceding hosted steps. The failure fixture then received the required
nonzero result from the forced over-allocation scenario, but its final assertion
used:

```text
settle peak_bytes=709771264 limit_bytes=524288000 result=FAIL
scripts/test-peak-memory-gate.sh: line 10: rg: command not found
Process completed with exit code 127.
```

```sh
rg -q 'settle .*result=FAIL' "$output"
```

Portable replacement:

```sh
grep -Eq 'settle .*result=FAIL' "$output"
```

The forced 550 MiB allocation, 500 MiB settle ceiling, expected failure record,
and artifact format are unchanged.

## Related portability correction

The same unpinned `rg` dependency existed in three other shared scripts:

- `scripts/check-module-dependencies.sh`;
- `scripts/check-clean-room.sh`;
- `scripts/nightly-reliability.sh`.

The first two invoked it inside shell `if` conditions, so a missing command
could be treated as a false condition and allow a vacuous pass. Reliability
used it for PID uniqueness and success-marker checks. All uses now employ
POSIX `grep` with the same regular expression and matching mode:

| Old | New |
|---|---|
| `rg -n` | `grep -Ern` or `grep -En` |
| `rg -q` | `grep -Eq` |
| `rg -qx` | `grep -Eqx` |

No tool installation or hosted-only alternate code path was added.

## FIX-03 — manually dispatched reliability lane

`.github/workflows/ci.yml` now declares:

```yaml
on:
  workflow_dispatch:
```

and the reliability condition is:

```yaml
if: ${{ github.event_name == 'schedule' || github.event_name == 'workflow_dispatch' }}
```

A manually dispatched run therefore executes all eight jobs. A push or pull
request may still skip nightly-reliability and cannot by itself qualify for
BLOCK-006.

## FIX-04 — Node.js 24 action majors

All action uses were updated:

```yaml
uses: actions/checkout@v6
uses: actions/upload-artifact@v7
```

These are the current Node.js 24-based major versions. No action is left on
`checkout@v4` or `upload-artifact@v4`.

## Required local reruns at `b6cee43`

| Affected gate | Result | Artifact/revision |
|---|---|---|
| Module dependency direction | PASS | `module-dependencies.txt` / `b6cee43` |
| Clean-room build-input scan | PASS | `clean-room.txt` / `b6cee43` |
| BENCH-1 | p50 5.030, p95 5.518, max 7.496 ms; PASS | `render-benchmark.txt` / `b6cee43` |
| BENCH-2 | p50 0.088, p95 0.113, max 0.166 ms; PASS | same |
| BENCH-2b | p50 5.443, p95 5.987, max 7.352 ms; 360/360 strips; PASS | same |
| BENCH-3 | p50 2.450, p95 9.043, max 10.428 ms; settle 2.990 ms; PASS | same |
| BENCH-4 | cold 9.088 ms; warm 4.319 ms; informational | same |
| Benchmark ratios | Largest current ratio 1.076314; all ≤ 1.25; exact boundary/failure fixtures PASS | `benchmark-comparison.txt`, `benchmark-gate-fixtures.txt` / `b6cee43` |
| Memory settle | 215,400,448 ≤ 524,288,000 bytes; PASS | `peak-memory.txt` / `b6cee43` |
| Memory export | 224,149,504 ≤ 681,574,400 bytes; PASS | same |
| Memory failure fixture | 791,642,112 > 524,288,000 bytes; expected gate failure and fixture PASS | `peak-memory-failure-fixture.txt` / `b6cee43` |
| Reliability | 100 distinct PIDs, 10,000 cycles, zero failures; PASS | `reliability-100x100.txt` / `b6cee43` |

Observed changes are ordinary run-to-run noise. No result approached a frozen
absolute limit or the 1.25 ratio boundary.

## Qualifying-run operator procedure

1. Push the final branch commit to `origin/remediation/pre-phase5`.
2. In GitHub Actions, open workflow `CI`, choose **Run workflow**, select
   `remediation/pre-phase5`, and dispatch it manually.
3. Confirm all eight jobs execute and pass, including nightly-reliability.
4. Retain the run URL and every job artifact under `artifacts/r4/hosted/`.
5. Treat the first green hosted benchmark as the hosted-baseline candidate,
   recording commit, runner image, run URL, artifact digest, date, and expiry.
   It is baseline establishment, not independent regression proof against
   itself; retain that caveat explicitly.
6. Rerun the ratio gate against the reviewed hosted baseline and retain the
   comparison artifact.
7. Only then update BLOCK-003/004/005/006. BLOCK-012 and the Phase 5 tag remain
   untouched until every closure requirement is satisfied.

Current verdict: **FAILED — PHASE 5 BLOCKED**.

## Retained run-1 evidence

- `artifacts/r4/hosted/ci-1-run.json` — run metadata and conclusion;
- `artifacts/r4/hosted/ci-1-jobs.json` — all job and step conclusions;
- `artifacts/r4/hosted/ci-1-benchmark-annotations.json` — exit-127 and missing
  comparison annotations;
- `artifacts/r4/hosted/ci-1-startup-memory-annotations.json` — exit-127
  annotation;
- `artifacts/r4/hosted/ci-1-job-87029417334.log` — raw benchmark job log;
- `artifacts/r4/hosted/ci-1-job-87029417345.log` — raw startup-memory job log.
