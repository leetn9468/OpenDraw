# Performance dashboard

Environment: arm64 macOS 15.7.5 on `MacBookPro18,2` (Apple M1 Max, 64 GB),
Swift 6.1.2. Results are local observations, not cross-hardware release
certification. Current raw results are in `artifacts/r4/`.

| Workload | Configuration | Observed / gate |
|---|---|---|
| BENCH-1 selected-object drag | Release, 60 warm-up + 300 measured | p95 5.496 ms <= 16.7 ms |
| BENCH-2 cached pan | Same | p95 0.108 ms <= 16.7 ms |
| BENCH-2b forced-exposure pan | Same | p95 5.950 ms; source precondition covers 360/360 frames |
| BENCH-3 zoom / settle | Same | p95 8.953 ms <= 33 ms; settle 2.745 ms <= 100 ms |
| BENCH-4 cold full redraw | Fresh harness before scenario warm-up | 8.236 ms, informational |
| Full automated suite | Release, 89 tests | 1.135 s on complete-battery revision `b01364b` |

Current BENCH-R3.5 and memory/startup measurements use explicit warm-up/sample
policies and are recorded in `docs/phase-4/R4-checkpoint.md`. Hosted-CI and real
macOS 15 runtime proof remain open in `docs/PROJECT_STATE.md`.
