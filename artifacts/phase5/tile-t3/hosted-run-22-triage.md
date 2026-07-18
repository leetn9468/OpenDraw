# T3 hosted dispatch triage — run 29595403869

Run: <https://github.com/leetn9468/OpenDraw/actions/runs/29595403869>

Exact dispatched input revision: `44f2de03b30038e5bb72749c03df18a716560244`.
Five jobs passed; `coverage`, `debug-release`, and `benchmark` failed.

## Risks cleared

The S6 hosted watch items passed on the shared runner. The benchmark job's
fixture runs reported:

```text
BENCH-1 drag: p50 4.481 ms | p95 6.679 ms | max 14.296 ms
BENCH-6 tile-edit: p50 3.802 ms | p95 4.787 ms | max 8.556 ms
BENCH-6 tile-edit: p50 4.395 ms | p95 5.708 ms | max 12.577 ms
```

Thus BENCH-1 p95 `6.679 <= 16.7 ms`, and both BENCH-6 observations
`4.787 <= 8.0 ms` and `5.708 <= 8.0 ms`. No owner decision is needed for
either pre-registered watch item.

Historical note: this risk-cleared classification records run #22 only.
Follow-up run #23 on accepted triage revision `6208f52` measured BENCH-6 p95
16.964 ms and max 113.417 ms on identical benchmark code, triggering the
2026-07-18 owner decision retained in `hosted-run-23-bench6-policy.md`.

## FAIL-A — wall-clock contention

`deterministicNativeAndSVGMutationCorpusMeetsDeadline` observed 3.427 seconds
in coverage and 3.162 seconds in debug-release against the unchanged 3.0-second
deadline. The same revision passes locally. The owner classified this as the
same co-runner-contention class as CI #6 and the T1/T2 geometry isolation.

The standing owner policy is recorded verbatim in `docs/PROJECT_STATE.md`.
`scripts/run-tests-with-isolated-deadlines.sh` is now the full-suite choke
point: it skips both known deadline tests in the main population, then runs
the corpus deadline and geometry smoke sequentially. Coverage uses the same
ordering while preserving the main population's profile. The adversarial job
does not select the geometry smoke and runs its selected corpus deadline alone
after the remaining adversarial/golden population.

### Eight-job audit

| Job | Executes a wall-clock deadline? | Final ordering |
|---|---:|---|
| `debug-release` | yes, both configurations | main minus both; corpus; geometry, sequentially for debug then release |
| `sanitizer` | yes | shared runner: main minus both; corpus; geometry |
| `adversarial-golden` | corpus only | selected main minus corpus deadline; corpus deadline |
| `coverage` | yes | coverage main minus both; corpus; geometry |
| `benchmark` | no | unchanged |
| `startup-memory` | no | unchanged |
| `release-integrity` | no | unchanged |
| `nightly-reliability` | no | unchanged |

## FAIL-B — actual benchmark failure

GitHub job `87934447188` failed in step
`Prove hosted BENCH-5b policy remains falsifiable`. Job metadata reports exit
code 1. The raw log tail is:

```text
BENCH_GATE_FIXTURE=bench5a-and-b-overrun
BENCH-5a undo-redo: p50 0.010 ms | p95 16.701 ms | max 16.701 ms
BENCH-5b record: p50 0.197 ms | p95 1.001 ms | max 1.094 ms
BENCH-5b enforcement: bench5b_enforcement=off result=INFORMATIONAL
BENCH-6 tile-edit: p50 4.094 ms | p95 8.001 ms | max 8.001 ms
BENCH_TRAP source=Sources/RenderBenchmark/main.swift:310 gate=BENCH-6 observed_p95_ms=8.001 target_p95_ms=8.0
##[error]Process completed with exit code 1.
```

H1 was falsified: `scripts/test-benchmark-enforcement-modes.sh` captured each
expected 133 with `|| status=$?`; no `tee` pipeline swallowed it. H2 identified
the actual failure inside the visible policy-fixture step, and H3 was not
needed. The composite `bench5a-and-b-overrun` fixture matched every call to
`applyingGateFixture`, including BENCH-6, so the third run trapped at BENCH-6
before the script's BENCH-5a trap assertion. The script consequently exited 1.

The two differently numbered passing measurement blocks cited by the operator
are fixture executions: this step intentionally launches three full benchmark
scenario runs — blocking BENCH-5b overrun (expected 133), informational
BENCH-5b overrun (expected 0), and blocking BENCH-5a overrun while BENCH-5b is
informational (expected 133). They are separate from the preceding real hosted
measurement step.

The third run now selects only `bench5a-overrun`. The earlier run still proves
that BENCH-5b's forced 1.001 ms overrun is informational under hosted mode, and
the third still proves that BENCH-5a's unchanged 16.7 ms gate traps with
BENCH-5b enforcement off. BENCH-6 is no longer injected by that fixture; its
dedicated forced-overrun script remains unchanged and must still prove exit
133.

No source or test file changed. No deadline, threshold, target, or frozen value
changed.

## Final local affected-gate battery

| Gate | Result | Exact local evidence |
|---|---|---|
| Debug isolated population | PASS | main 136 in 15.435 s; corpus 1 in 0.025 s; geometry 1 in 0.359 s; total 138 |
| Release isolated population | PASS | main 136 in 1.416 s; corpus 1 in 0.023 s; geometry 1 in 0.006 s; total 138 |
| Coverage isolated population | PASS | main 136 in 15.780 s; corpus 1 in 0.026 s; geometry 1 in 0.366 s; 90.69% >= unchanged 55% floor |
| AddressSanitizer isolated population | PASS | main 136 in 50.787 s; corpus 1 in 0.038 s; geometry 1 in 0.870 s; total 138 |
| Adversarial/golden selected ordering | PASS | non-deadline selection 2 in 0.019 s; isolated corpus 1 in 0.025 s |
| BENCH-5b enforcement modes | PASS | blocking BENCH-5b exit 133; informational BENCH-5b exit 0; hosted-mode BENCH-5a exit 133 with `gate=BENCH-5a` |
| BENCH-6 forced overrun | PASS | p95 8.001 ms; exit 133; `gate=BENCH-6` |
| Benchmark ratio falsifiability | PASS | normal and inclusive-boundary fixtures pass; 1.250151 overrun reports FAIL as required |
| Workflow + scripts | PASS | workflow YAML parsed; every shell script passed `sh -n`; `git diff --check` passed |

The affected battery ran after the final script/workflow changes. Because the
diff contains no `Sources/`, `Tests/`, or `docs/verification/` path, no further
production/test full-battery expansion is triggered by this triage directive.
