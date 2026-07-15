# VERIFY-022–028 Codex agreement review

Review date: 2026-07-15

Reviewed tree: `afb6f80`

Scope: independent arithmetic, v4-schema enumeration, existing frozen-test
compatibility, and history-cost attribution. No implementation was performed.

## Batch verdict

**RESOLVED — FROZEN 2026-07-15.** The original review below identified two
disputes. The author accepted both at `dc08b58` and supplied AMEND-1–6; Codex
independently checked and agreed with all six. The authoritative incorporated
text is in `VERIFICATION_QUEUE.md`. The original review is retained below as
the audit trail rather than rewritten.

## VERIFY-022 — AGREE

The concrete v4 volatile set is **`V = ∅`**.

`EditorDocument` persists exactly these top-level fields:
`formatVersion`, `width`, `height`, `unit`, `layers`, `swatches`, and
`gradients`. Recursively persisted fields describe IDs, names, visibility/
locking, scene order and nesting, geometry, transforms, styles, text, image
storage/dimensions, swatches, and gradients. The actual v4 schema contains no
wall-clock, session, viewport, or cache field. `ObjectID.rawValue` is persistent
document identity rather than a session identifier. Therefore no concrete
field meets the volatile criterion.

Consequences for the examples:

1. “Every field in V differs” is vacuous because V is empty; equal canonical
   documents remain byte-equal.
2. A last-significant-digit coordinate change changes sorted-key native JSON
   bytes, so equality fails with no epsilon.
3. The empty document's two encode passes around decode are byte-identical.

Existing proof: `nativeRoundTripIsDeterministic` and
`v4CanonicalGoldenBytes` in
`Tests/DocumentFormatsTests/DocumentFormatsTests.swift`.

## VERIFY-023 — AGREE

- `T(10,20) ∘ S(2,2) ∘ T(3,4)` maps the origin to `(16,28)`.
- Replacing the node transform with `T(5,-1)` maps it to `(20,18)`.
- `S(2,3) ∘ R90` maps `(1,0)` to `(0,3)`; replacing `R90` with identity maps
  it to `(2,0)`.
- Assigning the stored old transform restores exact stored components; no
  inverse matrix is needed.

P-IDENT adds no conflict with an existing frozen assertion: no existing test
requires a bitwise-identity edit to create history or clear redo. It must use
payload bit patterns/canonical bytes, not ordinary floating-point `==`, so
`-0.0` and `+0.0` are not silently conflated.

## VERIFY-024 — AGREE

- Removing index 1 from `[A,B,C]` gives `[A,C]`; reinsertion at 1 restores
  `[A,B,C]` and the stored payload.
- A pinned 3 MB asset remains byte-identical; equal SHA-256 follows from equal
  bytes.
- Empty groups are already valid: `GroupBoundsVerifyTests.swift` asserts an
  empty group's children are empty and its visual bounds are `nil`, while
  `EditorDocument.validate()` imposes no nonempty-child invariant.

P-EMPTYGROUP therefore conflicts with no existing frozen behavior.
`snapshotHistorySharesEmbeddedAssetsAndHonorsMemorySafetyNet` also confirms the
existing expectation that immutable embedded `Data` storage is shared rather
than duplicated.

## VERIFY-025 — AGREE

For `G = T(5,0) ∘ S(2,2)`:

- `G ∘ T(1,1)` maps child 1 point `(1,0)` to `(9,2)`.
- `G ∘ R90` maps child 2 point `(1,0)` to `(5,2)`.
- `G ∘ S(1/2,1/2)` maps child 3 point `(1,0)` to `(6,0)`.
- Child 1's local origin maps to `(7,2)`.

Reversing command order while inverting each command is the required LIFO
inverse. The one-command composite reduces to its one inverse exactly.

## VERIFY-026 — DISPUTE (scope precision; arithmetic agrees)

The arithmetic is correct:

- `2(100,100) - (90,95) = (110,105)`.
- Translating all present values by `(20,10)` gives anchor `(120,110)`, incoming
  `(110,105)`, and outgoing `(130,115)`.
- `2(120,110) - (110,105) = (130,115)`.

The literal P-ENDPOINT wording is broader than the current model. Public
`PenAnchor` in `Sources/EditorTools/CreationTools.swift` stores nonoptional
`incoming` and `outgoing` points and normalizes a supplied `nil` to the anchor
point. In contrast, an open `CubicBezier` chain structurally has no incoming
side at the first endpoint and no outgoing side at the last endpoint.

Required scope amendment before agreement:

> **P-ENDPOINT applies to the runtime history slice derived from document-path
> topology, not to `PenAnchor` tool-construction state or the v4 serialized
> schema. In that slice, the absent endpoint side is `nil` and is restored as
> `nil`; it is never synthesized as a zero-length or mirrored handle.**

With this scope, VERIFY-017's smooth mirror test remains unchanged and applies
only when both sides are present.

## VERIFY-027 — DISPUTE

Recomputed values:

1. Commands 6–205 are 200 entries and 200,000 bytes. The head state is after
   command 5. Recovering state after command 17 applies commands 6–17: 12
   applies. Exhaustive residue checking for K=25 gives a worst case of 24.
2. `150 × 100,000 + 60,000,000 = 75,000,000`; excess over B is 7,891,136.
   `ceil(7,891,136 / 100,000) = 79`; retained count is `151-79=72`, retained
   bytes are `67,100,000`, and headroom is 8,864 bytes.
3. `70,000,000 + 9 × 1,000 = 70,009,000`, which is 2,900,136 bytes over B.

The example 3 sentence “All older entries evicted; the M=10 floor retains all
ten” is self-contradictory. The described history starts with exactly ten
entries. P-FLOOR prevents any eviction. Required replacement:

> **No entry is evicted because the history is already at M=10; all ten remain,
> and Σ=70,009,000>B is permitted under P-FLOOR.**

### E-027 cost attribution — correction required

Counting an asset once against its oldest pin is sound only with these explicit
rules:

1. `costInBytes` is the structural command payload excluding asset buffers that
   are counted separately; otherwise embedded bytes are double-counted.
2. An asset is charged once to its **oldest retained pinning entry**.
3. If that entry is evicted while a later retained pin still exists, the charge
   transfers atomically to the next-oldest retained pin before Σ is
   re-evaluated. Without transfer, retained history undercounts live pinned
   bytes.
4. The specification must say whether checkpoint structural payloads and assets
   pinned only by a checkpoint count inside B. The supplied agreement material
   references spec §4 but does not provide this accounting boundary.

The global counter should also be stated to increment once per recorded command
commit; P-IDENT edits, cancelled gestures, undo, and redo do not increment it.

P-FLOOR intentionally supersedes ADR-012's old 30-entry/5-floor policy and the
current `minimumHistoryEntriesUnderMemoryPressure = 5`; this is an explicit OD-1
supersession, not an accidental compatibility claim.

## VERIFY-028 — AGREE

- `C1 C2 C3 U U` gives `[1] | [3,2]`; committing 4 gives `[1,4] | []`.
- `U U` gives `[] | [4,1]`; `R R` restores `[1,4] | []`.
- A cancelled gesture after undo leaves `[1] | [2]`; redo restores
  `[1,2] | []`.

P-REDOCLEAR agrees with `commandUndoRedoAndBranch`: a successfully committed
branch clears redo. It also agrees with the failure-before-commit behavior in
`failedFirstGestureDoesNotCorruptLaterCoalescing` and
`historyDirtyCoalescingRollbackAndLimit`: validation failure does not mutate
the accepted document/history. The new permanent test must pin redo preservation
for an explicit cancelled gesture.

## Five-policy compatibility summary

| Policy | Result against current frozen behavior/tests |
|---|---|
| P-IDENT | Compatible; no existing test requires no-op recording or redo clearing. |
| P-EMPTYGROUP | Compatible; empty groups are already valid and tested. |
| P-FLOOR | Intentional OD-1 supersession of the old 5-entry floor; old capacity tests must be superseded, not weakened silently. |
| P-REDOCLEAR | Compatible with committed-branch clearing and failed-command rollback tests. |
| P-ENDPOINT | Needs the history-slice scope amendment above; literal broad wording conflicts with nonoptional `PenAnchor`. |

## Final amendment resolution

### AMEND-1 — AGREE

The topology-derived runtime-history-slice scope resolves the original
P-ENDPOINT conflict. It leaves public `PenAnchor`, schema v4, and VERIFY-017
unchanged; nil restoration applies only to the new slice representation.

### AMEND-2 — AGREE

At exactly M=10, P-FLOOR permits no eviction. The retained sum is
`70,000,000 + 9×1,000 = 70,009,000`, exceeding `67,108,864` by `2,900,136`.

### AMEND-3 — AGREE

Structural command payload and pinned buffers are separated; an asset is
charged once and atomically reattributed if its oldest retained pin is evicted.
The checkpoint boundary is now decided. The ceiling recomputes as
`ceil(200/25)+1 = 8+1 = 9`. The unchanged 500 MiB peak-memory gate is the
acceptance proof for live state, worst-case floor history, and nine checkpoints.
The counter increments only for a recorded command commit.

### AMEND-4 — AGREE

Canonical payload-byte identity is precise and makes signed zero observable.
A direct Swift `JSONEncoder` check produced `{"x":-0}` for `-0.0` and
`{"x":0}` for `+0.0`, confirming distinct canonical bytes.

### AMEND-5 — AGREE

`V = ∅` follows from the inspected v4 schema. The vacuous first example is
retained as a mandatory amendment trigger if a future schema adds a volatile
field.

### AMEND-6 — AGREE

The supersession set explicitly includes
`historyLimitIsImmutableAndCappedAtThirty`,
`minimumHistoryEntriesUnderMemoryPressure = 5` and its pinning assertions, and
the ADR-012 capacity rows. These must be superseded row by row during
implementation.

## Freeze result

VERIFY-022 through VERIFY-028 are frozen. No implementation was performed in
this agreement round; Sources and Tests remain unchanged. The Phase 5 P1
implementation directive may now proceed.
