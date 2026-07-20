# U3-B hosted closure — CI #32

Run: <https://github.com/leetn9468/OpenDraw/actions/runs/29686626995>

- Event: manual `workflow_dispatch`
- Status: `completed`
- Conclusion: `success`
- Exact head SHA: `8d604586406565718a1d2146c91214742a6ecc7d`
- Branch: `remediation/pre-phase5`
- Started: `2026-07-19T12:14:55Z` (`2026-07-19 20:14:55 UTC+08:00`)
- Completed: `2026-07-19T12:17:17Z`
- Benchmark job: <https://github.com/leetn9468/OpenDraw/actions/runs/29686626995/job/88191889427>

## Eight-job result

| Job | Duration | Conclusion | Job URL |
|---|---:|---|---|
| adversarial-golden | 35 s | success | <https://github.com/leetn9468/OpenDraw/actions/runs/29686626995/job/88191889410> |
| debug-release | 2 m 15 s | success | <https://github.com/leetn9468/OpenDraw/actions/runs/29686626995/job/88191889424> |
| benchmark | 1 m 52 s | success | <https://github.com/leetn9468/OpenDraw/actions/runs/29686626995/job/88191889427> |
| startup-memory | 48 s | success | <https://github.com/leetn9468/OpenDraw/actions/runs/29686626995/job/88191889434> |
| coverage | 56 s | success | <https://github.com/leetn9468/OpenDraw/actions/runs/29686626995/job/88191889437> |
| sanitizer | 1 m 57 s | success | <https://github.com/leetn9468/OpenDraw/actions/runs/29686626995/job/88191889439> |
| release-integrity | 41 s | success | <https://github.com/leetn9468/OpenDraw/actions/runs/29686626995/job/88191889445> |
| nightly-reliability | 41 s | success | <https://github.com/leetn9468/OpenDraw/actions/runs/29686626995/job/88191889447> |

## Hosted BENCH table — verbatim

```text
revision=8d604586406565718a1d2146c91214742a6ecc7d model=VirtualMac2,1 chip=Apple M1 (Virtual) memory_bytes=7516192768 os=15.7.7 build=24G720 arch=arm64 swift=swift-driver version: 1.120.5 Apple Swift version 6.1.2 (swiftlang-6.1.2.1.2 clang-1700.0.13.5)
BENCH_METADATA warmup_frames=60 measured_frames=300 production_paths=true bench5b_enforcement=off renderer=tile-composite bench2b_fixture=exposure-corridor
BENCH-1 drag: p50 3.711 ms | p95 3.800 ms | max 4.294 ms
BENCH-2 pan: p50 0.090 ms | p95 0.106 ms | max 0.117 ms
BENCH-2b exposure corridor: p50 0.200 ms | p95 0.231 ms | max 0.341 ms
BENCH-2b exact_indices=true setup_columns=0...3 frame_formula=(f+3,0),(f+3,1) frames=1...360 warmup=1...60 measured=61...360 rendered_regions=728
BENCH-3 zoom: p50 4.868 ms | p95 5.302 ms | max 5.820 ms
BENCH-3 settle: 10.139 ms
BENCH-4 cold-open: 18.604 ms
Warm full redraw: 0.168 ms
BENCH-5a undo-redo: p50 0.009 ms | p95 0.010 ms | max 0.021 ms
BENCH-5b record: p50 0.174 ms | p95 0.823 ms | max 0.858 ms
BENCH-5 mix=structural,composite,anchor-slice history=delta-only
BENCH-5b enforcement: bench5b_enforcement=off result=INFORMATIONAL
BENCH-6 timing enforcement: bench6_timing_enforcement=off result=INFORMATIONAL reason=owner-decision-2026-07-18
BENCH-6 tile-edit: p50 3.770 ms | p95 3.941 ms | max 4.319 ms
BENCH-6 assertions cache_hits=nonzero rendered_tiles=exact_damage_mapping warmup_frames=60 measured_frames=300 result=BLOCKING
BENCH-6 sequence=node-84 dx=alternating(+1,-1) dy=0 reference_scene_nodes=1000
```

The comparison artifact is informational by standing policy. It reports the
BENCH-3 settle ratio as `3.866895` (`10.139/2.622`), while the unchanged
blocking 100 ms absolute settle target passes. BENCH-1 has 12.900 ms absolute
headroom beneath 16.7 ms. No target or policy changed.

## Hosted system observations

- Startup: p50 `147.955 ms`, p95 `193.713 ms`, max `600.125 ms`, target
  `2,000 ms` — PASS.
- Memory settle: `459,948,032 B` under `524,288,000 B`, exact headroom
  `64,339,968 B` — PASS.
- Memory export: `468,221,952 B` under `681,574,400 B`, exact headroom
  `213,352,448 B` — PASS.
- Forced memory fixture: `874,561,536 B` exceeds `524,288,000 B` and reports
  FAIL as required.
- Reliability: 100 launches, 100 distinct PIDs, 10,000 round trips, zero
  crashes/nonzero exits/timeouts/corruption failures — PASS.

## Retained artifact manifest

| Artifact | Size | GitHub artifact SHA-256 |
|---|---:|---|
| OpenDraw-app | 913 KB | `8e5f6665f13626886246cb7623d2428bc0e8f7f53f9bb370949954bf2c1db627` |
| benchmark-comparison | 615 B | `c1235d5905f08f90985ab1e7b53a74c830bd4db8a4fa9f3b22fdb41f2ea5080f` |
| benchmark-results | 919 B | `3b0fecc272d9568966064bb99fb5b89711c39db9cbdc583f0f3fcdcc2ab92ab3` |
| hosted-benchmark-baseline-candidate | 587 B | `c2fa5012260df6e8ac1506379f6373b0897f518b66ff3f0b2e2f991088e7b006` |
| reliability-100x100 | 1.73 KB | `82ad6bc335f5772df6cc1843185d6629b2c4f1f61d1a49b9b2689210f8c098e7` |
| startup-memory-results | 320 KB | `b1662a05e0a2935648f67417072707142420dc59ab2905ff4b570918a845e390` |

The text payloads required for permanent verification are retained beside this
record. `ci-32-run.json`, `ci-32-jobs.json`, and `ci-32-artifacts.json` retain
the GitHub API responses. The release-app binary remains in GitHub artifact
retention and is pinned here by its artifact digest; it is not duplicated in
source control.

CI #32 closes U3-B hosted verification and the UI redesign feature. No frozen
value, test count, deadline, benchmark target, or enforcement policy changed.
