# Performance dashboard

Environment: arm64 macOS 15.7.5 on `MacBookPro18,2` (Apple M1 Max, 64 GB),
Swift 6.1.2. Results are local observations, not cross-hardware release
certification. Current raw results are in `artifacts/r4/`.

| Workload | Configuration | Observed / gate |
|---|---|---|
| BENCH-1 selected-object drag | Release, 60 warm-up + 300 measured | p95 5.403 ms <= 16.7 ms |
| BENCH-2 cached pan | Same | p95 0.107 ms <= 16.7 ms |
| BENCH-2b forced-exposure pan | Same | p95 5.915 ms; source precondition covers 360/360 frames |
| BENCH-3 zoom / settle | Same | p95 8.880 ms <= 33 ms; settle 3.044 ms <= 100 ms |
| BENCH-4 cold full redraw | Fresh harness before scenario warm-up | 10.291 ms, informational |
| Full automated suite | Release, 90 tests | 1.109 s on complete-battery revision `ce3b4b3` |

Current BENCH-R3.5, memory, startup, and reliability results were rerun at
complete-battery revision `ce3b4b3`. All use explicit warm-up/sample policies
and are recorded in `docs/phase-4/R4-checkpoint.md`. Real minimum-OS runtime
proof and qualifying CI #8 hosted proof are closed. The hosted baseline is now
committed; meaningful ratio enforcement begins with the next hosted run.
