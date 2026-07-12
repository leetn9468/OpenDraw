# Native schema version 3 and migration

Version 3 adds optional document swatches/gradients, optional per-layer text/images,
and optional path appearance links, opacity and blend mode. Optional encoding lets
old v2 fields retain their original meaning.

Load procedure:

1. Enforce the byte limit and parse only the root version probe.
2. Reject versions below 2 or above the current version.
3. For v2, rewrite only `formatVersion` in an isolated JSON object; all new optional
   fields decode as absent/default behavior.
4. Decode and validate the complete candidate.
5. Return it only after invariants pass; the live document is untouched on failure.

The migration test creates project data with the v2 shape, loads it through the v3
codec, and verifies layers plus current version. Future versions should use explicit
typed migration steps rather than an accumulating conditional decoder.
