# Tile caching T2 local gate summary

Implementation revision: `da6b14ca7809fb9b2e1328832fc7a2dc7967eb97`

| Gate | Flag | Result |
|---|---:|---|
| Strict format; debug/release/macOS-15 builds | — | PASS |
| Debug tests | OFF | PASS — 128 executed (127 legacy + S1) |
| Debug tests | ON | PASS — 140 executed |
| Release tests | OFF | PASS — 128 executed |
| Release tests | ON | PASS — 140 executed |
| AddressSanitizer | OFF | PASS — 127 main + 1 isolated deadline |
| AddressSanitizer | ON | PASS — 138 main + 1 isolated deadline + 1 isolated geometry |
| Coverage | ON | PASS — 90.31% >= unchanged 55% |
| VERIFY-033 | ON | PASS — 205 advances, all 64 steps + corpus-end commit, zero differing pixels |
| BENCH-1/2/2b/3/5 absolute and local ratios | direct | PASS |
| BENCH-6 absolute | explicit tile ON | PASS — p50 4.128, p95 4.658, max 4.996 ms; 3.342 ms headroom |
| BENCH-6 local ratio | explicit tile ON | PASS — 4.658 / 4.619 = 1.008443 <= 1.25 |
| BENCH-6 forced overrun | explicit tile ON | PASS — 8.001 ms trapped with exit 133 |
| Peak memory settle | — | PASS — 453,869,568 <= 524,288,000 B; headroom 70,418,432 B |
| Peak memory export | — | PASS — 462,700,544 <= 681,574,400 B; headroom 218,873,856 B |
| Peak-memory forced fixture | — | PASS — underlying settle rejected 1,031,258,112 B |
| Pressure ordering | ON | PASS — cache 134,217,728 B -> 0 before checkpoints; floor pins unchanged |
| Dependency / clean-room / symbol graph | — | PASS |
| Adversarial / golden / UI-accessibility | OFF | PASS — 3 / 2 |
| Startup | OFF | PASS — p95 152.611 ms <= 2,000 ms |
| Reliability | OFF | PASS — 100 launches / 10,000 round trips |
| Release assembly/signature | OFF | PASS |
| Hosted BENCH-6 enforcement | CI | WIRED — unchanged 8.0 ms absolute precondition is blocking; ratio report remains informational |

The first ON ASan attempt retained in
`asan-tests-flag-on-contended-failure.txt` had no sanitizer report and passed
VERIFY-033, but the unrelated geometry wall-clock test took 18.40 seconds
under contention. The final qualifying ON run isolated both wall-clock tests,
matching the accepted T1 method.
