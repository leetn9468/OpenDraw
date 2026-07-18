# Tile caching T3 hosted closure — CI #28

Run: <https://github.com/leetn9468/OpenDraw/actions/runs/29625792344>

- Event: manual `workflow_dispatch`
- Status: `completed`
- Conclusion: `success`
- Exact head SHA: `039560539127cb459f64216bd0ab93f5505a6de1`
- Benchmark job: <https://github.com/leetn9468/OpenDraw/actions/runs/29625792344/job/88029808325>

## Eight-job result

| Job | Conclusion |
|---|---|
| benchmark | success |
| debug-release | success |
| startup-memory | success |
| sanitizer | success |
| adversarial-golden | success |
| release-integrity | success |
| nightly-reliability | success |
| coverage | success |

## Production environment proof

```text
production_benchmark_timing_env=BENCH5B_ENFORCEMENT=off,BENCH6_TIMING_ENFORCEMENT=off result=PASS
production_benchmark_extra_off_injection_exit=1 result=PASS
```

## Hosted BENCH table — verbatim

```text
BENCH_METADATA warmup_frames=60 measured_frames=300 production_paths=true bench5b_enforcement=off renderer=tile-composite bench2b_fixture=exposure-corridor
BENCH-1 drag: p50 3.821 ms | p95 3.893 ms | max 5.036 ms
BENCH-2 pan: p50 0.089 ms | p95 0.109 ms | max 0.126 ms
BENCH-2b exposure corridor: p50 0.324 ms | p95 0.783 ms | max 1.685 ms
BENCH-2b exact_indices=true setup_columns=0...3 frame_formula=(f+3,0),(f+3,1) frames=1...360 warmup=1...60 measured=61...360 rendered_regions=728
BENCH-3 zoom: p50 5.039 ms | p95 5.485 ms | max 7.733 ms
BENCH-3 settle: 11.470 ms
BENCH-4 cold-open: 20.223 ms
Warm full redraw: 0.161 ms
BENCH-5a undo-redo: p50 0.009 ms | p95 0.009 ms | max 0.015 ms
BENCH-5b record: p50 0.175 ms | p95 0.816 ms | max 0.883 ms
BENCH-5 mix=structural,composite,anchor-slice history=delta-only
BENCH-5b enforcement: bench5b_enforcement=off result=INFORMATIONAL
BENCH-6 timing enforcement: bench6_timing_enforcement=off result=INFORMATIONAL reason=owner-decision-2026-07-18
BENCH-6 tile-edit: p50 3.904 ms | p95 4.374 ms | max 6.585 ms
BENCH-6 assertions cache_hits=nonzero rendered_tiles=exact_damage_mapping warmup_frames=60 measured_frames=300 result=BLOCKING
BENCH-6 sequence=node-84 dx=alternating(+1,-1) dy=0 reference_scene_nodes=1000
```

## Fixture-class proof

All eight targeted timing cases exited 133 with their expected gate tags.
Hosted-policy forced BENCH-5b and BENCH-6 exited zero. Targeted BENCH-5a and
all-timing-off BENCH-6 correctness injection exited 133 as required. No
organic timing observation selected a fixture exit.

No deadline, threshold, target, ratio policy, schedule, corpus value, or frozen
value changed. CI #28 closes T3 S6 and the tile-caching feature.
