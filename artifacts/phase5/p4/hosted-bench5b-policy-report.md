# Hosted BENCH-5b informational policy implementation

Date: 2026-07-17

Owner-decision implementation revision:
`afc03ddf236a816627ea408064541bd34b4e5b2f`

Accepted triage revision:
`c992198c2118f9540c805e6b8c5e31344c1a0f03`

## 1 — Harness-boundary mechanism: RESOLVED

`RenderBenchmark` reads one policy mode input:
`BENCH5B_ENFORCEMENT`. Absence and every value other than exact `off` retain
the unchanged blocking 1.0 ms precondition. Only the hosted benchmark workflow
step sets `BENCH5B_ENFORCEMENT=off`, beside a YAML comment naming the
2026-07-16 owner decision.

Both modes emit the ordinary BENCH-5b p50/p95/max row. Hosted-off additionally
emits:

```text
BENCH-5b enforcement: bench5b_enforcement=off result=INFORMATIONAL
```

BENCH-2b's nonzero-strip precondition and BENCH-5a's 16.7 ms precondition are
unchanged and remain trapping in both modes. No `continue-on-error`, retry, or
threshold adjustment exists.

## 2 — Falsifiability: RESOLVED

`scripts/test-benchmark-enforcement-modes.sh` performs three deterministic
full-scenario runs:

| Fixture | Required behavior | Result |
|---|---|---|
| Default mode + forced BENCH-5b overrun | exit 133; retained BENCH-5b diagnostic | PASS — 1.001 ms, line 218 |
| Hosted-off + forced BENCH-5b overrun | informational row/tag; exit 0 | PASS — 1.001 ms |
| Hosted-off + forced BENCH-5a and BENCH-5b overruns | BENCH-5b remains informational; BENCH-5a traps | PASS — 16.701 ms / 1.001 ms, exit 133 at line 216 |

The fixture-only `BENCHMARK_GATE_FIXTURE` selector is not set by the production
benchmark workflow step.

## 3 — Reporting and comparisons: RESOLVED

The hosted comparison artifact retains every per-metric ratio row and adds:

```text
bench5b_enforcement=off result=INFORMATIONAL reason=owner-decision-2026-07-16
```

The local comparison script and output format are unchanged. The final local
comparison passed all seven owner-reference ratios:

`bench5b-policy-hosted-comparison-simulation.txt` applies the workflow's
reporting format to the final hosted-policy simulation. It confirms the new
enforcement annotation coexists with every original ratio row and the BENCH-5
bootstrap rows. The simulated hosted ratio result remains informational even
when a row reports `FAIL`; only the unchanged absolute gates determine the
benchmark step's exit.

| Metric | Observed | Ratio | Result |
|---|---:|---:|---|
| BENCH-1 p95 | 5.564 ms | 1.045079 | PASS |
| BENCH-2 p95 | 0.112 ms | 1.027523 | PASS |
| BENCH-2b p95 | 5.899 ms | 1.011662 | PASS |
| BENCH-3 p95 | 9.400 ms | 1.061787 | PASS |
| BENCH-3 settle | 3.097 ms | 1.114831 | PASS |
| BENCH-5a p95 | 0.010 ms | 0.027548 | PASS |
| BENCH-5b p95 | 0.840 ms | 0.953462 | PASS |

The pre-existing ratio fixtures also passed: exact 1.25 is accepted and the
1.314801 sample is rejected.

## 4 — Documentation and owner decision: RESOLVED

The owner decision is recorded verbatim in `docs/PROJECT_STATE.md`.
`docs/phase-4/ci-policy.md` now separates:

- BENCH-1/2/2b/3 and settle: blocking local and hosted;
- BENCH-5a: blocking local and hosted;
- BENCH-5b: blocking at unchanged 1.0 ms on owner-reference hardware and
  informational hosted;
- local ratio: blocking; hosted ratio: informational.

The run-16, run-17, and controlled-contention evidence chain and the standing
BENCH-1 headroom WATCH are retained.

## 5 — Final-revision affected gates and scope: RESOLVED

### Local blocking mode

| Scenario | Observation | Target | Result |
|---|---:|---:|---|
| BENCH-1 drag p95 | 5.564 ms | <= 16.7 ms | PASS |
| BENCH-2 pan p95 | 0.112 ms | <= 16.7 ms | PASS |
| BENCH-2b forced-exposure p95 | 5.899 ms; 360/360 strips | <= 16.7 ms | PASS |
| BENCH-3 zoom p95 | 9.400 ms | <= 33 ms | PASS |
| BENCH-3 settle | 3.097 ms | <= 100 ms | PASS |
| BENCH-4 cold-open | 8.594 ms | informational | RECORDED |
| BENCH-5a p95 | 0.010 ms | <= 16.7 ms | PASS |
| BENCH-5b p95 | 0.840 ms | <= 1.0 ms | PASS — BLOCKING |

### Hosted-policy simulation

| Scenario | Observation | Hosted policy | Result |
|---|---:|---|---|
| BENCH-1 drag p95 | 5.415 ms | blocking | PASS |
| BENCH-2 pan p95 | 0.108 ms | blocking | PASS |
| BENCH-2b forced-exposure p95 | 5.726 ms; 360/360 strips | blocking | PASS |
| BENCH-3 zoom p95 | 8.980 ms | blocking | PASS |
| BENCH-3 settle | 3.727 ms | blocking | PASS |
| BENCH-4 cold-open | 9.929 ms | informational | RECORDED |
| BENCH-5a p95 | 0.012 ms | blocking | PASS |
| BENCH-5b p95 | 0.824 ms | informational | RECORDED |

Scope diff from accepted triage `c992198` to build input `afc03dd`:

```text
M  .github/workflows/ci.yml
M  Sources/RenderBenchmark/main.swift
M  docs/PROJECT_STATE.md
M  docs/phase-4/ci-policy.md
M  scripts/run-render-benchmark.sh
A  scripts/test-benchmark-enforcement-modes.sh
```

No production module under `Sources/` outside `Sources/RenderBenchmark`
changed. No file under `Tests/` changed. No frozen target, ratio, tolerance,
ceiling, VERIFY value, benchmark scenario, warm-up count, measured-frame count,
or production-path selection changed.

## External hosted completion: OPEN

The operator must push the evidence-final revision and manually dispatch that
exact revision. Closure requires all eight jobs green and retention of the
benchmark and informational comparison artifacts. The dispatch response must
quote the complete hosted BENCH table verbatim, including blocking BENCH-5a
and informational BENCH-5b.
