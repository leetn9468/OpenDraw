# Initial risk register

Scale: likelihood and impact are `Low`, `Medium`, or `High`.

| ID | Risk | Likelihood | Impact | Mitigation / trigger | Owner |
|---|---|---|---|---|---|
| R-001 | Clean-room contamination from `AI10.c` | Medium | High | Keep outside repo; implementation contributors do not inspect it; follow exposure procedure | Project owner |
| R-002 | Scope expands toward full legacy parity | High | High | Capability matrix is normative; additions need value, dependencies, tests, performance budget | Product owner |
| R-003 | AppKit/Core Graphics misses frame target | Medium | High | TDR-004 spike before broad UI; profile representative document; superseding TDR if needed | Rendering lead |
| R-004 | Complex-script text fidelity fails | Medium | High | TDR-005 corpus and round-trip spike; keep MVP text deliberately plain | Text lead |
| R-005 | Intel behavior diverges or CI unavailable | Closed | Closed | Intel permanently out of scope per ADR-011 | Project owner |
| R-006 | Native schema becomes brittle | Medium | High | Stable IDs, versioned schema, canonical fixtures, migrations, unknown-field policy | Format lead |
| R-007 | SVG silently loses unsupported content | Medium | High | Explicit subset, structured warnings, hostile fixtures, visual golden tests | Format lead |
| R-008 | Malformed import causes resource exhaustion | Medium | High | Byte/object/depth/pixel limits; no network/entity/script execution; fuzzing | Security owner |
| R-009 | Undo misses a mutation or corrupts state | Medium | High | Single command boundary, invariant/property tests, transaction coalescing rules | Model lead |
| R-010 | Accessibility added too late | Medium | High | AppKit spike includes VoiceOver/keyboard; accessibility acceptance in each vertical slice | UI lead |
| R-011 | Dependency license conflict | Low | High | No dependency without ledger entry and license review | Project owner |
| R-012 | Working name creates trademark confusion | Medium | Medium | Select an original public name; state no affiliation/compatibility claim | Product owner |
| R-013 | Data loss during save/export | Low | High | Atomic save, fault injection, backups/recovery post-MVP, destination-preservation tests | Format lead |
| R-014 | Performance metric hardware is ambiguous | High | Medium | Nominate baseline Apple Silicon hardware in remediation R4 | Release lead |

Review at each phase boundary and whenever a trigger occurs. Closed risks remain in
the ledger with resolution evidence rather than being deleted.
