# Parser robustness corpus and results

This is deterministic fixed-seed mutation testing, not coverage-guided fuzzing.
`Tests/DocumentFormatsTests/AdversarialCorpusTests.swift` starts each native and
SVG corpus at `UInt64(0x00000000A110F00D)` (`2,702,241,805`), then uses the LCG
`state = state * 6,364,136,223,846,793,005 + 1` with wrapping UInt64 arithmetic.
For mutation index `i`, it performs `1 + i % 8` byte edits; each edit selects
`state % input.count` and XORs the byte with the truncating low byte of
`state >> 24`. Each corpus restarts from the same seed and contains 256 inputs.

The exact permanent tests are:

- `deterministicNativeAndSVGMutationCorpusMeetsDeadline` — 256 native plus 256
  SVG mutations from project-created valid seeds;
- `fixedAdversarialClassesFailSafely` — seven directly enumerated cases in that
  method: four malformed native inputs, entity-bearing SVG, pre-dispatch
  cancellation, and linked-path traversal. Additional depth/count/string/image
  boundary cases live in the exact `verify011*` and raster-loader tests.

The two-second `AdversarialParserHarness` wrapper is cooperative and in-process.
It races a parser task with a cancellation/deadline task; it is not process
isolation and cannot hard-kill non-cooperative synchronous parser code. Bounded
input/structure limits remain the primary hard resource control.

The final local command was `swift test --filter
'deterministicNativeAndSVG|fixedAdversarial'`; it passed on implementation
complete-battery revision `f6ec81a`. Raw output is retained at
`artifacts/r4/adversarial-tests.txt`. A reproducible failure record uses
`CORPUS_FAILURE kind=<native|svg> index=<0-based> seed=0x00000000A110F00D` in
the retained test log; the input is regenerated from the named seed, index,
LCG, and project-created base fixture rather than retaining untrusted bytes.

CI artifact name is `adversarial-golden`; a final hosted CI run reference is
unavailable because this checkout has no configured remote. That missing hosted
evidence is recorded with BLOCK-006 rather than invented.

No proprietary sample is permitted.

This LCG is test-side numeric policy. It uses exact wrapping UInt64 operations
to make corpus generation reproducible and introduces no production mathematical
behavior or verification-queue obligation.
