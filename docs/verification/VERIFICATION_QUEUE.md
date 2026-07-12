# Mathematical Verification Queue

Verified examples are frozen permanent assertions. A semantic change requires a new
queue entry; expected values below may not be weakened or edited to make code pass.

Convention: `AffineTransform(a,b,c,d,tx,ty)` maps
`(x,y)` to `(a*x+c*y+tx, b*x+d*y+ty)`.

## R1 verified entries

### VERIFY-001 — Affine transform apply, concatenation, and inverse

- Status: `VERIFIED`
- R-task: R1.1/R1.2
- Function/file: `Geometry.AffineTransform.applying(to:)`, `concatenating(_:)`, `inverted()`
- Commit: `6ca6ce1`
- Claim: concatenation applies the receiver first and the argument second. The
  algebraic inverse has linear part `(d,-b,-c,a)/det`, where `det=a*d-b*c`, and
  translation `(-tx*ia-ty*ic, -tx*ib-ty*id)`.
- Reasoning: affine maps are augmented 2×3 matrices. Composition is matrix
  multiplication in application order. The inverse follows from the 2×2 adjugate,
  with translation chosen so inverse(transform(point)) equals point.
- Worked examples:
  1. `(0,1,-1,0,0,0)` applied to `(2,3)` → `(-3,2)`.
  2. `scale(2,3).concatenating(translate(5,-1))` → `(2,0,0,3,5,-1)`;
     applied to `(1,1)` → `(7,2)`.
  3. Shear `(1,0,2,1,0,0)` maps `(3,4)` → `(11,4)`; inverse
     `(1,0,-2,1,0,0)` maps `(11,4)` → `(3,4)`.
  4. `(0,0,0,3,1,2)` has determinant zero and inversion fails explicitly.
- Tolerance: exact for integer cases; `1e-9` absolute for composed values.
  `|det| < 1e-12` is the library implementation policy for treating a transform
  as near-singular; this is distinct from the pure mathematical condition `det != 0`.
- Permanent test: `Tests/GeometryTests/AffineTransformVerifyTests.swift`

### VERIFY-002 — Cubic Bézier evaluation

- Status: `VERIFIED`
- R-task: R1.2
- Function/file: `Geometry.CubicBezier.point(at:)`
- Commit: `6ca6ce1`
- Claim: `B(t)=(1-t)^3 P0+3(1-t)^2t P1+3(1-t)t^2 P2+t^3 P3`.
- Reasoning: this is the cubic Bernstein basis; coefficients sum to one, preserving
  affine combinations and constant degenerate segments.
- Worked examples for `P0=(0,0), P1=(0,100), P2=(100,100), P3=(100,0)`:
  1. `t=0.5` → `(50,75)`.
  2. `t=0.25` → `(15.625,56.25)`.
  3. All points `(5,5)`, `t=0.7` → `(5,5)` exactly.
- Tolerance: `1e-9` absolute.
- Permanent test: `Tests/GeometryTests/BezierEvaluationVerifyTests.swift`

### VERIFY-003 — Cubic Bézier tight bounds

- Status: `VERIFIED`
- R-task: R1.2
- Function/file: `Geometry.CubicBezier.tightBounds`, `BezierPath.localBounds`
- Commit: `6ca6ce1`
- Claim: per-axis extrema are roots in `(0,1)` of `a*t^2+b*t+c=0`, with
  `a=3(-p0+3p1-3p2+p3)`, `b=6(p0-2p1+p2)`, `c=3(p1-p0)`; endpoints and extrema
  determine tight bounds. The `a≈0` linear branch uses `t=-c/b`.
- Reasoning: differentiating the cubic Bernstein form yields the quadratic. A
  continuous function on `[0,1]` reaches extrema at endpoints or stationary points.
- Worked examples:
  1. Arch from VERIFY-002: y derivative `(0,-600,300)`, root `0.5`, bounds
     `(0,0,100,75)`.
  2. Its x derivative `(-600,600,0)` has roots `0` and `1`, excluded from the
     open interior-root set.
  3. `(0,0),(-200,0),(300,0),(100,0)` has roots
     `0.1726731646` and `0.8273268354`; bounds
     `(-48.1980506062,0,148.1980506062,0)`.
- Tolerance: `1e-6` for printed irrational values; linear threshold `1e-12`.
- Permanent test: `Tests/GeometryTests/BezierBoundsVerifyTests.swift`

### VERIFY-004 — Path visual bounds

- Status: `VERIFIED`
- R-task: R1.2
- Function/file: `SceneNode.visualBounds` path case
- Commit: `8e98346`
- Claim: conservatively compute `expand(AABB(T*corners(localBounds)),e)`, where
  `e=(strokeWidth/2)*max(joinFactor,capFactor)`, miter `joinFactor=miterLimit`, other
  joins `1`, square-cap factor `sqrt(2)`, other caps `1`. Stroke expansion is in
  document space after transforming corners.
- Reasoning: transformed-corner AABB contains the affine image of the local bounds.
  Stroke extends half-width, bounded by the miter limit or square-cap diagonal.
- Worked examples:
  1. `(0,0,100,50)`, rotation 45°, width 10 round → transformed AABB
     `(-35.355339,0,70.710678,106.066017)`, visual
     `(-40.355339,-5,75.710678,111.066017)`.
  2. `(10,20,60,45)`, rotation 37° + translation `(12,-8)`, width 6, miter 4 →
     transformed AABB `(-7.09532094,13.99086043,47.88183014,64.04749934)`, visual
     `(-19.09532094,1.99086043,59.88183014,76.04749934)`.
  3. Width 4, miter limit 10 → expansion `20`.
  4. Point `(5,5)`, square cap, width 6 → expansion `4.2426406871`, visual
     `(0.7573593129,0.7573593129,9.2426406871,9.2426406871)`.
- Tolerance: `1e-6`; over-coverage allowed, under-coverage forbidden.
- Permanent test: `Tests/DocumentModelTests/VisualBoundsVerifyTests.swift`

### VERIFY-005 — Group visual bounds

- Status: `VERIFIED`
- R-task: R1.1
- Function/file: `SceneNode.visualBounds` group case
- Commit: `8e98346`
- Claim: `AABB(groupTransform*corners(union(child.visualBounds)))`.
- Reasoning: each child bounds contains child ink in group space; union contains all
  ink; affine mapping preserves containment; the transformed corner AABB is conservative.
- Worked examples:
  1. Union of VERIFY-004 example 1 and `(0,0,20,20)` remains
     `(-40.355339,-5,75.710678,111.066017)`.
  2. Rotation -30° + translation `(100,50)` →
     `(62.55125125,7.81453398,221.10037899,166.36366172)`.
  3. Empty group → `nil`; one child with identity → exact child bounds.
- Tolerance: `1e-6`.
- Permanent test: `Tests/DocumentModelTests/GroupBoundsVerifyTests.swift`

### VERIFY-006 — Compound-path fill containment

- Status: `VERIFIED`
- R-task: R1.1
- Function/file: `CompoundPath.contains(_:fillRule:)`
- Commit: `6ca6ce1`
- Claim: cast a +x ray; upward crossings contribute +1 and downward -1 using the
  half-open y rule. A crossing counts only when `xIntersection > px` (strict). No
  separate boundary-inclusion predicate exists. Non-zero is inside iff winding is
  nonzero; even-odd is inside iff crossing count is odd.
- Reasoning: half-open y comparisons count shared vertices once. Strict x comparison
  makes edge behavior deterministic. Interactive R3-B.1 hit-testing adds stroke
  distance tolerance, so boundary clicks can still select while pure fill remains strict.
- Worked examples for outer `(0,0)-(10,10)` and inner `(3,3)-(7,7)` squares:
  1. CCW+CCW at `(5,5)`: winding `2`, crossings `2` → nonZero inside,
     evenOdd outside.
  2. CCW+CW at `(5,5)`: winding `0` → both outside.
  3. `(1,5)`: winding `1`, crossings `3` → both inside.
  4. `(10,5)` on the outer right edge: winding `0`, crossings `0` → outside under
     both rules in both orientation configurations. `(12,5)` is likewise outside.
- Tolerance: exact for square fixtures; curve flattening tolerance `0.1` document units.
- Permanent test: `Tests/GeometryTests/FillRuleVerifyTests.swift`

### VERIFY-007 — Overflow-checked pixel count

- Status: `VERIFIED`
- R-task: R1.3
- Function/file: `DocumentLimits.checkedPixelCount(width:height:)`
- Commit: `8e98346`
- Claim: positive `Int64` dimensions multiply using `multipliedReportingOverflow`.
  Overflow and budget excess are distinct typed errors. Pixel budget is exactly
  `67_108_864` (`8192*8192=2^26`, approximately 256 MiB decoded RGBA).
- Reasoning: checked multiplication prevents integer wrap. Positivity is checked
  first. A successful product is then compared with the explicit resource budget.
- Worked examples:
  1. `4096*4096=16_777_216` → accepted.
  2. `3_037_000_499^2=9_223_372_030_926_249_001` → rejected as `budget`.
  3. `3_037_000_500^2=9_223_372_037_000_250_000` → rejected as `overflow`.
  4. Zero or negative dimensions → rejected as `nonPositive` before multiplication.
- Tolerance: exact integer arithmetic.
- Permanent test: `Tests/DocumentModelTests/PixelOverflowVerifyTests.swift`

## R0 checkpoint

R0 changed no mathematical or numerical functions and added no numeric entry.

## Entry template for VERIFY-008+

Each new entry must include status, R-task, function/file/commit, precise claim,
3–10 lines of reasoning, at least three numeric examples including a degenerate case,
tolerance rationale, and the permanent test file. New entries remain
`PENDING OWNER VERIFICATION` until the owner resolves the next checkpoint.

### VERIFY-008 — Document magnitude and collection ceilings

- Status: `VERIFIED`
- R-task: R1.3
- Function/file: `DocumentLimits`, `EditorDocument.validate()`
- Commit: `8e98346`
- Mathematical claim: all coordinates and affine components must be finite. Absolute
  coordinate magnitude is at most `1_000_000_000`; artboard width/height at most
  `1_000_000`; layers at most `1_024`; total recursive scene nodes at most `100_000`;
  total cubic segments at most `1_000_000`; each string at most `1_000_000` UTF-8
  bytes; each embedded asset at most `100 MiB`; aggregate embedded assets at most
  `500 MiB`. Aggregate byte addition uses `addingReportingOverflow`.
- Reasoning: finite magnitude bounds prevent non-finite geometry and unsafe numeric
  conversions. Count ceilings bound traversal and decoding work. Byte ceilings cap
  per-resource and total snapshot pressure. Checked addition prevents an aggregate
  byte count from wrapping and incorrectly passing its budget.
- Worked examples:
  1. Coordinate `999_999_999.5`, artboard `(640,480)`, 1 layer/1 node → accepted.
  2. Coordinate `1_000_000_001` → rejected as `coordinateMagnitude`; artboard width
     `1_000_001` → rejected as `artboardMagnitude`.
  3. `100_000` nodes → accepted; `100_001` → rejected as `nodeCount`.
  4. Five embedded assets of exactly `100 MiB` → aggregate `500 MiB`, accepted;
     adding one byte → rejected as `aggregateAssetBytes`; checked-add overflow is
     rejected as `assetByteOverflow`.
- Epsilon/tolerance: exact integer limits; floating comparisons are inclusive (`<=`)
  with no epsilon because these are safety budgets rather than geometric equality.
- Permanent test: `Tests/DocumentModelTests/DocumentLimitsVerifyTests.swift`

### VERIFY-009 — Nested-node document delta to parent-local delta

- Status: `VERIFIED`
- R-task: R1.2 alignment
- Function/file: `EditorDocument.translateNode(id:documentDelta:)`
- Commit: `8e98346`
- Mathematical claim: for a node whose ancestor chain applies transforms `T1`
  (outermost) through `Tn` (immediate parent), `L` is the linear part of the
  accumulated mapping `T1 ∘ ... ∘ Tn` (apply innermost first). A desired
  document-space translation `d` becomes node-parent-local `q=L^-1*d`; translation
  terms are excluded because vectors have homogeneous coordinate zero. If accumulated
  `L` is singular under the VERIFY-001 `1e-12` policy, translation fails without mutation.
- Reasoning: a child-local position maps through its parent as `L*p+t`. Adding local
  vector `q` changes the mapped point by `L*q`. Solving `L*q=d` gives `q=L^-1*d`.
  Parent translation cancels when subtracting old and new positions.
- Worked examples:
  1. Identity parent, document delta `(8,-3)` → local delta `(8,-3)`.
  2. Scale parent `(2,0,0,4,10,20)`, document delta `(10,8)` → local `(5,2)`.
  3. 90° rotation parent `(0,1,-1,0,0,0)`, document delta `(10,0)` → local `(0,-10)`.
  4. Singular parent `(0,0,0,1,0,0)` → explicit failure and no mutation.
  5. Outer rotation 90° and inner scale `(2,4)` accumulate to
     `L=(0,2,-4,0)`. Document delta `(10,6)` → local `(3,-2.5)`; round-trip
     `L*(3,-2.5)=(10,6)` exactly.
- Tolerance: `1e-9` absolute for transformed vectors; singularity `1e-12` per VERIFY-001.
- Permanent test: `Tests/DocumentModelTests/NestedTranslationVerifyTests.swift`

# Independent Cross-Verification — Claude

> Verifier: **Claude**  
> Verification date: 2026-07-12  
> Scope: independently recomputed VERIFY-008 and VERIFY-009 against commit
> `8e98346`; all calculations were executed numerically.

## Claude result summary

| Entry | Resolution | Result |
|---|---|---|
| VERIFY-008 | `VERIFIED` | Ceiling arithmetic, boundaries, and overflow behavior agree; direct boundary fixtures added in `2f6d3d6`. |
| VERIFY-009 | `VERIFIED` after precision amendment | Examples 1–4 agree; accumulated-ancestor definition and example 5 pin multi-level nesting. |

## VERIFY-008 calculation

1. `100 MiB=104,857,600`; five assets total `524,288,000=500 MiB` and are
   accepted inclusively; `524,288,001` is rejected as `aggregateAssetBytes`.
2. `999,999,999.5` is exactly representable near `1e9` and is within the inclusive
   coordinate ceiling.
3. `1,000,000,001` and artboard `1,000,001` exceed their respective ceilings.
4. Recursive count `100,000` is accepted and `100,001` is rejected as `nodeCount`.
   Checked aggregate addition rejects overflow before budget comparison.
5. Pixel and encoded-byte budgets are independent: `2^26` bounds decoded pixels;
   100 MiB bounds one encoded asset.

## VERIFY-009 calculation

1. Identity maps delta `(8,-3)` to `(8,-3)`.
2. Scale `(2,4)` maps document `(10,8)` back to local `(5,2)`.
3. Rotation 90° maps document `(10,0)` back to local `(0,-10)`.
4. Singular `(0,0,0,1)` fails without mutation under the `1e-12` policy.
5. Outer rotation 90° after inner scale `(2,4)` has accumulated linear part
   `(0,2,-4,0)`; inverse mapping of `(10,6)` is `(3,-2.5)`, and the forward
   round-trip returns `(10,6)` exactly.
