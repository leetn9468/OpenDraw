# ADR-011 macOS 15 platform-floor revision and R4 rerun report

Prepared: 2026-07-13  
Branch: `remediation/pre-phase5`  
Final build-input and battery revision: `f6ec81a88bee6a6b3055da850d08a6243061d090`  
Owner-reference environment: MacBookPro18,2, Apple M1 Max, 64 GB,
macOS 15.7.5 build 24G624, arm64, Apple Swift 6.1.2

## C1 — Build configuration

Commit `f6ec81a` changes only the supported platform floor and related active
configuration/documentation:

```swift
// Package.swift
platforms: [.macOS(.v15)]
```

```xml
<!-- resources/Info.plist -->
<key>LSMinimumSystemVersion</key><string>15.0</string>
```

```yaml
# .github/workflows/ci.yml
runs-on: macos-15
run: MACOSX_DEPLOYMENT_TARGET=15.0 swift build -c release
```

All eight hosted jobs are pinned to the `macos-15` image. Release proof in
`artifacts/r4/release-integrity.txt` records binary `minos 15.0`, SDK 15.5,
and plist minimum 15.0. No macOS 14/15-only API was adopted.

RESOLVED

## C2 — Documentation and artifact-name sweep

Tracked grep line count for the former floor patterns:

| Stage | Matching tracked lines |
|---|---:|
| Before sweep | 58 |
| After sweep and evidence refresh | 18 |

Every remaining line is intentionally historical:

- `artifacts/r4/revision-scope-proof.txt` lines 7 and 35: immutable diff proof
  showing the old deployment artifact being deleted/renamed.
- `docs/PROJECT_STATE.md` lines 42–55: the original frozen Option A wording and
  the verbatim owner-directed ADR revision; history must not be rewritten.
- `docs/adr/ADR-011-platform-support.md` lines 9–33: the original accepted ADR
  followed by its dated superseding revision.
- `docs/audits/pre-phase5-code-audit.md` lines 381 and 437: historical findings
  from the audited revision, explicitly identified as superseded nearby.
- `docs/phase-1/requirements-ledger.md` line 24: append-only superseded REQ-015;
  active REQ-017 records the new floor.

Active artifact names are `macos15-deployment-build.txt`,
`macos15-reliability-100x100.txt`, and `macos15-startup-p95.txt`. No active
operator command, package setting, plist value, workflow setting, project-state
row, or release document targets the former floor.

RESOLVED

## C3 — BLOCK-002 redefinition and evidence

`docs/PROJECT_STATE.md` records the owner decision verbatim and defines the
minimum-OS proof as both codec reliability and full-app startup on real macOS
15.x Apple Silicon hardware.

Both artifacts were produced in the same MacBookPro18,2/macOS 15.7.5 session
at `f6ec81a`:

| Artifact | Result |
|---|---|
| `artifacts/r4/macos15-reliability-100x100.txt` | 100 launches, 100 distinct PIDs, 10,000 round trips, zero crashes/nonzero exits/timeouts/corruption; 5 s aggregate wall clock |
| `artifacts/r4/macos15-startup-p95.txt` | 20 full-app launches; p50 142.652 ms, p95 152.286 ms, max 183.569 ms; p95 target 2,000 ms; PASS |

Both retain revision, model, chip, memory, OS version/build, architecture, Swift
toolchain, and policy metadata. BLOCK-002 is `CLOSED`.

RESOLVED

## C4 — BLOCK-011 complete rerun

The complete battery ran at exact revision
`f6ec81a88bee6a6b3055da850d08a6243061d090`. No later build-input change is
included in the evidence/state commit.

| Gate | Exact command | Observed result | Artifact |
|---|---|---|---|
| Debug build | `swift build -c debug` | PASS | `debug-build.txt` |
| Debug tests | `swift test` | 89/89, 2.419 s | `debug-tests.txt` |
| Release build | `swift build -c release` | PASS | `release-build.txt` |
| Release tests | `swift test -c release` | 89/89, 1.136 s | `release-tests.txt` |
| AddressSanitizer | `swift test --sanitize=address` | 89/89, 11.715 s | `asan-tests.txt` |
| Coverage | `swift test --enable-code-coverage`; `scripts/check-coverage.sh 55` | 87.93% ≥ 55% | `coverage-tests.txt`, `coverage-summary.txt` |
| Formatting | `xcrun swift-format lint --recursive --strict Sources Tests Package.swift` | PASS | `format.txt` |
| Dependency direction | `scripts/check-module-dependencies.sh` | PASS | `module-dependencies.txt` |
| Clean room | `scripts/check-clean-room.sh` | PASS | `clean-room.txt` |
| Minimum-target compile | `MACOSX_DEPLOYMENT_TARGET=15.0 swift build -c release` | PASS | `macos15-deployment-build.txt` |
| Symbol graph | `swift package dump-symbol-graph` plus emitted-file assertion | PASS | `symbol-graph.txt` |
| Adversarial corpus | `swift test --filter 'deterministicNativeAndSVG|fixedAdversarial'` | 2/2 PASS; seed remains `0xA110F00D` | `adversarial-tests.txt` |
| Golden rendering | `swift test --filter compositeSceneMatchesProjectGolden` | 1/1 PASS | `golden-test.txt` |
| UI/accessibility | `swift test --filter 'headlessUIJourney|accessibilityTreeExposes'` | 2/2 PASS | `ui-accessibility-tests.txt` |
| A6 named filter | Combined exact 19-method filter | 19/19 PASS | `a6-filtered-tests.txt`, `a6-test-existence.txt` |
| AUDIT-005/006 | Exact two-test filter | 2/2 PASS | `audit-005-006-filtered-tests.txt`, `audit-005-006-test-existence.txt` |
| Release assembly/signature | `scripts/build-release-app.sh`; `codesign -dvvv`; binary/plist minimum check | PASS; arm64, hardened-runtime ad-hoc signature, minos/plist 15.0 | `release-integrity.txt` |
| Startup | `scripts/check-startup-p95.sh 20 artifacts/r4/macos15-startup-p95.txt` | p50 142.652, p95 152.286, max 183.569 ms; PASS | `macos15-startup-p95.txt`, `startup-p95.txt` |
| Memory settle/export | `scripts/check-peak-memory.sh artifacts/r4/peak-memory.txt` | 214,548,480 / 524,288,000 bytes; 225,280,000 / 681,574,400 bytes; PASS | `peak-memory.txt` |
| Memory failure fixture | `scripts/test-peak-memory-gate.sh` | 790,740,992 > 524,288,000; expected nonzero gate failure; fixture PASS | `peak-memory-failure-fixture.txt` |
| Reliability | `scripts/nightly-reliability.sh artifacts/r4/macos15-reliability-100x100.txt` | 100 distinct PIDs, 10,000 cycles, zero failures; PASS | `macos15-reliability-100x100.txt`, `reliability-100x100.txt` |
| BENCH ratio | Exact-decimal comparison plus boundary/failure fixtures | Current ratios PASS; exact 1.25 PASS; 1.314801 FAIL as required | `benchmark-comparison.txt`, `benchmark-gate-fixtures.txt` |

### BENCH-R3.5 results

| Scenario | p50 | p95 | Max/settle | Frozen target | Result |
|---|---:|---:|---:|---:|---|
| BENCH-1 drag | 5.029 ms | 5.408 ms | 5.611 ms | p95 ≤ 16.7 ms | PASS |
| BENCH-2 pan | 0.087 ms | 0.107 ms | 0.133 ms | p95 ≤ 16.7 ms | PASS |
| BENCH-2b forced exposure | 5.415 ms | 5.815 ms | 6.161 ms | p95 ≤ 16.7 ms; nonzero strips every frame | PASS; 360/360 asserted |
| BENCH-3 zoom | 2.391 ms | 9.162 ms | 10.436 ms | p95 ≤ 33 ms | PASS |
| BENCH-3 settle | — | — | 2.776 ms | ≤ 100 ms | PASS |
| BENCH-4 cold open | — | — | 8.326 ms | Informational | RECORDED |
| Warm full redraw | — | — | 4.871 ms | Informational | RECORDED |

`artifacts/r4/revision-map.md` maps every retained artifact to `f6ec81a`.
`artifacts/r4/revision-scope-proof.txt` records the commit scope, ancestry,
runner pins, minimum-platform inputs, and zero changes under `Sources`, `Tests`,
or the frozen verification queue.

RESOLVED

## C5 — State and verdict

`docs/PROJECT_STATE.md` now records:

- BLOCK-002: `CLOSED` with both same-session minimum-OS artifacts;
- BLOCK-003/004/005: `OPEN — LOCAL PASS, HOSTED PENDING`;
- BLOCK-006: `OPEN` pending the first hosted four-job green run, hosted
  baseline bootstrap, comparison artifact, and run URL;
- BLOCK-012: `OPEN`; no Phase 5 tag exists.

Overall verdict remains **FAILED — PHASE 5 BLOCKED** until BLOCK-006 and the
hosted components close.

No pinned constant, VERIFY-001–021 entry, benchmark target, tolerance, memory
ceiling, startup target, ratio threshold, or expected value changed. Commit
scope proof reports zero changes under `Sources`, `Tests`, or
`docs/verification/VERIFICATION_QUEUE.md`.

RESOLVED
