# R1 model foundation

R1 performs the remediation's only schema bump, v3 to v4.

## Bounds contract

- `localBounds` is tight untransformed geometry.
- A path's `visualBounds` maps local-bounds corners through its object transform,
  takes the conservative AABB, then expands in document units for stroke cap/join.
- A group's visual bounds unions child visual bounds in group space, then maps the
  union corners through the group transform. Group transforms therefore scale the
  already-expanded child ink bounds.
- Singular transforms are accepted as renderable degenerate geometry. Inversion-
  dependent mutations fail without changing the document.

Selection overlays, alignment, spatial indexing, and SVG view-box calculation use
visual bounds because they describe rendered ink. Path editing uses local geometry.

## Validation limits

Limits are centralized in `DocumentLimits`. All coordinates and transform components
must be finite and within the magnitude budget. Validation recursively enforces global
IDs, references, gradients, styles, node/segment/string counts, image headers, checked
pixel multiplication, and checked aggregate asset sizes.

## Migration

Typed v2 and v3 structures are quarantined in `DocumentFormats`. v2 migrates to v3,
then v3 to v4. Separate v3 arrays migrate in their former rendered order: paths,
images, text. The result validates before it is returned. Canonical v4 JSON is frozen
by a byte-matched project-created golden fixture.
