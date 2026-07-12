# Clean-room and research policy

## Boundary

Production requirements come only from user requirements, public specifications,
approved black-box behavioral observations, and original product decisions.
Implementation must use original names, architecture, code, assets, messages, and
tests. Similar user-visible functionality does not authorize copying expression or
internal structure.

The restricted artifact `/Users/user/Desktop/AI10/AI10.c`:

- remains outside this repository;
- is not a build, generation, test, or documentation input;
- must not be copied, translated, summarized into implementation instructions, or
  used to infer private constants, layouts, algorithms, names, or control flow;
- may not be viewed by an implementation task. Any future research team must be
  separately authorized and may report only observable, implementation-neutral
  behavior through reviewed observation records.

Public documentation and standards should be linked in the provenance ledger.
Screenshots, fixtures, fonts, icons, sample documents, and other assets require an
explicit permission/license record before repository storage. No proprietary UI
text or visual asset should be replicated.

## Approved observation record

An authorized black-box record must include:

- observer, date, lawful test environment, and source category;
- setup, user input, externally visible output, and repeatability;
- no implementation guess, decompiled identifier, address, private constant, or
  copied creative expression;
- reviewer approval and mapped requirement/test IDs.

## Accidental-exposure procedure

1. Stop the affected implementation work immediately; do not paste or further
   distribute the material.
2. Record only the date, people/tasks involved, affected new files/requirements,
   and the category of exposure—do not commit proprietary contents.
3. Notify the project owner and quarantine affected original work without deleting
   evidence needed for review.
4. The owner determines whether to discard and independently re-create affected
   work, reassign it to an unexposed contributor, or obtain legal advice.
5. Resume only after a written disposition is committed to a neutral incident log.

## Contribution check

Every implementation change should be reviewable against these questions:

- Is each behavior mapped to a permitted provenance entry?
- Are code, names, algorithms, tests, messages, and assets independently authored?
- Does the change introduce any legacy artifact or proprietary-format assumption?
- Are all dependencies and assets licensed and recorded?

This policy governs engineering practice and is not legal advice.
