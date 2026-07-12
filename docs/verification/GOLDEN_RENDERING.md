# Golden rendering policy

The project-created 96×96 composite fixture covers dashed strokes, round caps,
bevel joins, miter configuration, linear gradients, opacity, transformed paths,
Core Text baseline placement, and mixed path/text/path z-order.

Comparison is performed on decoded premultiplied RGBA bytes. A channel delta up
to 3 is ignored; no observed channel may differ by more than 12; at most 1% of
pixels may exceed the ignored delta. These tolerances allow minor supported-OS
rasterization differences without accepting geometry, ordering, or color regressions.

Regeneration is explicit with `UPDATE_GOLDENS=1` and prints a base64 project
fixture for review. CI never regenerates a golden automatically.
