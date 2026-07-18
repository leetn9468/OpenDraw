# T3 enforcement-fixture immunity — run 29623884375

Failing run: <https://github.com/leetn9468/OpenDraw/actions/runs/29623884375>

Exact dispatched revision: `6090efe8d9649c57acaac26d8eb332555f0eb38c`.
Seven jobs passed. Benchmark job `88024307229` failed in
`Prove hosted BENCH-5b policy remains falsifiable`, not in the real hosted
measurement.

## Real gate result

The production benchmark step had exactly the two decision-backed policy
inputs and passed:

```text
BENCH5B_ENFORCEMENT: off
BENCH6_TIMING_ENFORCEMENT: off
BENCH-1 drag: p50 4.045 ms | p95 5.260 ms | max 6.702 ms
BENCH-2 pan: p50 0.098 ms | p95 0.144 ms | max 0.432 ms
BENCH-2b exposure corridor: p50 0.260 ms | p95 0.368 ms | max 0.622 ms
BENCH-2b exact_indices=true setup_columns=0...3 frame_formula=(f+3,0),(f+3,1) frames=1...360 warmup=1...60 measured=61...360 rendered_regions=728
BENCH-3 zoom: p50 5.472 ms | p95 6.278 ms | max 6.964 ms
BENCH-3 settle: 11.113 ms
BENCH-5a undo-redo: p50 0.010 ms | p95 0.010 ms | max 0.024 ms
BENCH-5b record: p50 0.179 ms | p95 0.839 ms | max 0.870 ms
BENCH-6 tile-edit: p50 4.475 ms | p95 6.505 ms | max 10.571 ms
BENCH-6 assertions cache_hits=nonzero rendered_tiles=exact_damage_mapping warmup_frames=60 measured_frames=300 result=BLOCKING
```

## Fixture failure — verbatim root cause

Case 1 behaved correctly: forced BENCH-5b p95 `1.001 ms` trapped at
`gate=BENCH-5b`. Case 2 turned BENCH-5b off but left BENCH-6 timing blocking.
The shared runner then produced an organic BENCH-6 overrun:

```text
BENCH_GATE_FIXTURE=bench5b-overrun
BENCH-5b record: p50 0.176 ms | p95 1.001 ms | max 1.001 ms
BENCH-5b enforcement: bench5b_enforcement=off result=INFORMATIONAL
BENCH-6 tile-edit: p50 5.731 ms | p95 9.464 ms | max 17.329 ms
BENCH-6 assertions cache_hits=nonzero rendered_tiles=exact_damage_mapping warmup_frames=60 measured_frames=300 result=BLOCKING
BENCH_TRAP source=Sources/RenderBenchmark/main.swift:323 gate=BENCH-6 observed_p95_ms=9.464 target_p95_ms=8.0
##[error]Process completed with exit code 133.
```

This is fixture contamination, not a production-gate failure. It is the same
class as the earlier `bench5a-and-b-overrun` selector overlap: a nontarget
timing precondition selected the fixture's exit.

## Class fix

| Requirement | Implementation |
|---|---|
| Per-gate timing modes | Seven default-ON inputs cover BENCH-1/2/2b/3/5a/5b/6; BENCH-3's input covers both p95 and settle |
| Organic-trap immunity | `run-render-benchmark-fixture.sh` sets all timing modes OFF, then enables only the deterministic target |
| Correctness remains blocking | Corridor exact-index/hit assertions and BENCH-6 hit/exact-mapping assertions remain outside every timing guard |
| Production policy exactness | Workflow production step contains exactly 5b OFF and 6 timing OFF; executable checker rejects any third OFF input |
| Timing falsifiability | Eight deterministic cases (including BENCH-3 p95 and settle separately) require exit 133 and the exact gate tag |
| Hosted-policy falsifiability | Forced 5b and forced 6 each emit informational rows and exit zero in fixture isolation |
| Correctness falsifiability | All timing OFF plus injected BENCH-6 over-invalidation still exits 133 |

No frame schedule was reduced. Production remains 60 warm-up plus 300
measured frames, and the corridor remains the frozen 360-frame schedule. No
deadline, threshold, target, ratio, corpus value, or frozen value changed.
Production renderer modules and `Tests/` are untouched.

Implementation revision: `4f101584f651e07ecd7d8b3f6264f706f765ac76`.

## Final affected local gates

| Gate | Result | Exact evidence |
|---|---|---|
| Strict Swift format + diff check | PASS | No diagnostics |
| Ordinary production full BENCH battery | PASS | BENCH-1 4.927; BENCH-2 0.111; BENCH-2b 0.322; BENCH-3 6.632; settle 14.718; BENCH-5a 0.010; BENCH-5b 0.853; BENCH-6 4.944 ms |
| Corridor correctness | PASS | `exact_indices=true`, frozen frame formula, `rendered_regions=728` |
| BENCH-6 correctness | PASS | Nonzero hits and exact damage mapping over 60+300 frames |
| Owner-reference ratios | PASS | All eight rows <= unchanged inclusive 1.25; largest ratio 1.203336 |
| Ratio falsifiability | PASS | Every exact 1.25 boundary passes; 1.250151 reports FAIL |
| Targeted timing falsifiability | PASS | Eight cases exit 133 with BENCH-1/2/2b/3/3-settle/5a/5b/6 tags |
| Hosted-policy timing cases | PASS | Forced 5b and forced 6 each exit zero with both informational rows |
| Timing-mode isolation | PASS | Only targeted BENCH-5a enabled; forced 16.701 exits 133 |
| Correctness with all timings OFF | PASS | Injected BENCH-6 over-invalidation exits 133 with correctness tag |
| Production env exactness | PASS | Exact 5b/6 OFF set passes; injected BENCH-1 OFF exits 1 |
| Scope audit | PASS | Only `Sources/RenderBenchmark`; no production renderer module, `Tests/`, or frozen verification file changed |

Raw evidence is retained in the sibling `fixture-immunity-*.txt` artifacts.

## Closure state

**OPEN — operator dispatch required.** After local evidence is committed, the
operator must push and manually dispatch that exact revision. Eight green jobs
plus the full hosted BENCH table close T3 S6; any red job is reported verbatim
without adjustment.
