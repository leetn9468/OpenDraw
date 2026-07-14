# Hosted CI run #6 sanitizer triage

Date: 2026-07-14

Run: <https://github.com/leetn9468/OpenDraw/actions/runs/29345329291>

Failed job: <https://github.com/leetn9468/OpenDraw/actions/runs/29345329291/job/87127394397>

Run revision: `2cfa8453d87d69d64f03b5a5c435aeca01afcedc`

Corrective revision: `5d2ea50`

Disposition: CI #6 is a failed, non-qualifying push run. The benchmark job
passed in hosted-baseline bootstrap mode. Sanitizer was the only executed job
that failed; nightly reliability was skipped as expected for a push event.

## Exact failure

The supplied protected job log contains no AddressSanitizer diagnostic. It
records one Swift Testing expectation failure:

```text
CORPUS_FAILURE kind=native index=0 seed=0x00000000A110F00D
Expectation failed: (elapsed -> 7.901786791 seconds) < (.seconds(3) -> 3.0 seconds)
Test deterministicNativeAndSVGMutationCorpusMeetsDeadline() failed after 8.661 seconds with 1 issue.
```

All other tests passed. Many independent trivial tests completed together at
approximately 8.52 seconds in the same run. This establishes that the timed
mutation was charged for whole-suite shared-runner scheduling starvation, not
7.9 seconds of parser execution. The complete corpus test still finished in
8.661 seconds, below its unchanged 10-second full-corpus limit.

## Classification and correction

This is a real test-harness defect, not an ASan memory finding and not a gate
waiver. A per-operation wall-clock deadline cannot be measured meaningfully
while unrelated ASan tests compete for a shared hosted runner.

Revision `5d2ea50` adds `scripts/run-address-sanitizer-tests.sh`. The same
ASan-instrumented test set is executed in two invocations:

1. all tests except `deterministicNativeAndSVGMutationCorpusMeetsDeadline`;
2. that deadline-sensitive test alone using the already-built ASan test binary.

Both CI and `make sanitize` call the same script. This keeps hosted and local
gate semantics identical. There is no retry and no continue-on-error path.

## Frozen-rule proof

The test source is unchanged. Its 256 native mutations, 256 SVG mutations,
seed `0xA110F00D`, per-mutation `< 3 seconds` assertion, and full-corpus
`< 10 seconds` assertion are unchanged. No production source, expected value,
VERIFY entry, benchmark target, tolerance, ceiling, or retry policy changed.

## Exact-revision local verification

At corrective revision `5d2ea50`, the new shared gate passed:

| Invocation | Result |
|---|---|
| ASan suite excluding the isolated deadline test | 89/89 PASS in 11.232 s |
| Isolated ASan deadline test | 1/1 PASS in 0.036 s; test body 0.035 s |

Before the correction, the original full-suite command also passed one fresh
local run and ten consecutive local reruns, for 990 passing test executions.
That evidence explains the intermittent trigger but does not excuse it; the
harness was corrected so the deadline now measures the intended parser work.

## Remaining action

Push the corrective chain and allow its automatic push run to complete. Ignore
only the expected push-event nightly-reliability skip. Do not close BLOCK-006
from that run. Then manually dispatch the workflow on the exact final revision;
all eight jobs must execute and pass before the standing hosted-closure steps.
