# Test strategy

| Level | Current baseline | Growth path |
|---|---|---|
| Unit | Colors, geometry, invariants, text metrics | Every behavior branch and error |
| Property sample | Identity transform across generated values | Deterministic seeded generators for transforms/paths |
| Integration | Command history, native round trip | Full command catalog, atomic file I/O |
| Render | Bitmap creation at zooms/compositing features | Checked-in original goldens; ≤1 channel unit exact or documented perceptual threshold |
| Security/fuzz | Size/version rejection | Swift fuzz harness for native/SVG parsers with corpus and resource limits |
| Performance | Swift hit tests, 1,000-path render | Release baselines for startup, frame p95, load, memory |
| UI/accessibility | Application shell | XCUITest primary journey and manual hardware/VoiceOver matrix |

Tests must be deterministic, independently authored, and traceable to Phase 1
`AT-*` scenarios as production behaviors arrive. Performance tests report hardware,
OS, build configuration, sample count, median, and p95. Golden updates require a
reviewed reason and cannot be used merely to silence a regression.
