# Phase 5 delta history P1

Status: implemented behind a default-off runtime flag. The snapshot history
remains the production path.

## Isolation flag

The single flag is the environment variable `OPENDRAW_DELTA_HISTORY`.
`DeltaHistoryFeatureFlag.environment()` enables the new container only when its
value is exactly `1`; absence, `0`, and every other value are OFF. The app does
not select `DeltaCommandHistory` in P1. The release benchmark sets the flag to
`1` explicitly for BENCH-5. Existing `CommandHistory`, its 30-entry limit, and
its five-entry memory-pressure floor are unchanged until P4.

## P1 command surface

`DocumentCommand` now carries `commandID`, `timestamp`, `damageBounds`,
structural `costInBytes`, and optional pinned-asset metadata. Reversible
commands capture both stored-value assignments at record time; `inverted()`
switches direction over that captured pair and performs no mathematical
inversion. `apply(to:)` is atomic:

- arbitrary and legacy closures mutate and validate a candidate document before
  assignment;
- the closed P1 value-swap classes preflight the exact affected payload and
  target, then perform a nonthrowing stored-value assignment.

The P1 factories cover node transform, path style, node property, text content,
layer visibility/lock, and artboard properties. Canonical sorted-key JSON bytes
implement VERIFY-022 equality and P-IDENT. Signed zero remains observable.

## Container and checkpoints

`DeltaCommandHistory` freezes N=200, B=67,108,864 bytes, M=10, and K=25.
Redo clears only after a nonidentity command reaches commit. The global counter
increments exactly once at that boundary. Identity elision and gesture
cancellation leave the counter and redo untouched.

The byte budget is structural command payload plus each distinct pinned asset
once. The charge belongs to the oldest retained pin and is recalculated before
the budget is tested after every eviction, atomically transferring it to the
next-oldest pin. P-FLOOR stops byte eviction at ten commands even when the sum
still exceeds B.

The container retains a head snapshot and periodic snapshots at global counter
multiples of 25. Checkpoint payload and checkpoint-only assets are outside B;
copy-on-write `EditorDocument`/`Data` storage reuses the existing shared
immutable asset behavior. Stale branch checkpoints are discarded, checkpoints
at or behind the head are folded into it, and the total is capped at nine.

The peak-memory harness retains two concurrent Phase 5 envelopes while it runs
the unchanged settle/export gates: a ten-command P-FLOOR history containing a
real 70,000,000-byte pinned buffer (Σ=70,009,000), and a 200-command history
with all nine checkpoints. This deliberately conservative construction makes
both frozen worst cases resident alongside the live representative document.

## Failure containment

Undo or redo first attempts the stored command direction. On failure it records
a `DeltaHistoryDiagnostic`, restores the nearest lineage-compatible checkpoint,
and replays captured forward commands. The forced inverse-failure permanent test
proves recovery, diagnostic fields, stack transition, and later redo.

## BENCH-5

Both scenarios use the fixed 1,000-object BENCH-1 document, release code, a
60-frame warm-up, and 300 measured operations:

| Scenario | Measurement | Frozen absolute target |
|---|---|---:|
| BENCH-5a | Alternating delta undo/redo apply | p95 <= 16.7 ms |
| BENCH-5b | Value-swap construction plus commit under sustained history eviction/checkpointing | p95 <= 1.0 ms |

Local ratios remain blocking against the owner-reference baseline at the
unchanged inclusive 1.25 threshold. Hosted absolute targets are blocking;
hosted ratios remain informational. If the committed hosted reference lacks
BENCH-5, the first hosted run emits 1.0 bootstrap rows and a seven-row candidate
whose two added metrics carry their own run/commit provenance.
