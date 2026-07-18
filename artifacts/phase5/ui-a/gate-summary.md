# U3-A gate summary

Validated revision: `65f3cf4283558205e5b22b7bf8c86096544622d9` on macOS 15.7.5, Apple M1 Max, arm64, Swift 6.1.2.

| Gate | Exact observation | Result |
|---|---|---|
| Debug tests | 140 tests passed in 15.539 s | PASS |
| Golden tests | 2 selected canonical/render golden tests passed | PASS |
| Release tests | 140 tests passed in 1.452 s | PASS |
| AddressSanitizer | Main batch: 138 passed in 51.302 s; isolated parser deadline: 1 passed in 0.037 s; isolated geometry deadline: 1 passed in 0.885 s | PASS |
| Coverage | 90.72%; minimum 55% | PASS |
| BENCH-1 drag p95 | 4.805 ms; baseline 4.961 ms; ratio 0.968555; allowed 1.25 | PASS |
| BENCH-2 pan p95 | 0.117 ms; baseline 0.116 ms; ratio 1.008621; allowed 1.25 | PASS |
| BENCH-2b exposure p95 | 0.330 ms; baseline 0.387 ms; ratio 0.852713; exact corridor indices true | PASS |
| BENCH-3 zoom p95 | 6.415 ms; baseline 6.669 ms; ratio 0.961913; allowed 1.25 | PASS |
| BENCH-3 settle | 15.164 ms; baseline 12.231 ms; ratio 1.239801; allowed 1.25 | PASS |
| BENCH-5a undo/redo p95 | 0.011 ms; baseline 0.363 ms; ratio 0.030303 | PASS |
| BENCH-5b record p95 | 0.844 ms; baseline 0.881 ms; ratio 0.958002; blocking enforcement on | PASS |
| BENCH-6 tile edit p95 | 4.964 ms; baseline 4.619 ms; ratio 1.074691; exact damage mapping and nonzero hits | PASS |
| Memory settle | 460,734,464 B; limit 524,288,000 B; headroom 63,553,536 B | PASS |
| Memory export | 470,024,192 B; limit 681,574,400 B; headroom 211,550,208 B | PASS |
| Memory forced-failure fixture | 1,036,894,208 B exceeds 524,288,000 B and gate reports `FAIL` as required | PASS |
| Startup | 20 samples; p50 190.016 ms; p95 213.762 ms; max 229.270 ms; target 2,000 ms | PASS |
| Reliability | 100 launches, 100 distinct PIDs, 10,000 round trips, 0 crashes/nonzero exits/timeouts/corruption failures | PASS |
| Accessibility shell contract | 3 selected tests passed | PASS |
| Format and theme-token lint | Strict Swift format lint and permanent UI token grep exited 0 | PASS |
| Dependency and clean-room checks | Both exited 0 | PASS |
| Dark-mode screenshot | Captured from the release shell; owner visual acceptance remains manual | CAPTURED |

The nearest performance margin is BENCH-3 settle at 1.239801x against the 1.25x limit; it remains a passing observation and is not rounded down in this record.
