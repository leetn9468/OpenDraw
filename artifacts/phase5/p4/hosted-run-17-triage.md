# Hosted RenderBenchmark run 17 SIGTRAP triage

Date: 2026-07-16

Failing workflow run:
`https://github.com/leetn9468/OpenDraw/actions/runs/29499008599`

Same-revision automatic push run:
`https://github.com/leetn9468/OpenDraw/actions/runs/29498775517`

Revision executed by both hosted runs:
`36e46319e88ba6ee68e9acf826548900122137ad`

Evidence-preservation fix:
`a364fd1d7352a63d46277417995364c8a31ad6d6`

## STEP-1 — recovered evidence

The failing benchmark step ended with these exact raw log lines:

```text
2026-07-16T12:41:22.8379690Z scripts/run-render-benchmark.sh: line 14:  1678 Trace/BPT trap: 5       .build/release/RenderBenchmark > "$benchmark_log" 2>&1
2026-07-16T12:41:22.8513250Z ##[error]Process completed with exit code 133.
```

The retained `benchmark.txt` contains only the environment header. Therefore
the last completed `BENCH-x` line in run 17 is **not recoverable**: no BENCH
line survived the redirected Swift stdout buffer. The Swift runtime emitted no
precondition text or `file:line` into either the raw job log or the partial
artifact. This absence is itself preserved in
`hosted-run-17-partial-benchmark.txt`; a file:line must not be invented for the
original run.

The automatic push run on the identical revision did not trap. It completed
all sections, proved `BENCH-2b strip_redraw_frames=360
nonzero_every_frame=true`, and reported:

```text
BENCH-5a undo-redo: p50 0.010 ms | p95 0.011 ms | max 0.055 ms
BENCH-5b record: p50 0.194 ms | p95 0.938 ms | max 1.105 ms
```

## STEP-2 — classification

**H1 is disproved.** The same-revision push run completed BENCH-2b with
360/360 nonzero-strip frames. The controlled high-contention reproduction on
the evidence-fix revision also completed BENCH-2b with 360/360 frames before
trapping. The forced-exposure proof remains live and unchanged.

**H2 is disproved.** `RenderBenchmark` does not query `NSScreen`, a display,
or a dynamic backing scale. It constructs a fixed 800 × 500 bitmap context.
There is no headless forced unwrap or screen-scale precondition on this path.

**Classification: H3's environment/timing subcase at the BENCH-5b absolute
gate, not delta-state corruption.** `RenderBenchmark` has only three release preconditions:
BENCH-2b at `main.swift:117`, BENCH-5a at line 194, and BENCH-5b at line 195.
BENCH-2b completed in both the successful hosted run and the controlled
reproduction. Under CPU contention, the unchanged binary completed every
section with BENCH-5a p95 0.026 ms and BENCH-5b p95 12.277 ms, then exited 133.
The updated wrapper retained:

```text
BENCH_TRAP exit=133 last_completed=BENCH-5 mix=structural,composite,anchor-slice history=delta-only
BENCH_TRAP source=Sources/RenderBenchmark/main.swift:195 gate=BENCH-5b observed_p95_ms=12.277 target_p95_ms=1.0
```

This controlled value is not substituted for the unrecoverable run-17 value.
Together with the same-revision hosted success, the fixed, renderer-independent
strip-count construction, and the absence of any screen-dependent code, it
identifies run 17 as the standing hosted BENCH-5b timing/owner-decision case.
It also proves that shared-runner load can exercise the same silent line-195
trap and that the missing original evidence was a buffering problem.

## STEP-3 — fix and verification

The benchmark wrapper now runs the binary with `NSUnbufferedIO=YES`, retains
the binary's exit status, and on exit 133 appends the last completed BENCH line
plus the uniquely identifiable source gate and observed/target values. It
still exits 133. No precondition, target, comparison, retry, or hosted/local
semantic changed.

Affected-gate results on exact revision
`a364fd1d7352a63d46277417995364c8a31ad6d6`:

| Gate | Result |
|---|---|
| BENCH-1 | PASS — p95 5.522 ms ≤ 16.7 ms |
| BENCH-2 | PASS — p95 0.110 ms ≤ 16.7 ms |
| BENCH-2b | PASS — p95 5.803 ms ≤ 16.7 ms; 360/360 strips |
| BENCH-3 | PASS — p95 8.984 ms ≤ 33 ms; settle 2.914 ms ≤ 100 ms |
| BENCH-4 | INFORMATIONAL — 9.311 ms |
| BENCH-5a | PASS — p95 0.010 ms ≤ 16.7 ms |
| BENCH-5b | PASS — p95 0.902 ms ≤ 1.0 ms |
| Owner-reference local ratios | PASS — all seven ≤ 1.25 |
| Ratio fixtures | PASS — exact 1.25 accepted; 1.314801 rejected |
| Exit-133 diagnostic fixture | PASS — BENCH-5b line 195 and values retained |

Because the change is confined to the benchmark wrapper, the directive's
affected-gates rule applies; no full source/test battery rerun is required.

## STEP-4 — qualifying hosted rerun

Push the evidence-final revision and manually dispatch that exact revision.
The push run may be observed, but the manually dispatched run is the requested
qualifying execution. The absolute gates remain blocking. If hosted BENCH-5b
exceeds 1.0 ms, the job will still fail; the populated artifact will now
contain its exact p50/p95/max and the line-195 diagnostic. Report those values
verbatim and stop for the owner decision. The informational ratio artifact
continues unchanged.
