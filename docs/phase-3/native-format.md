# OpenDraw native format

Extension: `.odraw`
Encoding: UTF-8 JSON with sorted keys  
Current version: 4 (the pre–Phase 5 R1 remediation introduced ordered scene nodes)

The root contains `formatVersion`, artboard width/height, unit, ordered layers and
resources. Layers contain one heterogeneous ordered node sequence; nodes may be paths,
text, images, or recursive groups. Paths support multiple cubic subpaths and one fill
rule independently of SVG. IDs are UUID-backed and globally unique.

Writers validate before encoding and use a temporary sibling plus filesystem move
or replacement. Readers cap input at 100 MiB, inspect the version before decoding,
decode into an isolated value, validate invariants, and only then return a document.
Unknown future versions fail without changing a live document.

Canonical field order is an encoder property, not an in-memory layout contract.
The schema is original and no proprietary compatibility is implied.
