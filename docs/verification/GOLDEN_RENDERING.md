# Golden rendering policy

The project-created 96×96 composite fixture covers dashed strokes, round caps,
bevel joins, miter configuration, linear gradients, opacity, transformed paths,
Core Text baseline placement, and mixed path/text/path z-order.

Comparison is performed on decoded premultiplied RGBA bytes. A channel delta up
to 3 is ignored; no observed channel may differ by more than 12; at most 1% of
pixels may exceed the ignored delta. Integer flooring makes that an inclusive
maximum of 92 pixels for the 96×96 fixture; 93 fails. The channel maximum of 12
is also inclusive, and 13 fails. These tolerances allow minor supported-OS
rasterization differences while remaining sensitive to material geometry,
ordering, and color regressions. They do not prove that every subpixel or
color-managed difference will fail, because changes within the documented
channel/pixel budget can pass.

Regeneration is explicit with `UPDATE_GOLDENS=1` and prints a base64 project
fixture for review. CI never regenerates a golden automatically.

Permanent test file: `Tests/CanvasRenderTests/GoldenRenderingTests.swift`;
function: `compositeSceneMatchesProjectGoldenWithExplicitTolerance`. Final local command:
`swift test --filter 'compositeSceneMatchesProjectGolden|goldenToleranceBoundaryPolicyIsInclusive'`; raw output:
`artifacts/r4/golden-test.txt`. CI artifact/job group: `adversarial-golden`.
`goldenToleranceBoundaryPolicyIsInclusive` permanently pins the zero-difference
degenerate case, the 92/93 pixel boundary, and the 12/13 channel boundary.
