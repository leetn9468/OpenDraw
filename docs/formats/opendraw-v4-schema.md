# OpenDraw native schema version 4

The `.odraw` v4 file is UTF-8 JSON emitted by `JSONEncoder` with sorted keys.
Numbers use Swift's JSON numeric encoding; non-finite numbers are forbidden by model
validation. Unknown fields are ignored on read, while missing required fields fail.

Root required fields are `formatVersion` (`4`), finite positive `width`, `height`,
`unit`, ordered `layers`, `swatches`, and `gradients`.

Each layer requires stable `id`, `name`, visibility/lock flags, and one ordered
`nodes` array. `SceneNode` uses Swift Codable's tagged enum representation with one
case: `path`, `text`, `image`, or recursive `group`. Node order is z-order. Groups
contain an ID, name, affine transform, and ordered child nodes.

Paths contain an ID, affine transform, style, and a compound path containing ordered
subpaths plus one fill rule. Each subpath contains cubic segments and closure state.
Text contains content, requested font information, origin, layout bounds, color, and
transform. Images contain frame, storage choice, declared pixel dimensions, and
transform. Resources use stable IDs and every reference must resolve.

Canonical conformance is pinned by `Fixtures/v4-canonical-golden.odraw`. Changing
field names, enum representation, required status, or numeric output requires a future
schema version and typed migration; v4 bytes are frozen.

Migration order is typed `v2 -> v3 -> v4`. The v3-to-v4 layer order is paths, then
images, then text because that is the order v3 rendered to users.
