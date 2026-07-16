# ADR-012 — Bounded snapshot history

- Status: Accepted
- Date: 2026-07-12
- Decision owner: Project owner

## Decision

OpenDraw will retain snapshot-based undo/redo for the current stage with an immutable
hard cap of 30 undo entries. A separate estimated-memory ceiling must evict old
entries while preserving at least five entries. Embedded assets must use demonstrably
shared immutable storage so snapshots do not duplicate asset bytes.

Delta or inverse-command history is deferred until after Phase 5 and is not part of
the current remediation.

## Consequences

- R1 makes the count limit immutable; R3 implements the 30-entry and memory limits.
- Tests must pin eviction behavior and verify that large asset storage is shared.
- The accepted design bounds current complexity while keeping observable undo/redo
  semantics stable.

## Supersession — 2026-07-15

The original decision above is retained as history. The following owner
decisions supersede its capacity and snapshot-history direction for Phase 5:

> **2026-07-15 — OD-1 (supersedes ADR-2 capacity):** history capacity is
> N = 200 commands AND B = 64 MiB (67,108,864 bytes, Σ costInBytes incl.
> history-pinned assets), minimum retained M = 10, checkpoint interval K = 25
> (global monotone command counter). ADR-2's 30/5 snapshot constants are
> superseded; the ADR text is appended, not rewritten.
> **OD-2:** hybrid checkpointing per spec §4 (snapshot every K commands and
> always at history head after eviction).
> **OD-3:** history remains runtime-only; document schema v4 unchanged.
> **OD-4:** ADR-2 supersession rationale: "the snapshot cap was a memory-cost
> ceiling, not a UX target; command-inverse history achieves deeper undo
> within a smaller budget."

Status after supersession: **Superseded for Phase 5 by OD-1–OD-4**.
VERIFY-022–028 completed two-AI agreement and froze on 2026-07-15. Phase 5
implementation must apply the recorded row-by-row supersessions; this ADR's
historical text remains intact.

## Retirement execution — 2026-07-16

P4 executed the supersession. Delta command history is now the sole
application undo/redo owner with N=200, B=67,108,864 bytes, M=10, and K=25.
The former feature gate, snapshot undo container, 30-entry cap, and five-entry
pressure floor were removed. Snapshot storage was not deleted wholesale:
`DeltaCommandHistory` retains document snapshots for the history-head and
periodic checkpoints, and those checkpoints continue to share immutable
embedded assets through `ApprovedAssetStore`. The complete row-by-row
successor table is in `docs/verification/VERIFICATION_QUEUE.md` and
`docs/phase-5/delta-history-P4.md`.
