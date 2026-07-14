# Performance dashboard

Environment: arm64 macOS 15.7.5 on `MacBookPro18,2` (Apple M1 Max, 64 GB),
Swift 6.1.2. Results are local observations, not cross-hardware release
certification. Current raw results are in `artifacts/r4/`.

| Workload | Configuration | Observed / gate |
|---|---|---|
| BENCH-1 selected-object drag | Release, 60 warm-up + 300 measured | p95 5.518 ms <= 16.7 ms |
| BENCH-2 cached pan | Same | p95 0.113 ms <= 16.7 ms |
| BENCH-2b forced-exposure pan | Same | p95 5.987 ms; source precondition covers 360/360 frames |
| BENCH-3 zoom / settle | Same | p95 9.043 ms <= 33 ms; settle 2.990 ms <= 100 ms |
| BENCH-4 cold full redraw | Fresh harness before scenario warm-up | 9.088 ms, informational |
| Full automated suite | Release, 89 tests | 1.136 s on complete-battery revision `f6ec81a` |

Current BENCH-R3.5 and memory results were rerun at portability revision
`b6cee43`; startup remains mapped to complete-battery revision `f6ec81a`. All use explicit warm-up/sample
policies and are recorded in `docs/phase-4/R4-checkpoint.md`. Real minimum-OS
runtime proof is closed; hosted-CI proof remains open in `docs/PROJECT_STATE.md`.
