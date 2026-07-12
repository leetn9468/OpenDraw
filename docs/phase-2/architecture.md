# Architecture overview and module rules

The application is a directed set of Swift Package Manager targets. Authoritative
state is held in `DocumentModel`; views render snapshots and tools request commands.

```text
VectorFoundryApp / MacPlatform
        |          |
        v          v
EditorTools    TextEngine
        |
        v
EditorCommands     DocumentFormats
        |             |
        +------v------+
          DocumentModel ---> CanvasRender
                |
                v
             Geometry
                |
                v
            EditorCore
```

Arrows mean “may depend on.” `CanvasRender` depends on the model; the model never
depends on a renderer. The package manifest enforces declared dependencies and the
module-check script rejects key forbidden imports.

## Module contracts

| Module | Responsibilities / public boundary | Allowed dependencies | Ownership and threading | Error / serialization boundary |
|---|---|---|---|---|
| EditorCore | IDs, units, colors, errors, diagnostics | Foundation, OSLog | Immutable/value types are `Sendable` | Defines shared errors; no document serialization |
| Geometry | Points, rectangles, affine math, cubic evaluation and hit tests | EditorCore, Foundation | Value types; callable off main thread | Reject invalid runtime parameters safely; Codable primitives |
| DocumentModel | Document/layer/object/style invariants | EditorCore, Geometry, Foundation | Document is a value snapshot; caller owns mutations | Codable model, but codecs own external validation |
| EditorCommands | Atomic mutations and history | DocumentModel | History has one owner; transfer is explicit | Command failure commits no candidate state; not serialized |
| CanvasRender | Backend adapter from model to Core Graphics | DocumentModel, Geometry, CoreGraphics | Renderer is stateless; caller owns context/synchronization | No persistence; rendering failures must not mutate model |
| TextEngine | Core Text shaping/measurement boundary | EditorCore, CoreText/CoreGraphics | Stateless facade; font APIs wrapped here | Invalid typography inputs use shared errors; stored text remains model data |
| EditorTools | Input-independent tool state and hit policies | Core, Geometry, Model, Commands | Value state; UI converts events before calling | No file serialization; mutations become commands |
| DocumentFormats | Native/SVG/PNG adapters and hostile-input limits | Core, Geometry, Model | Stateless codecs; immutable data crossing boundary | Sole external serialization trust boundary |
| MacPlatform | AppKit input/window/clipboard/dialog adapters | EditorCore, AppKit | MainActor for AppKit-owned state | Converts platform errors to shared errors |
| VectorFoundryApp | Composition root and original application UI | All facade modules | MainActor; no authoritative model in widgets | Presents errors; does not define formats |

## Dependency review procedure

1. Update `Package.swift` deliberately; no target imports an undeclared module.
2. Run `scripts/check-module-dependencies.sh`.
3. Run `swift package describe` during review when the graph changes.
4. New upward dependency requires an ADR; UI/framework types may not enter Core,
   Geometry, DocumentModel, or EditorCommands.
