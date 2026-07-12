# Performance dashboard

Environment: arm64 macOS 15.7.5, Swift 6.1.2. Results are local observations, not
cross-hardware release certification.

| Workload | Configuration | Observed / gate |
|---|---|---|
| Render 1,000 identical path objects to 640×480 bitmap | Release, isolated | ~42 ms initial scene rebuild |
| Pan cached 1,000-object scene for 20 frames | Release | Every measured cached frame <16.7 ms (test assertion) |
| 20,000 cubic hit tests, 32-subdivision parameter | Release full suite | ~30 ms |
| Full automated suite | Release, 29 tests | ~49 ms test execution after build |

The initial rebuild does not meet the interactive frame budget and is explicitly not
hidden. Cached panning meets it; document mutations invalidate and rebuild the cache.
Future work: incremental tiled cache/damage rendering, representative nonidentical
objects, memory/RSS capture, cancellation tests, baseline Intel/8 GB hardware, and
median/p95 sampling rather than single-run observations.
