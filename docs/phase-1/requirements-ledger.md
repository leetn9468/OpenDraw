# Requirements and provenance ledger

Allowed source categories are `User Requirement`, `Original Product Decision`,
`Public Specification`, and `Approved Black-Box Observation`. The last category
requires a separate approved observation record. Decompiled implementation is not
an allowed source.

| Requirement ID | Description | Source category | Source/reference | Date | Author | Test status |
|---|---|---|---|---|---|---|
| REQ-001 | Create a sized one-artboard document | Original Product Decision | PRD MVP boundary | 2026-07-12 | Project/Codex | Specified AT-001 |
| REQ-002 | Select objects and path components | Original Product Decision | CAP-003/004 | 2026-07-12 | Project/Codex | Specified AT-003/004 |
| REQ-003 | Create/edit cubic Bézier paths | User Requirement | Phase 1 plan capability list | 2026-07-12 | Project/Codex | Specified AT-005 |
| REQ-004 | Create rectangle, ellipse, and line | Original Product Decision | CAP-006 | 2026-07-12 | Project/Codex | Specified AT-006 |
| REQ-005 | Apply solid sRGB fill/stroke | Original Product Decision | CAP-007/014 | 2026-07-12 | Project/Codex | Specified AT-007/013 |
| REQ-006 | Transform and align objects | User Requirement | Phase 1 plan capability list | 2026-07-12 | Project/Codex | Specified AT-008/009 |
| REQ-007 | Layers, ordering, grouping | User Requirement | Phase 1 plan capability list | 2026-07-12 | Project/Codex | Specified AT-010/011 |
| REQ-008 | Undo every MVP mutation | User Requirement | Project-wide engineering rule | 2026-07-12 | Project/Codex | Specified AT-012 |
| REQ-009 | Plain text and raster placement | Original Product Decision | CAP-017/018 | 2026-07-12 | Project/Codex | Specified AT-014/015 |
| REQ-010 | Versioned original native format | Original Product Decision | CAP-019 | 2026-07-12 | Project/Codex | Specified AT-016 |
| REQ-011 | Safe documented SVG subset | Public Specification | W3C SVG 1.1, https://www.w3.org/TR/SVG11/ | 2026-07-12 | Project/Codex | Specified AT-017 |
| REQ-012 | PNG export | Public Specification | W3C PNG, https://www.w3.org/TR/png/ | 2026-07-12 | Project/Codex | Specified AT-018 |
| REQ-013 | Clipboard interoperability | Original Product Decision | CAP-022 | 2026-07-12 | Project/Codex | Specified AT-019 |
| REQ-014 | macOS accessibility support | Public Specification | Apple Accessibility documentation | 2026-07-12 | Project/Codex | Specified AT-020 |
| REQ-015 | macOS 13+, arm64 only | User Requirement | ADR-011 original decision | 2026-07-12 | Project owner | Superseded 2026-07-13 by REQ-017 |
| REQ-016 | No decompiler-derived production code | User Requirement | Clean-room plan §2.1 | 2026-07-12 | Project/Codex | Policy review |
| REQ-017 | macOS 15+, arm64 only | User Requirement | ADR-011 revision | 2026-07-13 | Project owner | Accepted |

## New-entry template

| Requirement ID | Description | Source category | Source/reference | Date | Author | Test status |
|---|---|---|---|---|---|---|
| REQ-NNN | | | | YYYY-MM-DD | | Not specified |

Changes must be append-only or preserve review history in version control. A
requirement becomes implementation-ready only after it has a source, observable
behavior, and acceptance mapping.
