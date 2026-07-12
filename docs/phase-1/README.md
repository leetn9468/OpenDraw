# Phase 1 specification index

Status: **Complete, with explicit Phase 2 validation gates**  
Baseline date: 2026-07-12  
Requirements author: Project owner with Codex drafting support

## Deliverables

1. [Product requirements](product-requirements.md)
2. [Prioritized capability matrix](capability-matrix.md)
3. [Behavioral specification catalog](behavioral-specifications.md)
4. [Requirements and provenance ledger](requirements-ledger.md)
5. [Technology decision record](technology-decision-record.md)
6. [Initial risk register](risk-register.md)
7. [MVP acceptance-test outline](mvp-acceptance-tests.md)
8. [Clean-room and research policy](clean-room-policy.md)

## Phase 1 exit review

| Exit criterion | Result | Evidence |
|---|---|---|
| Every MVP capability has observable behavior and acceptance criteria | Pass | Behavior catalog and `AT-*` coverage map |
| Stack and supported platform selected | Pass, validation required | `TDR-001` through `TDR-008` |
| Clean-room rules recorded and acknowledged | Pass | Clean-room policy; acknowledgment below |
| Out-of-scope features explicit | Pass | Capability matrix |
| No production code depends on decompiler export | Pass | No production code exists; artifact excluded by policy |

## Decisions to reconfirm before Phase 2

- Product owner accepts macOS 13+ as the minimum deployment target.
- Intel support remains required for the MVP.
- The working product name will be replaced before public distribution.
- Swift/AppKit/Core Graphics proof-of-concepts meet the gates in `TDR-008`.

## Clean-room acknowledgment

By starting implementation work in this repository, a contributor acknowledges
that they have read `clean-room-policy.md`, will not use decompiled code as an
implementation source, and will report accidental exposure before continuing.
