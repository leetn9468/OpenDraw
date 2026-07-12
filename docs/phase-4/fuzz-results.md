# Parser robustness corpus and results

The R4 deterministic corpus mutates project-created valid native and SVG seeds
256 times each with a fixed linear-congruential seed. Every input must either
decode safely or return a controlled error within the production two-second
deadline wrapper. Fixed adversarial classes cover deep nesting, huge counts,
entity expansion, overflow dimensions, truncation, invalid UTF-8, path traversal,
pre-dispatch cancellation, active SVG content, and malformed raster bytes.

Result on 2026-07-13, arm64 macOS: 512 deterministic mutations and every fixed
adversarial class passed; the combined mutation corpus completed in 0.025 seconds.

This is the documented deterministic CI floor rather than coverage-guided fuzzing.
Nightly CI runs a larger fixed-seed iteration count and retains failing mutation
indices as reproducible artifacts. No proprietary sample is permitted.
