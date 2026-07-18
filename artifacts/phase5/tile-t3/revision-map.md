# Tile caching T3 revision map

Accepted T2: `da6b14c` (`6452540` evidence)
Frozen basis: `790c013`
Local gate input: `4f101584f651e07ecd7d8b3f6264f706f765ac76`
Final local evidence revision: `039560539127cb459f64216bd0ab93f5505a6de1`
Final hosted input revision: `039560539127cb459f64216bd0ab93f5505a6de1`
Closure evidence revision: this containing commit (`git rev-parse HEAD`)

| Scope | State | Commit | Files / evidence |
|---|---|---|---|
| S1 flag removal and production cutover | RESOLVED | `2b7e214`, `a7c5b9f` | `TileCompositeRenderer.swift`, `VectorFoundryApp/main.swift`, unconditional tile suites, `scope-proof.txt` |
| S2 BENCH-2b corridor supersession | RESOLVED | `2b7e214`, `5f18000` | `TileExposureCorridor.swift`, `RenderBenchmark/main.swift`, exact-index permanent test, `render-benchmark.txt` |
| S3 production BENCH-1/2/3 and baseline | RESOLVED | `2b7e214`, `58e867b` | production benchmark wiring, one-commit owner baseline rebase, `benchmark-comparison.txt` |
| S4 queue/state supersession record | RESOLVED | `3d17a17` | `tile-cache-T3.md`, `PROJECT_STATE.md`, `VERIFICATION_QUEUE.md`, ADR-014 |
| S5 full local battery and closure docs | RESOLVED | `be6b0d4`, `a7c5b9f`, `3d17a17` | `gate-summary.md` and all sibling logs |
| S6 hosted operator dispatch and eight-job report | RESOLVED | `44f2de0`, `6208f52`, `6090efe`, `4f10158`, `0395605`, this closure evidence commit | Run #28 (`29625792344`) manually dispatched exact `0395605`; all eight jobs green; production env exactness, corridor `rendered_regions=728`, BENCH-6 blocking correctness, and the full hosted BENCH table are retained in `hosted-run-28-closure.md` |

No frozen value changed. Every T3 deletion is listed with a successor or
owner-visible justification in `docs/phase-5/tile-cache-T3.md`.
