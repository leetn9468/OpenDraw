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

Status after supersession: **Superseded for Phase 5 by OD-1–OD-4**. The
VERIFY-022–028 agreement round must finish before implementation begins.
