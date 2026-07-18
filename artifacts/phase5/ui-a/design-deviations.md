# U3-A design-deviation log

Design of record: `/Users/user/Documents/OpenDraw Redesign.html` plus the U3-A directive dated 2026-07-18.

| Item | Resolution | Rationale |
|---|---|---|
| FIX-0 Dash inventory mismatch | `EXISTS`; row included, read-only and model-faithful | `PathStyle.dash` is Codable, validated, rendered through `CGContext.setLineDash`, and exported as SVG `stroke-dasharray`. U3-A adds no dash capability. |
| C1 smooth-handle note | Directive correction accepted | The shell adds no conflicting copy. Frozen VERIFY-017 remains the authority: `H_out = 2A - H_in`, mirroring angle and length. |
| C2 rotation copy | **OPEN — owner reconciliation required** | The directive says 22.5° is frozen VERIFY-013, but the checked-in frozen queue, production `snappedRotation`, and permanent tests all specify 15° (`pi/12`). U3-A changes neither frozen math nor canvas interaction and introduces no snap-increment copy. |
| C3 `icon.rest` | Directive correction accepted | Dark is `#FFFFFF` at 75%; light is `#000000` at 70%, chosen as directed for secondary-control contrast. |
| Rail icon mapping | Directive overrides HTML mapping | The directive explicitly requires the seven rail glyphs to use the accepted SVG path data. All seven `d` strings are retained verbatim beside their `NSBezierPath` transcriptions, even where the HTML's `sfMap` suggests an SF Symbol. |
| Export label | Existing capability retained | The accepted mockup calls the command “Export PNG,” but the engine exposes SVG export only. The toolbar says “Export” and the menu says “Export SVG…”; PNG export was not invented under the ADD NOTHING rule. |
| Arrange z-order row | Omitted in U3-A | The HTML hero sketches Bring/Send controls, while S4's U3-A inventory names Group/Ungroup/Compound/Release and the align family. No additional arrange behavior was added. |
| AppKit rail composition | Structural implementation detail | The `.sidebar` `NSVisualEffectView` is the rail background inside an explicitly constrained 44-pt host view; explicit constraints are required so AppKit does not visually occlude the narrow rail when mixed with the canvas and two fixed right panels. Metrics and appearance are unchanged. |

