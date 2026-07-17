# Mathematical Verification Queue

Verified examples are frozen permanent assertions. A semantic change requires a new
queue entry; expected values below may not be weakened or edited to make code pass.

Process violation record: VERIFY-019 math shipped in `8ed6d00` before queueing;
queued in `5f95bd6` and remediated on 2026-07-12 in `95fd622`.

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
>
> Verification date: 2026-07-12
>
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

### VERIFY-010 — SVG absolute-unit conversion

- Status: `VERIFIED`
- R-task: R2.3
- Function/file: `SVGLengthParser.parse(_:)`
- Commit: `b05a149`
- Mathematical claim: OpenDraw's SVG import coordinate unit is one CSS pixel at
  96 pixels per inch. Absolute conversions are `px=1`, `in=96`, `cm=96/2.54`,
  `mm=96/25.4`, `pt=96/72`, and `pc=16`. Unit matching is case-insensitive.
- Reasoning: SVG/CSS defines 96 CSS pixels per inch. Centimeters and millimeters
  divide the inch conversion by 2.54 and 25.4. A point is 1/72 inch and a pica is
  12 points, hence 16 CSS pixels.
- Worked examples:
  1. `1in` → `96`; `2.54cm` → `96`; `25.4mm` → `96`.
  2. `72pt` → `96`; `6pc` → `96`; `10PX` → `10`.
  3. Bare `12.5` → `12.5`; `0mm` → `0`.
  4. Percent, `em`, unknown suffix, NaN, and infinity → typed unsupported/invalid result.
- Tolerance: `1e-9` absolute for decimal conversions; exact for px/pc examples.
- Permanent test: `Tests/DocumentFormatsTests/SVGLengthVerifyTests.swift`

### VERIFY-011 — External-input structural ceilings

- Status: `VERIFIED`
- R-task: R2.1/R2.3
- Function/file: `InputLimits`, `JSONStructureValidator`, `SVGImporter.Delegate`
- Commit: `b05a149`, resolution `65cfb1a`
- Mathematical claim: native file bytes are capped at `100 MiB`; SVG at `10 MiB`;
  JSON nesting at `128`, total values at `1,000,000`; SVG nesting at `256`, elements
  at `100,000`, produced nodes at `100,000`, warnings at `1,000`, and every XML
  XML string at `1,000,000` UTF-8 bytes, including element names, attribute names
  and values, and accumulated character data per element. Comparisons are inclusive.
- Reasoning: byte limits match existing format budgets. Structural limits bound parser
  traversal independently of bytes. The root consumes one element, so the importer
  can produce at most `99,999` nodes—deliberately below VERIFY-008's `100,000`-node
  document ceiling. Inclusive checks accept exactly the documented capacity and
  reject the next unit.
- Worked examples:
  1. JSON depth `128` accepted; `129` rejected as `nestingDepth`.
  2. `1,000,000` JSON values accepted; `1,000,001` rejected as `valueCount`.
  3. One root plus `99,999` producing children is `100,000` elements and produces
     `99,999` nodes → accepted; another child is element `100,001` → `elementCount`.
  4. Exactly `1,000` warnings accepted; the `1,001`st aborts as `warningCount`.
  5. Accumulated character data of `1,000,000` UTF-8 bytes in one text element is
     accepted at the parser layer; `1,000,001` bytes rejects as `stringLength`.
- Tolerance: exact integer comparisons, no epsilon.
- Permanent test: `Tests/DocumentFormatsTests/InputLimitsVerifyTests.swift`

### VERIFY-012 — Approved image-cache pixel budget and autosave interval

- Status: `VERIFIED`
- R-task: R2.2/R2.6
- Function/file: `ApprovedImageCache`, `RecoverySettings`
- Commit: `b05a149`
- Mathematical claim: one image remains bounded by VERIFY-007's `67,108,864`
  pixels; the approved decoded cache permits at most `268,435,456` pixels (`4*2^26`,
  exactly 1 GiB at four bytes/pixel), and one image source permits at most 32
  frames. Checked addition rejects overflow before the budget comparison. Default
  autosave interval is exactly 60 seconds and must be strictly positive.
- Reasoning: the cache budget is exactly 4× VERIFY-007's per-image cap, so at most
  four maximum-sized decoded images fit; at four bytes per pixel it is exactly 1 GiB.
  Checked addition prevents wrapped cache accounting. The 60-second default is fixed
  by the owner directive; positive validation prevents a busy-loop timer.
- Worked examples:
  1. Four images of `67,108,864` pixels total `268,435,456` → accepted.
  2. That total plus one pixel → rejected as `totalPixelBudget`.
  3. `Int64.max + 1` → rejected as `overflow`, never budget-tested.
  4. Autosave `60` seconds → accepted; `0` and `-1` → rejected as `nonPositive`.
  5. Image source with 32 frames → accepted; 33 frames → rejected as `frameCount`.
- Tolerance: exact integer pixel arithmetic; exact Foundation `TimeInterval` (`Double`)
  value `60.0`, with validation requiring a finite value greater than zero.
- Permanent tests: `Tests/DocumentFormatsTests/ApprovedImageCacheVerifyTests.swift`,
  `Tests/DocumentFormatsTests/DurablePersistenceTests.swift`

## Independent Cross-Verification — Claude (VERIFY-010/011/012)

> Verifier: **Claude**
>
> Verification date: 2026-07-12
>
> Scope: every worked example independently recomputed against commit `b05a149`.

### Result summary

| Entry | Result |
|---|---|
| VERIFY-010 | `VERIFIED`; conversions and typed invalid/unsupported split confirmed. |
| VERIFY-011 | Numeric ceilings confirmed; element example amended and XML string enforcement extended. |
| VERIFY-012 | `VERIFIED`; numerics confirmed, with documentation corrections adopted. |

For VERIFY-010, `1in`, `2.54cm`, `25.4mm`, `72pt`, and `6pc` recompute to
`96.0`; `10PX`, bare values, and zero-unit behavior agree. The `1e-9` tolerance
remains because the exact round trips are input-specific.

For VERIFY-011, the root-element count makes the original combined
100,000-element/100,000-node example unrealizable. The frozen element ceiling
remains `100,000`; one root plus 99,999 producing children is accepted and the
next child rejects. The parser now applies the `1,000,000`-byte ceiling to every
XML string category, including accumulated character data and element names.
Direct fixtures pin element/node, warning, depth, attribute, and character-data
boundaries.

For VERIFY-012, `4 × 67,108,864 = 268,435,456` pixels exactly, which is exactly
four maximal images and exactly 1 GiB at four bytes per pixel. Checked overflow,
32/33 frames, and finite positive `TimeInterval` validation at `60.0`, `0`, and
`-1` all recompute as specified.

### VERIFY-013 — Rotation about a pivot and 15-degree snapping

- Status: `VERIFIED`
- R-task: R3-B.3
- Function/file: `TransformInteractions.rotation`, `snappedRotation`
- Mathematical claim: rotation uses `q = p + R(theta)(x-p)`, equivalently linear
  part `R(theta)` and translation `p-R(theta)p` under VERIFY-001. Constrained
  angles use `round(theta/(pi/12))*(pi/12)`, half away from zero.
- Worked examples: `(10,20)` pivot and `(15,20)` at 90° gives `(10,25)` and affine
  `(0,1,-1,0,30,10)`; the pivot at `1.234` is fixed; zero is identity; `±0.27`
  snap to `±pi/12`; the exactly reachable tie `pi/8` snaps to `pi/6`; pivot
  `(3,-4)`, point `(7.5,2.25)`, 37° gives `(2.8325159005,3.6996395420)`.
- Tolerance: `1e-9` absolute.
- Permanent test: `Tests/EditorToolsTests/EditorToolsTests.swift`

### VERIFY-014 — Zoom about a fixed screen point

- Status: `VERIFIED`
- R-task: R3-B.4
- Function/file: `TransformInteractions.zoomAbout`
- Mathematical claim: for finite positive old/new zoom, document point
  `(s-pan)/zoom` remains invariant by choosing `newPan=s-documentPoint*newZoom`;
  invalid zoom returns `nil`. UI requests clamp to `minZoom=0.05` and `maxZoom=64`.
- Worked examples: base `1→2` gives `(-80,-40)`; inverse `2→0.5` gives `(55,50)`;
  identity leaves pan `(10,20)`; the dyadic fractional case gives
  `(-42.625,-46.375)` exactly; zero, negative, infinity and NaN return `nil`.
- Tolerance: exact for the integer-valued example; `1e-9` generally.
- Permanent test: `Tests/EditorToolsTests/EditorToolsTests.swift`

## VERIFY-013/014 Consolidated Resolution — Claude + Codex

Two independent computations agree on every frozen value. Both identified and
closed the prior worked-example template gap. VERIFY-013 pins Swift's
round-half-away-from-zero tie behavior and the VERIFY-001 affine equivalence.
VERIFY-014 pins the finite-positive domain, named UI clamps, inverse/identity/
fractional cases, and invalid-input behavior. Both entries are `VERIFIED` and
the frozen-value rule now covers VERIFY-001 through VERIFY-014.

### VERIFY-015 — Damage rectangle union and intersection

- Status: `VERIFIED`
- R-task: R3.5
- Claim: union uses componentwise extrema; intersection uses componentwise inner
  extrema and returns `nil` when either resulting dimension is negative. Zero
  dimensions are retained (`>=`): touching damage rectangles merge like overlaps.
- Examples: union of `(0,0)-(10,10)` and `(5,-2)-(12,8)` is
  `(0,-2)-(12,10)`; intersection is `(5,0)-(10,8)`; disjoint rectangles return nil;
  touching at x=10 retains `(10,0)-(10,10)`.
- Tolerance: exact. Permanent test: `Tests/GeometryTests/GeometryTests.swift`.

### VERIFY-016 — Eight-handle scale mapping

- Status: `VERIFIED`
- R-task: R3-B.3
- Claim: in y-down document space, min-edge handles use `s=1-d/size`, max-edge
  handles use `s=1+d/size`, corners combine axes, and the other axis stays 1.
  The caller applies factors about the opposite anchor; Option fixes the center and
  doubles displacement; Shift uses the smaller magnitude with signs preserved.
- Examples: right handle on a 100×50 box dragged +50 gives `(sx,sy)=(1.5,1)`;
  Option gives `(2,1)`; Shift bottom-right `(50,50)` gives `(1.5,1.5)`. All eight
  handles, opposite-anchor integration, negative mirror scaling, and zero dimensions
  are pinned in the permanent test.
- Tolerance: `1e-9`. Permanent test: `Tests/EditorToolsTests/EditorToolsTests.swift`.

### VERIFY-017 — Smooth-anchor handle symmetry

- Status: `VERIFIED`
- R-task: R3-B.2
- Claim: for anchor `a` and outgoing handle `h`, the mirrored incoming handle is
  `2a-h`, preserving collinearity and equal opposite distance.
- Examples: `a=(10,20), h=(14,26)` gives `(6,14)`; `h=a` remains at `a`;
  negative-coordinate case `a=(-2,3), h=(-5,-1)` gives `(1,7)`.
- Tolerance: exact. Permanent test: `Tests/EditorToolsTests/EditorToolsTests.swift`.

### VERIFY-018 — Screen-space snapping tolerance

- Status: `VERIFIED`
- R-task: R3-B.3
- Claim: a document-space candidate snaps iff Euclidean distance is at most
  `screenTolerance/zoom`; equality is inclusive and invalid zoom never snaps.
- Examples: tolerance 6 at zoom 2 accepts distance 3 and rejects 3.000001;
  at zoom 0.5 accepts distance 12; zoom 0/negative rejects; NaN, infinity, and
  negative distance reject at valid zoom.
- Tolerance: `1e-9` at the boundary. Permanent test:
  `Tests/EditorToolsTests/EditorToolsTests.swift`.

## Independent Cross-Verification — Claude (VERIFY-015/016/017/018)

All values were independently recomputed against `9fdd523`. The resolution
pins touching-rectangle retention, the complete y-down eight-handle table and
opposite-anchor integration, negative and degenerate scale cases, the smooth-
handle vector identity, and non-finite/negative snapping distances. Protocol
compliance was confirmed: all four mathematical surfaces were queued before
reliance. VERIFY-015 through VERIFY-018 are `VERIFIED`; frozen values now cover
VERIFY-001 through VERIFY-018.

### VERIFY-019 — Document delta to path-local anchor delta

- Status: `VERIFIED`
- R-task: R3-B.2
- Function/file: `EditorDocument.movePathAnchor(id:subpath:segment:documentDelta:)`
- Mathematical claim: for anchor geometry stored in node-local space, `L` is
  the accumulated linear mapping `ancestors ∘ nodeTransform`; document drag
  `d` becomes local delta `q=L⁻¹d`. Translation is excluded. A singular mapping
  fails without mutation under VERIFY-001's `1e-12` policy.
- Worked examples:
  1. Identity maps `(8,-3)` to `(8,-3)`.
  2. Own 90° rotation inside group scale `(2,4)` gives `L=(0,4,-2,0)`;
     document delta `(10,8)` maps to local `(2,-5)`, round-tripping to `(10,8)`.
  3. Singular own transform `(0,0,0,1)` fails without mutation.
  4. Contrast: for own rot90 inside parent scale `(2,4)`, document delta `(10,8)`
     gives `translateNode` parent-local `(5,2)` under VERIFY-009, but anchor-local
     `(2,-5)` under VERIFY-019.
- Tolerance: `1e-9` absolute.
- Permanent test: `Tests/DocumentModelTests/DirectAnchorVerifyTests.swift`.

### VERIFY-020 — Document-space transform applied to a nested node

- Status: `VERIFIED`
- Implementation commit: `d85ae4b`
- R-task: R3-B.3
- Function/file: `EditorDocument.applyDocumentTransform(id:transform:)`
- Mathematical claim: with accumulated ancestor mapping `P`, node transform `N`,
  and desired document transform `D`, the replacement node transform is
  `N' = P⁻¹ ∘ D ∘ P ∘ N`; singular `P` fails without mutation.
- Worked examples:
  1. Identity parent gives `N'=D∘N`.
  2. Parent scale `(2,4)`, document translation `(10,8)`, identity node gives
     node-local translation `(5,2)`, reproducing document displacement `(10,8)`.
  3. Singular parent fails without mutation.
- Tolerance: `1e-9` absolute.
- Permanent test: `Tests/DocumentModelTests/DocumentTransformVerifyTests.swift`.

### VERIFY-021 — Axis snap candidate selection

- Status: `VERIFIED`
- Implementation commit: `72bd44d`
- R-task: R3-B.3
- Function/file: `SnapPolicy.snap(_:xCandidates:yCandidates:zoom:)`
- Mathematical claim: each axis independently chooses the nearest candidate whose
  absolute axis distance is at most `screenTolerance/zoom`; ties choose the first
  candidate in stable input order. Invalid zoom returns the original point.
- Worked examples: point `(9,21)`, candidates x `[0,10]`, y `[20,30]`, tolerance
  6 at zoom 1 gives `(10,20)`; x distance exactly 3 at zoom 2 snaps; 3.000001
  does not; equal-distance candidates preserve input order.
- Tolerance: exact for examples, `1e-9` boundary policy.
- Permanent test: `Tests/EditorToolsTests/EditorToolsTests.swift`.

## Independent Cross-Verification — VERIFY-020/021

Owner verification confirmed on 2026-07-13:

- VERIFY-020: under the project convention that `A.concatenating(B)` applies
  A then B, `parent.concatenating(D).concatenating(parent.inverted())`
  represents `P⁻¹∘D∘P`; composing it after the existing node transform gives
  `N'=P⁻¹∘D∘P∘N`. Identity, scaled-parent `(10,8)→(5,2)`, and singular
  no-mutation examples all agree with `d85ae4b` and its permanent tests.
- VERIFY-021: independent-axis nearest-candidate selection, inclusive
  `distance <= screenTolerance/zoom`, strict-best stable tie ordering, and
  invalid-zoom passthrough all agree with `72bd44d`. The `1e-9` value is a test
  assertion tolerance only and does not enlarge the snapping region.

R4-close scope: VERIFY-001 through VERIFY-021 were frozen with no open R4
entries. The current authoritative frozen range is stated below.

## Phase 5 agreement batch — VERIFY-022 through VERIFY-028

Pre-authored by Claude on 2026-07-15, independently reviewed by Codex against
tree `afb6f80`, and amended by the author after the review recorded at
`dc08b58`. Detailed recomputation, resolution, and schema/test citations:
`docs/verification/VERIFY-022-028-agreement-review.md`.

Batch status: **FROZEN — TWO-AI AGREEMENT RECORDED 2026-07-15;
IMPLEMENTATION COMPLETE IN P4 ON 2026-07-16**. Frozen values and policies
cover VERIFY-001 through VERIFY-028.

### VERIFY-022 — Canonical document equality

- Status: `FROZEN`
- Claim: equality is byte equality of sorted-key native v4 JSON after excluding
  the concrete volatile set, with no floating epsilon.
- E-022: the actual v4 schema has no wall-clock, session, viewport, or cache
  fields; therefore **`V = ∅`**. Top-level persisted fields are
  `formatVersion`, `width`, `height`, `unit`, `layers`, `swatches`, and
  `gradients`; all recursive fields are document identity, structure,
  geometry, style, text, or asset state.
- Recomputed examples: V-only difference is vacuous; a final-significant-digit
  coordinate change changes bytes; empty encode→decode→encode is byte-identical.
- The vacuous V-only example is a required guard: if a future schema adds a
  wall-clock, session, viewport, or cache field, VERIFY-022 must be amended
  before reliance. Adding such a field without amendment is a protocol
  violation.
- Existing proof: `nativeRoundTripIsDeterministic`, `v4CanonicalGoldenBytes`.
- P1 permanent proof: `testVerify022CanonicalDocumentEqualityFrozenExamples`
  in `DeltaHistoryP1VerifyTests.swift`.

### VERIFY-023 — Value-swap transform round trip

- Status: `FROZEN`
- Claim: store `(nodeID,N_old,N_new)`, assign values directly, and invert by
  swapping stored values; bitwise identity edits are not recorded.
- Recomputed examples: `T(10,20)∘S(2,2)∘T(3,4)` maps origin to `(16,28)`;
  replacing the node transform by `T(5,-1)` gives `(20,18)`; `S(2,3)∘R90`
  maps `(1,0)` to `(0,3)`, while identity gives `(2,0)`.
- P-IDENT has no conflicting frozen test. Identity is decided on canonical
  payload bytes/bit patterns rather than floating-point `==`; `-0.0` and
  `+0.0` are distinct. Identity edits create no history entry and do not clear
  redo.
- P1 permanent proof:
  `testVerify023ValueSwapTransformFrozenExamplesAndSignedZeroIdentity`.

### VERIFY-024 — Structural remove/reinsert

- Status: `FROZEN`
- Claim: delete stores parent, exact index, full payload, and pinned assets;
  inverse reinserts exactly and preserves asset bytes/content hash.
- Recomputed examples: `[A,B,C]→[A,C]→[A,B,C]`; equal pinned bytes imply equal
  SHA-256; deleting a sole child leaves an empty group and inverse restores
  index 0.
- P-EMPTYGROUP agrees with `GroupBoundsVerifyTests.swift` and current document
  validation, both of which permit empty groups.
- P2 permanent proof:
  `testVerify024ABCExactIndexAndPayloadRestoration`,
  `testVerify024ThreeMiBAssetSurvivesPressurePinnedAndSHA256RoundTrip`, and
  `testVerify024EmptyGroupPersistsAndInverseRestoresIndexZero` in
  `Tests/DocumentModelTests/DeltaHistoryP2VerifyTests.swift`. Supporting P2
  proofs pin one-command multi-delete reversal, real-pin transfer/release,
  checkpoint-only accounting, structural limits, reorder identity, and the
  mixed seeded corpus. These references add implementation evidence only; the
  frozen claim and values above are unchanged.

### VERIFY-025 — Composite reversal

- Status: `FROZEN`
- Claim: `inverse(Composite[c1…cn]) = Composite[inverse(cn)…inverse(c1)]`.
- Recomputed examples for `G=T(5,0)∘S(2,2)`: child points map to `(9,2)`,
  `(5,2)`, and `(6,0)`; child 1 origin maps to `(7,2)`. Reverse-order inverse
  restores the original document; the single-command case reduces directly.
- P3 implementation-semantics addendum — **P-COMPOSITE-ATOMIC**: children
  apply in order. If child `i` throws, children `1...i-1` are unwound by their
  captured inverses in reverse order and the composite records nothing. If an
  unwind throws, checkpoint restore plus a structured delta-history diagnostic
  engages. Composite cost is child structural-cost sum plus framing; damage is
  the child-damage union; an all-identity child list is identity-elided. This
  owner-authored 2026-07-16 directive and the passing clean-rollback and
  forced-containment fixtures constitute the required two-AI agreement.
- P3 permanent proof:
  `testVerify025UngroupCompositeFrozenExamplesAndReverseRestoration` and
  `testVerify025SingleChildCompositeInverseReducesDirectly` in
  `Tests/DocumentModelTests/DeltaHistoryP3VerifyTests.swift`. Supporting P3
  proofs cover group/ungroup and make/release-compound canonical round trips,
  align-as-one-command, damage/cost aggregation, both atomic failure branches,
  identity elision, and the seeded mixed corpus. These references and the
  implementation-semantics addendum do not alter any frozen numeric value.

### VERIFY-026 — Anchor-geometry slice swap

- Status: `FROZEN`
- Claim: an anchor gesture swaps the affected `{A,H_in,H_out}` pre/post slice
  verbatim; the inverse assigns the stored pre-state without reconstruction.
- P-ENDPOINT applies to the runtime history slice derived from document-path
  topology, not to `PenAnchor` tool-construction state or the v4 serialized
  schema. In that slice, the absent endpoint side is `nil` and is restored as
  `nil`; it is never synthesized as a zero-length or mirrored handle.
  VERIFY-017's mirror identity remains unchanged and applies only when both
  sides are present.
- Recomputed examples: mirror `(110,105)`; translated triple `(120,110)`,
  `(110,105)`, `(130,115)`; mirror check returns `(130,115)`. A corner edit
  leaves the other handle bitwise unchanged; an open-path endpoint inverse
  restores the absent side as `nil`.
- P3 permanent proof:
  `testVerify026SmoothAnchorSliceFrozenTripleAndExactInverse`,
  `testVerify026CornerUntouchedHandleIsBitwiseStable`, and
  `testVerify026OpenEndpointNilIsRestoredNotSynthesized` in
  `Tests/DocumentModelTests/DeltaHistoryP3VerifyTests.swift`. Supporting P3
  proofs cover structural control-point slices, real transform/anchor gesture
  coalescing, cancelled-gesture redo preservation, failed-first-gesture
  isolation, and the seeded mixed corpus. Values above remain untouched.

### VERIFY-027 — Budget arithmetic and checkpoints

- Status: `FROZEN`
- Example 1 agrees: retain commands 6–205, 200,000 bytes; replay 6–17 is 12
  applies; exhaustive K=25 residue bound is 24.
- Example 2 agrees: initial 75,000,000; excess 7,891,136; evict 79; retain 72
  commands and 67,100,000 bytes with 8,864-byte headroom.
- Example 3: one 70,000,000-byte command with nine prior 1,000-byte commands
  is already at M=10, so no entry is evicted. All ten remain; Σ=70,009,000,
  which exceeds B by 2,900,136 bytes and is permitted under P-FLOOR.
- `costInBytes` is structural command payload only. Pinned asset buffers are
  counted separately in Σ, so asset bytes are not double-counted.
- Each history-pinned asset is charged once to its oldest retained pinning
  entry. If that entry is evicted while a later retained pin exists, its charge
  transfers atomically to the next-oldest retained pin before Σ is
  re-evaluated; live pinned bytes are never undercounted.
- Checkpoint structural payloads and assets pinned only by checkpoints are
  outside B. Checkpoints are limited to `ceil(N/K)+1 = ceil(200/25)+1 = 9`,
  with asset bytes deduplicated through existing shared immutable storage.
  The total envelope—live document + B + checkpoints—is governed by the
  unchanged 500 MiB peak-memory gate, whose Phase 5 scenario must include
  worst-case P-FLOOR history plus nine checkpoints.
- The global monotone command counter increments exactly once per recorded
  command commit. P-IDENT elisions, cancelled gestures, undo, and redo do not
  increment it.
- P1 permanent proof:
  `testVerify027CountEvictionAndReplayBoundFrozenExample`,
  `testVerify027ByteEvictionFrozenExample`,
  `testVerify027FloorOutranksByteBudgetFrozenExample`, and
  `testVerify027PinnedAssetChargeTransfersAtomicallyToNextOldestPin`.

### VERIFY-028 — Redo branch state machine

- Status: `FROZEN`
- Recomputed stacks: `C1 C2 C3 U U → [1]|[3,2]`; `C4 → [1,4]|[]`;
  `U U → []|[4,1]`; `R R → [1,4]|[]`; cancelled gesture after undo leaves
  `[1]|[2]`, and redo gives `[1,2]|[]`.
- P-REDOCLEAR agreed with the historical `commandUndoRedoAndBranch` behavior
  and existing failed-command rollback semantics. P4 retires that snapshot
  test in favor of the permanent delta proof below plus the real-gesture P3
  proofs.
- P1 permanent proof:
  `testVerify028RedoBranchAndCancelledGestureFrozenStateMachine`.

### P-policy compatibility result

- P-IDENT: compatible; no frozen test requires no-op recording.
- P-EMPTYGROUP: compatible and already structurally supported.
- P-FLOOR: intentional OD-1 supersession of the old 5-entry floor; old capacity
  assertions must be superseded explicitly rather than weakened.
- P-REDOCLEAR: compatible with committed-branch and failure rollback semantics.
- P-ENDPOINT: compatible under the frozen history-slice scope; VERIFY-017 and
  `PenAnchor` behavior remain unchanged.

### P4 executed supersessions — 2026-07-16

Every removed production surface and deleted snapshot-path test is accounted
for below. No frozen value was edited.

| Removed/replaced item | Disposition | Successor evidence |
|---|---|---|
| Snapshot `CommandHistory` application undo/redo owner | Removed | `DeltaCommandHistory`; production wiring in `VectorFoundryApp/main.swift`; `headlessUIJourneyCreateStyleTransformSaveReopenAndExport`; `accessibilityTreeExposesDocumentLayersSelectionAndFrames` |
| Legacy non-reversible `DocumentCommand(name:mutation:)` | Removed | Captured-inverse value-swap, structural, composite, resource, and anchor command factories; P1–P3 permanent suites |
| `historyLimitIsImmutableAndCappedAtThirty` | Deleted | `testVerify027CountEvictionAndReplayBoundFrozenExample`; OD-1 N=200/B=67,108,864/M=10/K=25 assertions |
| `minimumHistoryEntriesUnderMemoryPressure = 5` and old pressure assertions | Removed | `testVerify027FloorOutranksByteBudgetFrozenExample`; `testP2SafetyNetDropsPeriodicCheckpointsButPreservesFloorPins` |
| `commandUndoRedoAndBranch` | Deleted | `testVerify028RedoBranchAndCancelledGestureFrozenStateMachine` |
| `historyDirtyCoalescingRollbackAndLimit` | Deleted; responsibilities split | `deltaRevisionDirtyAndChangeStreamSemantics`; `testP3RealGestureCoalescingCommitsOneCommandAndCancelPreservesRedo`; VERIFY-027 capacity proofs |
| `revisionGestureAndChangeStreamSemantics` | Migrated/renamed | `deltaRevisionDirtyAndChangeStreamSemantics` |
| `failedFirstGestureDoesNotCorruptLaterCoalescing` | Deleted | `testP3AnchorGestureCoalescesAndFailedFirstGestureDoesNotCorruptLaterCoalescing` |
| `alignmentIsUndoable` | Deleted | `testP3AlignmentIsOneCompositeAndUndoableOnDeltaPath` |
| `directAnchorGroupUngroupAndCompoundCommandsAreUndoable` | Deleted | `testP3GroupUngroupAndCompoundRoundTripsRestoreCanonicalDocument`; `groupUngroupAndCompoundReleasePreserveVisualBounds`; `directAnchorDeletionIsUndoable`; `directionHandleMovementUsesDocumentDeltaAndIsUndoable` |
| `snapshotHistorySharesEmbeddedAssetsAndHonorsMemorySafetyNet` | Retained semantics, migrated to checkpoint owner | `checkpointHistorySharesEmbeddedAssetsAndHonorsMemorySafetyNet`; `testP2SafetyNetDropsPeriodicCheckpointsButPreservesFloorPins`; checkpoint snapshots and `ApprovedAssetStore` remain shared machinery |
| P1 default-off feature-gate test | Deleted because the gate itself no longer exists | Single unconditional 122-test population plus zero-reference grep across production, tests, scripts, workflow, Makefile, package, and docs |
| `AlignmentCommands.swift` | Removed | `CompositeSceneCommands.align` and its one-composite delta test |
| `SceneCommands.swift` | Removed | `StructuralCommands`, `CompositeSceneCommands`, and `AnchorGeometryCommands` |
| P1 runtime-gate type/source | Removed | Delta history is the only production and test path |
| ADR-012 30/5 capacity and snapshot-primary direction | Superseded, historical ADR text retained | OD-1–OD-4; this table; `docs/adr/ADR-012-bounded-snapshot-history.md` execution note |

### Final amendment agreement — 2026-07-15

- AMEND-1: `AGREE` — P-ENDPOINT is correctly limited to the topology-derived
  runtime history slice.
- AMEND-2: `AGREE` — at M=10 no entry is evicted; 70,009,000−67,108,864 =
  2,900,136 bytes.
- AMEND-3: `AGREE` — separate asset charging, atomic charge transfer,
  checkpoint boundary, nine-checkpoint ceiling, and counter semantics are
  complete and internally consistent.
- AMEND-4: `AGREE` — canonical bytes provide the required bit-pattern identity;
  native canonical JSON emits `-0` and `0` distinctly.
- AMEND-5: `AGREE` — V is empty in schema v4 and the vacuous example remains a
  future-schema protocol guard.
- AMEND-6: `AGREE` — the listed old capacity constant, tests, and ADR rows are
  explicit implementation-time supersessions.

## Phase 5 tile-render caching — preimplementation freeze

VERIFY-029–033 were authored and independently recomputed before production
implementation. The three agreement rounds closed on 2026-07-17. Their values,
targets, tolerances, ceilings, policies, and corpus parameters are now frozen;
implementation has not begun at this checkpoint.

### Frozen owner decisions — OD-5–OD-8

> **2026-07-17 — OD-5:** tile size 256×256 device pixels; tile-cache budget
> exactly 134,217,728 bytes (= 512 full tiles at 262,144 B each — the exact
> divisibility is a design property, pinned); LRU eviction by last composite
> use; exact byte accounting (w×h×4, edge tiles smaller); when the budget
> cannot fit one full tile the cache is disabled-but-correct (every composite
> miss-renders; the composite/direct invariant still holds).
>
> **OD-6:** exact-current-zoom caching; any zoom or backing-scale change bumps
> the cache generation (lazy full invalidation); zoom gestures retain the
> direct-render path — BENCH-3 semantics and targets are untouched by
> construction.
>
> **OD-7:** per-object caching is deferred pending profiling evidence; Phase 5
> V1 is tile-only.
>
> **OD-8:** the peak-memory gate scenario extends to settle + delta-history
> P-FLOOR worst case + nine checkpoints + tile cache filled to budget; the
> 500 MiB ceiling is unchanged. Under memory-safety-net pressure the tile
> cache is discarded first, before any checkpoint and long before the history
> floor. Compliance is proven only by exact measured bytes and exact byte
> headroom at the gate; percentage estimates are never proof. The arithmetic
> expectation is 285,294,592 + 134,217,728 = 419,512,320 B, implying
> 104,775,680 B headroom under 524,288,000 B; this is an expectation only.

### Frozen tile policies

- **P-OUTSET:** outset the conservative ink bound by exactly one device pixel
  before tile mapping.
- **P-HALFOPEN:** treat device-space damage as
  `[minX,maxX) × [minY,maxY)`; columns are `floor(minX/256)` through
  `ceil(maxX/256)-1`, rows likewise, intersected with the canvas tile range.
- **P-NILDAMAGE:** typed `.none` means no invalidation; `.rects` maps only the
  listed ink bounds; `.full` or genuinely absent/unknown damage means full
  invalidation. The typed change stream is authoritative.
- **P-BUDGETFIT:** cached bytes may equal the budget; evict LRU entries until
  `Σ <= budget` and stop at exact equality.
- **P-TILERENDER-COUNT:** BENCH-2b counts tile renders, never cache hits. Its
  nonzero-render precondition remains trapping.

### VERIFY-029 — Conservative ink damage to tile-set mapping

- Status: `FROZEN`
- Freeze checkpoint: implementation `NOT STARTED` at `790c013`.
- T1 implementation: `TileDamageMapper`; permanent references
  `verify029FrozenDamageMappingExamples` and
  `verify029FrozenConservativeInkCases`. T2 wiring reference:
  `verifyT2TypedChangesUseOneInvalidationChokePoint`.
- Rule: `deviceScale = zoom × backingScale`. Map the conservative ink bound to
  device space, apply P-OUTSET, apply P-HALFOPEN, and clamp to the canvas tile
  range. Paths use stroke-inclusive `visualBounds`; images use their
  `visualBounds`; text uses Core Text image bounds union typographic bounds
  union `layoutBounds`; groups use the union of member ink bounds. An
  unavailable or untrustworthy ink bound is unknown damage and causes full
  invalidation.
- Worked examples, all with `backingScale = 1` unless stated otherwise:
  1. `z=1`, `D=(100,50,200,100)` gives device `[100,300)×[50,150)`,
     outset `[99,301)×[49,151)`, columns `0...1`, row `0`: **2 tiles**.
  2. `z=2`, same D gives outset `[199,601)×[99,301)`, columns `0...2`,
     rows `0...1`: **6 tiles**.
  3. On an 800×500 canvas, `z=1`, `D=(256,0,256,256)` gives outset
     `[255,513)×[-1,257)`, raw columns `0...2`, raw rows `-1...1`, and
     clamped columns `0...2`, rows `0...1`: **6 tiles**.
  4. Zero-area damage at `(300,300)`, `z=1`, gives `[299,301)²` and only
     tile **(1,1)**.
  5. On an 800×500 canvas, `D=(900,600,50,50)` gives
     `[899,951)×[599,651)`; raw `(column 3,row 2)` clamps to the **empty set**.
  6. Absent/unknown damage causes full invalidation; typed `.none` causes
     **zero invalidation**.
  7. `800×500`, `z=1`, `backingScale=2` maps to device 1600×1000 and is
     covered by the VERIFY-030 seven-column/four-row example.
- Permanent scene cases: transformed text, fallback-glyph text,
  image, path, and group union. TEXT-DEFECT-001 commit `ad1e5db` completed the
  prerequisite conservative text bounds without changing schema v4; its five
  permanent tests passed in the 127/127 full battery.
- Tolerance: exact integer tile indices after floating-to-integer floor/ceil;
  under-invalidation is forbidden.

### VERIFY-030 — Grid geometry, backing scale, and pixel alignment

- Status: `FROZEN`
- Freeze checkpoint: implementation `NOT STARTED` at `790c013`.
- T1 implementation: `TileGrid`; permanent reference
  `verify030FrozenGridGeometryAndByteCosts`. T2 generation-change wiring
  reference: `verifyT2TypedChangesUseOneInvalidationChokePoint`.
- Rule: `deviceScale = zoom × backingScale`;
  `W=ceil(docW×deviceScale)`, `H=ceil(docH×deviceScale)`;
  `columns=ceil(W/256)`, `rows=ceil(H/256)`. Tile origins are integer
  multiples of 256 device pixels. Right/bottom edge dimensions are the
  remaining device pixels. A backing-scale change bumps the generation just
  like a zoom change.
- Worked examples:
  1. 800×500, `z=1`, `backingScale=1` gives 4 columns and 2 rows; right edge
     width 32 and bottom edge height 244. Full tile = **262,144 B**;
     right-edge tile `32×256 = 8,192 pixels = 32,768 B`; bottom-edge tile
     `256×244×4 = 249,856 B`; corner `32×244×4 = 31,232 B`.
  2. 800×500, `z=1.5`, `backingScale=1` gives device 1200×750, 5 columns,
     3 rows, right edge 176, bottom edge 238.
  3. A 100×80 device canvas has one 100×80 tile costing **32,000 B**.
  4. 800×500, `z=1`, `backingScale=2` gives device 1600×1000, 7 columns,
     4 rows, right edge 64, bottom edge 232.
- Tolerance: exact integer geometry and byte arithmetic.

### VERIFY-031 — Budget-fit and LRU eviction arithmetic

- Status: `FROZEN`
- Freeze checkpoint: implementation `NOT STARTED` at `790c013`.
- T1 implementation: `TileCache`; permanent references
  `verify031FrozenCapacityAndExactBoundaryEviction`,
  `verify031FrozenLRUAndGenerationBehavior`, and
  `verify031DisabledCacheRemainsCompositeCorrect`. T2 memory-pressure
  ordering reference:
  `verifyT2PressureDropsFullTileCacheBeforeCheckpointsAndPreservesFloorPins`.
- Rule: exact byte accounting, P-BUDGETFIT, LRU by last composite use, and
  disabled-but-correct behavior when one full tile cannot fit.
- Worked examples under the exact 134,217,728 B budget:
  1. `512×262,144 = 134,217,728 B`, exactly permitted. A 513th full tile
     evicts exactly one LRU full tile.
  2. `510` full tiles plus one 31,232 B corner total **133,724,672 B**.
     One full insertion gives **133,986,816 B**, so no eviction. A second
     gives **134,248,960 B**, over by exactly **31,232 B**; evicting the LRU
     corner leaves **134,217,728 B**, so eviction stops after one entry.
  3. Insert A, B, C; composite A; insert D under forced pressure: **B** is
     evicted.
  4. A fixture budget of 200,000 B is below 262,144 B: no full-tile insertion
     occurs, every composite miss-renders, and correctness is unchanged.
- Tolerance: exact integer byte counts and deterministic LRU order.

### VERIFY-032 — Tile composite equals direct render

- Status: `FROZEN`
- Freeze checkpoint: implementation `NOT STARTED` at `790c013`.
- T1 implementation: cold- and fully-warm-cache harness references
  `verify032MixedSceneColdAndWarmCompositeEqualDirect`,
  `verify032CornerStraddleColdAndWarmCompositeEqualDirect`, and
  `verify032EmptyColdAndWarmCompositeEqualDirect`.
- Rule: compare actual image dimensions with the existing golden instrument:
  per-channel delta `<=3` is ignored, hard maximum is `12`, and the
  overflow-checked differing-pixel limit is
  `floor(actualWidth×actualHeight/100)`. Tile compositing expects **zero**
  differing pixels. Every nonzero count is reported even if the instrument
  passes, and any visible seam is a defect.
- Pinned scenes and limits:
  1. Mixed vectors/text/image, 800×500, 4×2 tiles: limit **4,000**, expected
     differing pixels **0**.
  2. Circle centered at device `(256,256)`, radius 40, on 512×512: four-tile
     seam straddle, limit `floor(262,144/100) = **2,621**`, expected **0**.
  3. Empty document on 256×256: limit `floor(65,536/100) = **655**`,
     expected **0**.
- Tolerance rationale: the frozen golden instrument measures acceptance; it
  does not weaken the zero-difference construction expectation.

### VERIFY-033 — Deterministic invalidation-completeness corpus

- Status: `FROZEN`
- Implementation: `NOT STARTED` at freeze
- T2 implementation reference:
  `verify033FrozenSeededInvalidationCompletenessCorpus`.
- Initial state: the exact 1,000-node benchmark reference document, stable
  pre-order scene-object indexing recomputed after structural changes, zoom
  1.0, backing scale 1, fresh delta history, empty tile cache, and exactly one
  warm-up composite before step 1.
- PRNG: exactly 64 steps; seed `0x00000000A110F00D`; each `draw()` performs
  `state = state &* 6364136223846793005 &+ 1` in UInt64 arithmetic and returns
  `state >> 33` (31 bits). Each step first consumes one draw and selects
  `draw() mod 100` from gapless ranges `0...29`, `30...49`, `50...59`,
  `60...74`, `75...84`, `85...94`, `95...99`.
- Complete operation table:
  1. **valueSwap**, 3 further draws `t,d,e`: target is
     `t mod objectCount`; `dx=(d mod 201)-100`, `dy=(e mod 201)-100`;
     translate through a value swap. `dx=dy=0` is P-IDENT-elided with zero
     tile re-renders.
  2. **structural** consumes subtype draw `s`. INSERT consumes `s,p,q,r`
     (4 further draws total): index `p mod (rootChildCount+1)` under the root
     layer, x `q mod 761`, y `r mod 461`, fixed 40×40 rectangle and fixed
     style. DELETE consumes `s,p` (2 further draws total): victim
     `p mod objectCount`, objects only and layers excluded. Subtype is
     `s mod 2` (INSERT/DELETE). Empty DELETE is a no-op with zero re-renders.
  3. **reorder**, 2 further draws `p,q`: candidate is
     `p mod (objects with at least two siblings)`; none means no-op while both
     draws remain consumed. New index is `q mod siblingCount`; same position
     is P-IDENT-elided with zero re-renders.
  4. **undo**, no further draws; empty stack is a legal zero-render no-op.
  5. **redo**, no further draws; empty stack is a legal zero-render no-op.
  6. **gestureFrame:** with no open session, OPEN consumes `t,d,e` (3 further
     draws), selects `t mod objectCount`, derives each delta component with
     the same 201-value rule, and applies the first live frame. With an open
     session, CONTINUE consumes `d,e` (2 further draws). Auto-commit occurs
     immediately before a subsequently selected non-gesture operation and at
     corpus end. Live frames publish damage; each frame asserts only that
     frame's mapped tiles re-render. Commit damage is old ink union new ink.
  7. **zoomChange**, 1 further draw `z`: new zoom is
     `{0.5,1.0,1.5,2.0}[z mod 4]`. Equal zoom is a no-op with no generation
     bump and zero invalidation; changed zoom bumps generation and lazily
     re-renders only requested visible tiles.
- After every step: full-canvas composite versus direct render under
  VERIFY-032; rendered tiles must be a subset of the P-OUTSET/P-HALFOPEN map
  of published damage, except lazy requested-tile rendering after generation
  bumps. Elided/no-op steps assert the exact empty render set.
  `CORPUS_FAILURE` retains step index, operation, subtype, draws consumed,
  seed, and offending tile indices.
- Independent seed walk: 205 total PRNG advances produce 15 value swaps,
  21 structural operations (11 INSERT, 10 DELETE), 5 reorders, 8 undos,
  5 redos, 6 gesture frames, and 4 zoom selections. All six gesture frames
  are OPEN live frames for this seed (zero CONTINUE). Zoom selections are
  step 2 `1.0→1.0` (no-op), step 14 `1.0→1.5`, step 19 `1.5→0.5`, and
  step 38 `0.5→0.5` (no-op). Every operation class is exercised.
- Boundary checks: 201 residues map gaplessly to `-100...100`;
  `q mod 761` gives `0...760` and `760+40=800`; `r mod 461` gives
  `0...460` and `460+40=500`; operation ranges cover `0...99` gaplessly.
- T2 hard requirement: damage-bearing change publication for uncommitted live
  gesture frames must be wired before this corpus can pass.

### BENCH-2b tile-era mechanism supersession

The owner-selected exposure corridor supersedes only BENCH-2b's old
2-device-pixel strip mechanism. Its p95 `<=16.7 ms`, 60+300 schedule, and
trapping nonzero-render precondition remain unchanged. The 1,000-node
reference document remains unchanged for all other benchmarks.

| Superseded item | Frozen successor |
|---|---|
| BENCH-2b 2-device-pixel pan, strip-redraw counter, and 1,000-node fixture | Dedicated document 46,480×250 units; `z=2`, `backingScale=1`; device 92,960×500; viewport 800×500; 256-device-pixel pan per frame; 360 one-column advances; 364 periods × 25 strictly interior nodes = 9,100 nodes; count exact tile renders only |

Corridor frames are 1-based `f=1...360`: warm-up `1...60`, measured
`61...360`. Setup renders columns `0...3`; frame f renders exactly tiles
`(f+3,0)` and `(f+3,1)`, so new columns are `4...363`. Device height 500
gives row heights 256 and **244**. The final viewport is
`[360×256, 360×256+800) = [92,160,92,960)`, exactly the device canvas end.

### Round-3 agreement — 2026-07-17

- AMEND-9: `AGREE` — the 1-based convention maps frames 1…360 bijectively to
  new columns 4…363; both rows render and the second row is 244 device pixels.
- AMEND-10: `AGREE` — the operation ranges, draw consumption, modulo bounds,
  identity/no-op behavior, lazy-generation exemptions, live-gesture damage
  requirement, and failure retention form one deterministic 64-step corpus.

### T3 execution references — 2026-07-17 (references only)

No frozen VERIFY-029–033 value changed. Permanent execution references added
by T3 are `bench2bExposureCorridorRendersExactIndices` and
`productionDocumentCoordinateCompositeEqualsDirect` in
`TileCompositeVerifyTests.swift`; the accepted T1/T2 tests are unconditional.
The production cutover, complete deletion/successor table, gate map, and
hosted-closure requirement are recorded in
`docs/phase-5/tile-cache-T3.md` and
`docs/adr/ADR-014-tile-composite-production-renderer.md`.
