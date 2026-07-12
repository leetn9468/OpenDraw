# Historical schema version 3 and migration to version 4

Version 3 added optional resources and three separate per-layer object arrays. The R1
remediation supersedes it with version 4 ordered heterogeneous scene nodes, recursive
groups, and compound paths. The frozen v4 schema is documented in
`docs/formats/opendraw-v4-schema.md`.

Load procedure:

1. Enforce the byte limit and parse only the root version probe.
2. Reject versions below 2 or above the current version.
3. Decode v2 into a typed v2 representation, migrate to typed v3, then migrate v3
   into v4. The v3 visible order—paths, images, text—is preserved deterministically.
4. Decode and validate the complete v4 candidate.
5. Return it only after invariants pass; the live document is untouched on failure.

Checked-in v2 and v3 project-created fixtures migrate, validate, save as v4, and
reopen identically. Future versions must add explicit typed migration steps.
