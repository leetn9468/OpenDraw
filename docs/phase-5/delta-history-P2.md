# Phase 5 delta history P2

Status: historically implemented behind the existing default-off runtime
gate. Snapshot `CommandHistory` remained the primary application path; P2
performed no capacity or behavior supersession. P4 later retired both.

## Structural commands

`StructuralCommands` provides create-shape, create-text, create-image, paste,
insert-layer, delete, cut, node move/reorder, and layer reorder commands. Each
command captures immutable old/new payload data at record time. Forward and
inverse operations have atomic preflights before the accepted document is
touched. Inserts validate the new payload in isolation, scan the already-valid
history document for additive node/segment/asset/ID ceilings, and prove the
position on a candidate. Removal and reorder prove their exact positions on a
candidate; because they only remove or relocate already-valid payload, they
cannot increase any frozen ceiling.

Insert inverses remove by stable object ID. Remove commands retain the exact
parent, child index, complete node payload, and asset references. Multi-delete
is one history command: removal is deepest-first and descending by index inside
one parent; reinsertion is the exact reverse of that removal order. Deleting a
group's last child does not remove the group. Move and reorder commands capture
both parent/index positions; canonical payload equality elides a same-position
move without clearing redo or incrementing the global counter.

## Approved asset store and real pins

`ApprovedAssetStore` is the shared content-addressed immutable byte store in
`DocumentModel`, below both document-format approval and history. SHA-256 is the
asset identity. `ApprovedImageCache` publishes bytes to this store only after
the existing decoder approval succeeds. Structural factories require embedded
bytes to already exist in the supplied approved store; an unapproved embedded
insert is rejected without document, history, or store mutation.

History commands carry approved-store pins separately from structural
`costInBytes`. The history replaces its complete history/checkpoint pin sets in
one store critical section. An asset is charged once in B to its oldest
retained command; when that command leaves while a later pin remains, the store
pin and the B charge both transfer without an observable unpinned interval.
When the last command and checkpoint pin leave, pressure eviction may remove
the bytes. Checkpoint-only bytes remain outside B and are deduplicated in the
store; the nine-checkpoint ceiling still binds.

The memory safety-net operation drops periodic checkpoints while preserving the
head checkpoint, every retained M-floor entry, and those entries' real pins.
The renderer's independent `maximumRetainedBitmapPixels` constant and the
unchanged 500 MiB settle envelope are not reused or altered.

## Permanent proof and corpus

`DeltaHistoryP2VerifyTests.swift` pins all three VERIFY-024 examples, structural
limit rejection, create/paste round trips, reverse-order multi-delete,
cross-parent/node/layer reorder, P-IDENT redo preservation, real-pin charge
transfer and release, checkpoint-only accounting, and safety-net pin survival.
The permanent 3 MiB fixture checks the content-addressed SHA-256 before and
after undo and proves structural cost plus one asset charge has no byte double
counting.

The same frozen seed `0x00000000A110F00D` drives a mixed value-swap,
structural-insert/remove, and reorder corpus. A 40-command balanced prefix is
then evicted by 200 retained mixed commands, so the test crosses count eviction
and checkpoint creation while retaining an exact initial-state head. Every
retained undo and redo step is compared using VERIFY-022 canonical equality;
failures emit the standing `CORPUS_FAILURE` seed/index/phase record.

## BENCH-5 and gates

BENCH-5 keeps its frozen targets, sample discipline, labels, artifact format,
and local/hosted policies. P2 changes the measured operations, not the gate:
BENCH-5a alternates structural delete undo/redo on the fixed 1,000-object scene,
and BENCH-5b alternates structural delete/insert construction plus commit under
sustained eviction/checkpointing. Targets remain p95 <= 16.7 ms and p95 <=
1.0 ms respectively.
