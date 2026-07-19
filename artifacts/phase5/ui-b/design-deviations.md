# U3-B design-deviation delta

Design basis: accepted U3-A shell, design 1f/D3.2, and the 2026-07-18 U3-B
directive.

| Item | Resolution | Rationale |
|---|---|---|
| U3-A C2 rotation copy | `CLOSED — directive erratum` | Repository authority is unchanged: increment `pi/12` (15 degrees); `pi/8` (22.5 degrees) is the pinned half-away tie input. No frozen value changed. |
| Selection chrome values | `EXACT` | Required colors, sizes, strokes, offsets, alpha, radius, and SF Mono 10.5 badge font are Theme tokens and linted. |
| Anchor hit target | `UNCHANGED` | The visual is 7 points; the existing 6-point interaction radius remains authoritative. Transform and rotation radii also remain 7 and 8 points. |
| Canonical render goldens | `OUTSIDE CHROME SCOPE` | AppKit overlays are not part of document-pixel rendering; the canonical golden files remained byte-identical. |
| Benchmark impact | `NONE BY CONSTRUCTION` | Benchmark executable is headless and has no dependency on `VectorFoundryApp`, `CanvasView`, or Theme chrome. |
| In-place text field | `MODEL-FAITHFUL` | Current text objects are point text. The replacement is a single in-place AppKit field and does not invent multiline/area-text capability. |

No new design deviation was introduced in U3-B. The only delta from U3-A is
closure of C2 under the directive's explicit erratum.
