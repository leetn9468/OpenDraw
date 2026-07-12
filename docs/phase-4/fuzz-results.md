# Parser robustness corpus and results

The current deterministic native-format corpus generates 128 byte sequences of
length 0–127 from a fixed linear-congruential seed. Every input must return a
controlled error. Additional fixed cases cover missing version, future version,
oversized input policy, malformed SVG, active SVG content, unsupported SVG elements,
unsafe raster links and malformed raster bytes.

Result on 2026-07-12, Swift 6.1.2, arm64 macOS 15.7.5: all corpus assertions passed.

This is a regression corpus, not coverage-guided fuzzing. Before accepting broader
SVG syntax, add a persistent fuzz target with timeout/memory limits, crash artifact
retention and minimized project-authored seeds. No proprietary sample is permitted.
