# T3 hosted BENCH-6 policy — run 29622813655

Run: <https://github.com/leetn9468/OpenDraw/actions/runs/29622813655>

Exact revision: `6208f5224a0fefa10fb8fae90008f7f5a4b4961a`.
Seven jobs passed. Benchmark job `88021068701` failed only because the hosted
BENCH-6 timing p95 exceeded the unchanged local target.

```text
BENCH-6 tile-edit: p50 7.540 ms | p95 16.964 ms | max 113.417 ms
BENCH-6 assertions cache_hits=nonzero rendered_tiles=exact_damage_mapping warmup_frames=60 measured_frames=300 result=BLOCKING
BENCH_TRAP source=Sources/RenderBenchmark/main.swift:310 gate=BENCH-6 observed_p95_ms=16.964 target_p95_ms=8.0
```

The same run retained the corridor invariant:

```text
BENCH-2b exact_indices=true setup_columns=0...3 frame_formula=(f+3,0),(f+3,1) frames=1...360 warmup=1...60 measured=61...360 rendered_regions=728
```

Run #22 had measured BENCH-6 p95 4.787 and 5.708 ms in its hosted fixture
executions. The subsequent 16.964 ms observation is a greater-than-3.5-times
cross-run swing on identical benchmark code. This evidence triggered the
2026-07-18 owner decision recorded verbatim in `docs/PROJECT_STATE.md`.

## Implementation map

| Requirement | Implementation |
|---|---|
| Default local timing enforcement | `BENCH6_TIMING_ENFORCEMENT` defaults ON; unchanged 8.0 ms p95 precondition remains trapping |
| Hosted timing policy | Only the hosted measurement step sets timing enforcement `off`; p50/p95/max plus the owner-decision tag are retained |
| Correctness isolation | Nonzero-hit and exact-damage-mapping preconditions remain outside the timing guard and execute every frame |
| Default timing falsifiability | Forced 8.001 ms p95 exits 133 with `gate=BENCH-6` |
| Informational timing proof | Forced 8.001 ms p95 emits the informational row and exits zero |
| Mode isolation | With timing off, forced BENCH-5a 16.701 ms still exits 133 with `gate=BENCH-5a` |
| Correctness falsifiability | With timing off, injected over-invalidation exits 133 with `gate=BENCH-6-correctness-exact-damage-mapping` |

No production renderer module or `Tests/` file changed. No deadline, threshold,
target, ratio, corpus, or frozen value changed.

## Final affected local gates

| Gate | Result | Evidence |
|---|---|---|
| Ordinary local full BENCH battery | PASS | BENCH-1 4.885; BENCH-2 0.114; BENCH-2b 0.338 and `rendered_regions=728`; BENCH-3 6.624; settle 12.223; BENCH-5a 0.011; BENCH-5b 0.858; BENCH-6 4.776 ms |
| Ordinary local output compatibility | PASS | No BENCH-6 timing-mode row when the mode input is absent; both local timing gates default blocking |
| Owner-reference ratio comparison | PASS | All eight rows at or below unchanged inclusive 1.25; BENCH-6 ratio 1.033990 |
| BENCH-5b enforcement modes | PASS | Default forced overrun exits 133; hosted-off overrun exits zero; hosted-off BENCH-5a forced overrun exits 133 |
| BENCH-6 default timing falsifiability | PASS | Forced p95 8.001 ms exits 133 with `gate=BENCH-6` |
| BENCH-6 hosted timing policy | PASS | Forced p95 8.001 ms emits informational owner-decision row and exits zero |
| BENCH-6 mode isolation | PASS | Timing off plus forced BENCH-5a 16.701 ms exits 133 with `gate=BENCH-5a` |
| BENCH-6 correctness falsifiability | PASS | Timing off plus injected over-invalidation exits 133 with `gate=BENCH-6-correctness-exact-damage-mapping` |
| Exact hosted-mode dry run | PASS | BENCH-6 p95 4.739 ms; timing row informational; correctness row blocking; corridor `rendered_regions=728` |
| Ratio falsifiability | PASS | Normal and exact 1.25 boundary fixtures pass; 1.250151 fixture reports FAIL |
| Hosted reporting dry run | PASS | Extracted workflow reporting step emits BENCH-6 mode tag and owner-decision reason in `benchmark-comparison.txt` |
