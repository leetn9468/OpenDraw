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
