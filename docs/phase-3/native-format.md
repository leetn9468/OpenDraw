# Vector Foundry native format

Extension: `.vfd` (working designation)  
Encoding: UTF-8 JSON with sorted keys  
Current version: 3 (Phase 3 introduced version 2; Phase 4 migrates it)

The root contains `formatVersion`, artboard width/height, unit, ordered layers and,
from version 3, optional resources. Layers contain ordered paths and optional text
and image objects. IDs are UUID-backed values. Geometry uses document-space doubles;
paths store cubic segments and closure/fill rule independently of SVG.

Writers validate before encoding and use a temporary sibling plus filesystem move
or replacement. Readers cap input at 100 MiB, inspect the version before decoding,
decode into an isolated value, validate invariants, and only then return a document.
Unknown future versions fail without changing a live document.

Canonical field order is an encoder property, not an in-memory layout contract.
The schema is original and no proprietary compatibility is implied.
