# U3-B local gate summary

Validated revision: `a9f219c6b3f94befa55d7c5eba9409f4b80bd934`
on macOS 15.7.5, Apple M1 Max, arm64, Swift 6.1.2.

| Gate | Exact observation | Result |
|---|---|---|
| Debug tests | 144 main in 15.084 s + isolated 1 in 0.023 s + isolated 1 in 0.367 s = 146 | PASS |
| Release tests | 144 main in 1.451 s + isolated 1 in 0.021 s + isolated 1 in 0.006 s = 146 | PASS |
| AddressSanitizer | 144 main in 51.086 s + isolated 1 in 0.049 s + isolated 1 in 0.829 s = 146 | PASS |
| Coverage | 90.85%; unchanged minimum 55% | PASS |
| Canonical render goldens | 2 selected canonical/render tests; fixtures byte-identical | PASS |
| UI journey | Existing journey extended with two-axis align, modifier scale, Option corner break + undo, in-place text, undo depth >30, and composite/direct spot equality | PASS |
| Accessibility | Six align affordances and conditional text fields pinned in the existing shell contract | PASS |
| Theme/token lint | Selection-chrome token inventory and hard-coded-geometry lint exit 0 | PASS |
| BENCH-1 drag | p95 4.550 ms <= 16.7; ratio 0.917154 <= 1.25 | PASS |
| BENCH-2 pan | p95 0.108 ms <= 16.7; ratio 0.931034 <= 1.25 | PASS |
| BENCH-2b corridor | p95 0.281 ms <= 16.7; ratio 0.726098; `exact_indices=true`, `rendered_regions=728` | PASS |
| BENCH-3 zoom | p95 5.872 ms <= 33; ratio 0.880492 | PASS |
| BENCH-3 settle | 11.645 ms <= 100; ratio 0.952089 <= 1.25; U3-A watch did not recur | PASS |
| BENCH-5a undo/redo | p95 0.010 ms <= 16.7; ratio 0.027548 | PASS |
| BENCH-5b record | p95 0.801 ms <= 1.0; ratio 0.909194; local enforcement on | PASS |
| BENCH-6 tile edit | p95 4.517 ms <= 8.0; ratio 0.977917; nonzero hits and exact damage mapping | PASS |
| Benchmark chrome isolation | No RenderBenchmark dependency/reference to app shell, CanvasView, chrome, or Theme | PASS |
| Memory settle | 458,883,072 B <= 524,288,000 B; exact headroom 65,404,928 B | PASS |
| Memory export | 468,926,464 B <= 681,574,400 B; exact headroom 212,647,936 B | PASS |
| Memory forced fixture | 1,037,123,584 B exceeds 524,288,000 B and exits nonzero | PASS |
| Startup | 20 samples; p50 178.925 ms; p95 190.495 ms; max 193.822 ms; target 2,000 ms | PASS |
| Reliability | 100 launches, 100 PIDs, 10,000 round trips, zero failures | PASS |
| Dependency / clean room / symbol graph | Dependency and clean-room scripts exit 0; all module symbol graphs emit | PASS |
| Release integrity | arm64 app, ad-hoc signature, hardened runtime, sealed resources | PASS |
| Formatting | Strict Swift formatting exits 0 | PASS |
| Dark-mode mid-gesture screenshot | SHA-256 `471b5c010c3b56581d7912a0a0252d2b84f18b98af65a127c38c998eed1e4ad1`; approved by TN LEE on 2026-07-19 | PASS |

All machine-enforced gates and owner visual acceptance pass. U3-B and the UI
redesign are delivered.
