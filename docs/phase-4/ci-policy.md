# R4 CI and reliability policy

## Platform lanes

The hosted arm64 lane uses macOS 15. CI also compiles with
`MACOSX_DEPLOYMENT_TARGET=13.0`, but that is not a macOS 13 runtime test. ADR-011
requires the 100-launch reliability script on real macOS 13 Apple Silicon before
A7/R4 acceptance. That external run is currently missing (BLOCK-002).

## Enforced jobs

CI separates debug/release, ASan, adversarial/golden, benchmark, coverage,
startup/memory, release-integrity, and scheduled reliability jobs. Coverage has
a 55% line floor, excluding test and generated runner code. Public symbol-graph
emission, dependency direction, clean-room build inputs, an ad-hoc
hardened-runtime signature, and arm64 binary integrity are enforced.

`scripts/check-startup-p95.sh` launches 20 clean application processes. Start is
the executable's static initializer; stop is after the sample document canvas,
window, toolbar and autosave timer are ready. Each run uses a fresh HOME (cold
application state); OS/framework/filesystem caches are not purged. The target is
the Phase 1 PRD's p95 <= 2,000 ms.

`scripts/check-peak-memory.sh` uses `/usr/bin/time -l` maximum resident set size
for a 1,000-object/10,000-anchor/10-image (50 MP metadata) representative
document. It enforces the Phase 1 PRD ceilings as binary units: 500 MiB after
settled render and 650 MiB during production Core Graphics/ImageIO PNG export.
Exceeding either value exits nonzero. Raw logs are uploaded.

The scheduled `scripts/nightly-reliability.sh` executes 100 separate application
processes. Each performs 100 native encode/decode round trips, producing 10,000
aggregate cycles. Every process has a 30-second watchdog. Any crash, timeout,
nonzero exit, missing success marker or codec error fails the job; the per-launch
and summary log is uploaded.

## Benchmark regression policy

The absolute BENCH-R3.5 targets bind on owner reference hardware. Hosted CI also
runs `scripts/check-benchmark-regression.sh`. Each BENCH-1/2/2b/3 p95 and
BENCH-3 settle value must be <= 1.25 times its baseline. Missing, empty, unknown,
or past-`valid_until` baselines fail closed. The comparison log is uploaded even
on failure. `scripts/test-benchmark-regression-gate.sh` proves a below-threshold
fixture passes and a 1.314801 ratio fails.

The committed baseline records the accepted owner-reference run at `d68f415`;
it is explicitly not a hosted-runner artifact. Baseline updates require a reviewed
commit containing a green known-good hosted run, unchanged scenario/sample
semantics, source run URL/artifact, measurement date and 90-day expiry. Since no
remote or hosted run is available in this checkout, BLOCK-006 remains open even
though enforcement and failure behavior are implemented.

## Boundaries

The parser deadline harness is cooperative and in-process, not a hard-kill
isolation boundary. Developer ID signing/notarization requires owner credentials.
Manual VoiceOver, multi-display review and long-duration Instruments observation
remain operator checks and are not represented as automated passes.

Swift mutation tooling remains deferred because no maintained Swift 6-compatible
tool is approved here. The substitute is the frozen VERIFY-001–021 suite plus
deterministic property and adversarial mutation tests; those tests are not called
coverage-guided fuzzing.
