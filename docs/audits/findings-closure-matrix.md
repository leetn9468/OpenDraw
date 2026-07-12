# Findings closure matrix

Re-audit date: 2026-07-13. Zero accepted-risk or open categories are permitted.

| Finding | Status | Fixing commits | Regression evidence | Verification |
|---|---|---|---|---|
| AUDIT-001 transformed bounds | Closed | `6ca6ce1`, `8e98346` | `VisualBoundsVerifyTests`, transformed-ink render test | VERIFY-004/005 |
| AUDIT-002 lossy SVG export | Closed | `b05a149` | deterministic SVG, structured-loss and gradient tests | VERIFY-010 |
| AUDIT-003 unbounded native load | Closed | `b05a149`, `65cfb1a` | bounded metadata/read, JSON/SVG structural boundary corpus | VERIFY-011 |
| AUDIT-004 incomplete validation | Closed | `8e98346`, `2f6d3d6` | strict validation and direct count/asset boundaries | VERIFY-007/008 |
| AUDIT-005 unsaved open loss | Closed | `f12920f` | independent coordinators and cancel/no-replacement tests | Frozen R3 behavior |
| AUDIT-006 unsafe drag coalescing | Closed | `f12920f` | failed-first-gesture and distinct-gesture tests | Frozen R3 behavior |
| AUDIT-007 mixed stacking impossible | Closed | `8e98346` | v4 mixed-order/group/compound round trip | VERIFY-005/009 |
| AUDIT-008 unsafe embedded images | Closed | `b05a149` | decode/cache/path traversal/placeholder tests | VERIFY-007/012 |

All eight audit findings are closed by committed implementation and permanent
tests. VERIFY-001 through VERIFY-021 are frozen and verified; no row is open.
