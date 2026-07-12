# Mathematical Verification Queue

The project owner independently verifies each queued mathematical or numerical claim
with multiple AI systems. Codex must stop at every R-task checkpoint until every new
entry is marked `VERIFIED` or returned with a correction.

## Status values

- `PENDING OWNER VERIFICATION`
- `VERIFIED`
- `CORRECTION REQUIRED`

## R0 checkpoint

R0 changes product identity, platform scope, repository policy, and architecture
records only. No mathematical, geometry, numerical, tolerance, conversion, sizing,
or overflow formula was written or modified, so R0 adds no numeric verification
entry.

## Entry template

### VERIFY-NNN — Function name

- Status: `PENDING OWNER VERIFICATION`
- R-task:
- Function/file:
- Commit: populated after the task commit
- Mathematical claim:
- Derivation/reasoning (3–10 lines):
- Worked examples (at least three, including one edge/degenerate case):
  1. Inputs → expected output
  2. Inputs → expected output
  3. Inputs → expected output
- Epsilon/tolerance and rationale:
- Permanent test assertion:
