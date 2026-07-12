# R4 CI policy

The hosted arm64 lane uses macOS 15. Until a hosted macOS 13 arm64 runner
exists, CI compiles with `MACOSX_DEPLOYMENT_TARGET=13.0` and the release
checklist requires the 100-run smoke script on real macOS 13 Apple Silicon, as
specified by ADR-011.

CI separates debug/release, ASan, adversarial/golden, benchmark, coverage, and
release-integrity jobs. Nightly runs execute 100 clean process smoke launches,
10,000 native round trips in aggregate, release tests, and BENCH-R3.5. Benchmark
artifacts are retained for ratio-based regression comparison.

Coverage has a 55% initial line threshold, measured without tests and generated
runners. Public API surface extraction must succeed. Swift mutation tooling is
not sufficiently stable/cost-effective for this package; the substitute is the
frozen VERIFY-001–021 suite plus high-iteration deterministic property and
adversarial tests. Revisit mutation testing when a maintained Swift 6-compatible
tool can run without rewriting package sources.
