# Pre–Phase 5 Full Code Audit

Audit date: 2026-07-12  
Scope: production sources, tests, Swift package configuration, CI, persistence,
security boundaries, rendering, interaction, performance claims, and clean-room
compliance.  
Disposition: **Phase 5 blocked pending remediation and regression tests.**

No source changes were made as part of this audit. Line numbers and excerpts refer
to the repository state on the audit date.

## Executive summary

The repository builds cleanly and all 29 tests pass in debug, release, and
AddressSanitizer runs. Those checks do not cover multiple release-blocking defects.
The most serious findings are:

1. Transforms are omitted from bounds, selection, alignment, and spatial indexing.
2. SVG export silently loses transforms and other supported properties.
3. Native loading allocates the entire input before enforcing its size limit.
4. Document validation permits invalid geometry and unresolved resources.
5. Opening a file can discard unsaved work.
6. Suppressed command errors can corrupt drag-history coalescing.
7. Mixed path/text/image stacking order cannot be represented.
8. Embedded image bytes reach synchronous rendering without load-time validation.

Critical and high findings should be fixed, covered by regression tests, and audited
again before Phase 5 begins.

## Release-blocking findings and code excerpts

### AUDIT-001 — Critical: transforms are excluded from bounds

`PathObject.bounds` returns local path bounds although rendering applies the full
affine transform. Selection, alignment, selection overlays, and spatial indexing
therefore operate on geometry different from what the user sees.

File: `Sources/DocumentModel/Document.swift`, around line 99.

```swift
public struct PathObject: Identifiable, Hashable, Codable, Sendable {
    public var id: ObjectID
    public var path: BezierPath
    public var style: PathStyle
    public var transform: Geometry.AffineTransform

    // ...

    public var bounds: Rect? { path.bounds }
}
```

Downstream alignment uses those untransformed bounds:

```swift
let selected = document.layers.flatMap(\.paths).filter { pathIDs.contains($0.id) }
let bounds = selected.compactMap(\.bounds)

// ...

document.layers[layerIndex].paths[pathIndex].transform.tx += target - b.minX
```

Required correction: introduce canonical transformed visual bounds, including
rotation, scale, stroke width, caps, joins, and miter expansion. Use the same bounds
contract in alignment, selection, hit-testing, indexing, damage tracking, and export.

### AUDIT-002 — Critical: SVG export silently loses properties

The exporter emits local coordinates without the object transform. It also omits
fill rule, line cap/join, dash pattern, color alpha, blend mode, and text transforms.
The loss report only covers gradients and raster images.

File: `Sources/DocumentFormats/SVGExporter.swift`, around lines 22–41.

```swift
for object in layer.paths {
    guard let first = object.segments.first else { continue }
    var d = "M \(number(first.start.x)) \(number(first.start.y))"
    for s in object.segments {
        d +=
            " C \(number(s.control1.x)) \(number(s.control1.y)) "
            + "\(number(s.control2.x)) \(number(s.control2.y)) "
            + "\(number(s.end.x)) \(number(s.end.y))"
    }

    body +=
        "<path d=\"\(d)\" fill=\"\(fill)\" stroke=\"\(stroke)\" "
        + "stroke-width=\"\(number(object.style.strokeWidth))\" "
        + "opacity=\"\(number(object.style.opacity ?? 1))\"/>"
}
```

Required correction: export every representable property, apply or emit transforms,
and return structured object-level loss entries for every nonrepresentable property.
Loss review must occur before the destination is overwritten.

### AUDIT-003 — Critical: native size limit runs after allocation

`load(from:)` reads the full file before `decode` checks `maximumBytes`. A hostile
file can exhaust memory before the limit is evaluated.

File: `Sources/DocumentFormats/NativeDocumentCodec.swift`, lines 53–54.

```swift
public func load(from url: URL) throws -> EditorDocument {
    try decode(Data(contentsOf: url, options: .mappedIfSafe))
}
```

The later check cannot protect the initial allocation:

```swift
public func decode(_ data: Data) throws -> EditorDocument {
    guard data.count <= Self.maximumBytes else {
        throw EditorError.corruptInput("Document exceeds size limit")
    }
    // ...
}
```

Required correction: inspect file metadata first and perform a bounded or streaming
read. Add JSON depth, object count, anchor count, string length, and aggregate asset
limits before constructing the live model.

### AUDIT-004 — Critical: validation is incomplete

Validation checks artboard dimensions, path ID uniqueness, stroke width, opacity,
resource ID uniqueness, text size, and basic image dimensions. It does not validate
finite path points/transforms, all ID types, resource references, gradients, colors,
dash values, embedded image bytes, collection counts, or maximum artboard size.

File: `Sources/DocumentModel/Document.swift`, around lines 193–221.

```swift
public func validate() throws {
    guard width.isFinite, height.isFinite, width > 0, height > 0, !layers.isEmpty else {
        throw EditorError.invariantViolation("Invalid document")
    }
    let objects = layers.flatMap(\.paths)
    let objectIDs = objects.map(\.id)
    guard Set(objectIDs).count == objectIDs.count else {
        throw EditorError.invariantViolation("Duplicate object ID")
    }
    for object in objects {
        guard object.style.strokeWidth.isFinite,
            object.style.strokeWidth >= 0,
            (object.style.opacity ?? 1).isFinite
        else {
            throw EditorError.invariantViolation("Invalid style")
        }
    }
    // Text and image checks follow, but path geometry and references are unchecked.
}
```

Required correction: centralize strict model validation and apply it after decoding,
after migrations, and before every committed command. Enforce finite coordinates,
reasonable counts/sizes, global ID uniqueness, resource referential integrity, valid
gradient stops, valid style values, and validated embedded resources.

### AUDIT-005 — High: opening discards unsaved work

The termination path prompts, but Open replaces the current history immediately.

File: `Sources/VectorFoundryApp/main.swift`, lines 215–223.

```swift
private func openDocument() {
    guard let canvas else { return }
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
        let document = try NativeDocumentCodec().load(from: url)
        canvas.replaceDocument(document)
    } catch {
        NSAlert(error: error).runModal()
    }
}
```

Required correction: use one save/discard/cancel coordinator for Open, New, Close,
Revert, and Quit. Replacement must occur only after the user resolves dirty state.

### AUDIT-006 — High: suppressed drag errors can corrupt history

The first command error is discarded, but `dragHasMutation` becomes true anyway.
The next coalescing call can remove or merge an unrelated undo entry.

File: `Sources/VectorFoundryApp/main.swift`, lines 68–73.

```swift
if dragHasMutation {
    try? history.coalesce(command)
} else {
    try? history.perform(command)
    dragHasMutation = true
}
```

The generic coalescer also pops the latest command without confirming that it belongs
to the same gesture:

```swift
public mutating func coalesce(_ command: DocumentCommand) throws {
    let earlier = undoStack.popLast()
    do {
        try perform(command)
        if let earlier { undoStack[undoStack.count - 1] = earlier }
    } catch {
        if let earlier { undoStack.append(earlier) }
        throw error
    }
}
```

Required correction: use gesture/transaction IDs, coalesce only compatible commands,
advance UI state only after success, and surface or log all command failures.

### AUDIT-007 — High: mixed stacking order is impossible

Each layer owns three independent arrays. Rendering always draws paths, then images,
then text, regardless of intended order.

```swift
public struct Layer: Identifiable, Hashable, Codable, Sendable {
    public var paths: [PathObject]
    public var textObjects: [TextObject]?
    public var imageObjects: [ImageObject]?
}
```

```swift
for layer in document.layers where layer.isVisible {
    for object in layer.paths { render(object, swatches: swatches, gradients: gradients, in: context) }
    for image in layer.imageObjects ?? [] { render(image, in: context) }
    for text in layer.textObjects ?? [] { render(text, in: context) }
}
```

Required correction: use one ordered object-node collection with typed payloads or a
stable ordered reference list. Migrate v3 documents explicitly.

### AUDIT-008 — High: embedded images bypass the safe loader

Native decoding accepts embedded `Data` without ImageIO validation. Rendering then
decodes that data synchronously, normally from the AppKit drawing path.

```swift
if case .embedded(let data) = image.storage,
    let source = CGImageSourceCreateWithData(data as CFData, nil),
    let cg = CGImageSourceCreateImageAtIndex(source, 0, nil)
{
    context.draw(cg, in: frame)
} else {
    placeholder(frame, in: context)
}
```

Required correction: validate all embedded assets at import/load time, decode off the
main thread with cancellation and pixel limits, and render only approved cached
resources or safe placeholders.

## Complete risk inventory

### Geometry and editing

- **High:** collinear backtracking Bézier curves can be flattened to a single chord,
  breaking hit-testing and derived operations.
- **Medium:** `hitTest(...subdivisions:)` ignores the supplied subdivision value.
- **Medium:** closed-path hit-testing does not explicitly test the closing edge.
- **Medium:** object selection uses rectangular bounds, producing false positives.
- **Medium:** direct selection behaves like object selection; anchor editing is absent.
- **Medium:** pen interaction creates straight segments and no direction handles.
- **Medium:** scale and rotation lack complete interaction paths.
- **Medium:** UI selection ignores layer visibility and locking.
- **Medium:** snapping exists but is not connected to canvas gestures.
- **Low:** exact document equality drives dirty state and can treat numerically
  equivalent operations as different.

### Persistence and compatibility

- **High:** SVG parsing lacks nesting, element, warning, and output-object limits.
- **High:** internal XML entity-expansion safety is not demonstrated by tests.
- **High:** ignored `<script>` and `<foreignObject>` elements do not suppress parsing
  of their descendant elements.
- **High:** SVG import is not integrated into the application Open flow.
- **Medium:** SVG namespaces and root placement are not validated.
- **Medium:** repeated SVG roots can overwrite dimensions.
- **Medium:** unit parsing is incomplete and case-sensitive.
- **Medium:** import/export warnings lack object location and occurrence count.
- **Medium:** lossy SVG is written before the warning is presented.
- **Medium:** a gradient may export as no fill even though the warning promises a
  solid fallback.
- **Medium:** v2 migration only rewrites the version number rather than applying typed
  migration steps.
- **Medium:** atomic replacement does not explicitly synchronize the file and parent
  directory for crash durability.
- **Medium:** no autosave, recovery, backup, or interrupted-save end-to-end test exists.
- **Medium:** `pixelWidth * pixelHeight` can overflow for extreme integers.
- **Medium:** linked-resource paths are checked lexically but not normalized or
  resolved inside an approved resource root.
- **Low:** sorted JSON keys are deterministic but not yet a frozen canonical schema.

### Model and history

- **High:** undo stores complete document snapshots; 100 histories with embedded
  images can consume extreme memory.
- **Medium:** coalescing does not check command identity or gesture ownership.
- **Medium:** `maximumEntries` can be mutated after initialization to an invalid value.
- **Medium:** dirty-state comparison costs increase with the entire document size.
- **Medium:** `DocumentChange` exists, but there is no actual change-notification stream.
- **Medium:** groups, compound paths, and a mixed hierarchy are not represented.
- **Medium:** dangling swatch and gradient references pass validation.
- **Medium:** gradients can have too few stops or non-finite geometry.
- **Low:** `EditorDocument.sample()` uses `try!` and can become a startup crash after
  future invariant changes.

### Rendering, performance, and concurrency

- **High:** an uncached 1,000-object render is approximately 41–43 ms, above the
  16.7 ms target.
- **High:** bitmap-cache allocation derives directly from unrestricted artboard
  dimensions and can trap or exhaust memory.
- **Medium:** cache identity uses `hashValue`; a collision can return stale artwork.
- **Medium:** `SceneBitmapCache` is `@unchecked Sendable`; locking its own state does
  not make the caller-owned destination `CGContext` thread-safe.
- **Medium:** the cache lock is held during rebuild and destination drawing.
- **Medium:** cache resolution is one pixel per document unit, producing Retina/high-
  zoom blur and excessive memory for large artboards.
- **Medium:** damage tracking is not connected to rendering, and `nil` ambiguously
  represents both no accumulated region and full invalidation.
- **Medium:** text drawing errors are suppressed.
- **Medium:** Core Text orientation/baseline behavior in the flipped AppKit canvas is
  not verified.
- **Medium:** rendering tests assert bitmap existence, not correct pixels.
- **Low:** the forced Core Text glyph-run cast is a potential crash if bridging
  assumptions change.

Relevant cache excerpt:

```swift
public final class SceneBitmapCache: @unchecked Sendable {
    private let lock = NSLock()
    private var key: Int?
    private var image: CGImage?

    public func render(_ document: EditorDocument, in destination: CGContext, viewport: RenderViewport) {
        lock.lock()
        defer { lock.unlock() }
        let nextKey = document.hashValue
        let width = max(1, Int(document.width.rounded(.up)))
        let height = max(1, Int(document.height.rounded(.up)))
        // Allocation and drawing occur while the lock is held.
    }
}
```

### Application and usability

- **High:** no automated UI journey covers create, edit, save, reopen, and export.
- **High:** the canvas has no verified accessibility tree or VoiceOver workflow.
- **High:** file load/save/export and resource decoding are synchronous on the main
  actor.
- **Medium:** there is no New flow, full properties panel, persistent document URL,
  Save/Save As distinction, recent files, layer UI, text tool, image placement UI,
  gradient UI, alignment UI, or complete zoom/pan UI.
- **Medium:** close protection is only reasoned about for the current single-window
  application.
- **Medium:** direct selection is not exposed in the toolbar.
- **Medium:** command enabled states are not updated for undo, redo, or selection.
- **Low:** the application window is still titled “Foundation.”

### Testing, CI, and release process

- **High:** CI runs only macOS 15 and does not validate macOS 13 or Intel.
- **High:** CI omits `scripts/check-module-dependencies.sh`.
- **High:** CI omits AddressSanitizer and release-mode tests.
- **High:** malformed input tests are deterministic random cases, not coverage-guided
  fuzzing.
- **High:** tests do not cover deep JSON/XML, huge counts, decompression bombs,
  integer overflow, cancellation, or parser deadlines.
- **Medium:** the performance sample repeats one object with the same ID 1,000 times,
  violating document invariants and weakening the benchmark.
- **Medium:** wall-clock thresholds can be flaky under shared CI load.
- **Medium:** memory/RSS and leak thresholds are absent.
- **Medium:** startup p95, interaction p95, crash-free 100-run, and 100-cycle native
  round-trip gates are not automated.
- **Medium:** no golden-image comparison suite exists.
- **Medium:** no coverage threshold, mutation tests, or API-documentation checks exist.
- **Medium:** there is no signed `.app`, sandbox profile, hardened runtime,
  notarization, symbolication, or packaging workflow.
- **Low:** the repository has no commit yet, so the audit has no immutable baseline.

### Clean-room, licensing, and product

- No production file references or includes `AI10.c`; the clean-room boundary appears
  intact for the audited tree.
- The working `AI10` association and “Vector Foundry” name require trademark and
  public-product naming review.
- No third-party packages are present, but Apple SDK/runtime distribution terms and
  notices still require packaging review.
- Phase completion wording should be reconciled with actual UI acceptance coverage
  before public claims.

## Verification evidence

At the audited revision:

- Debug tests: 29/29 passed.
- Release tests: 29/29 passed.
- AddressSanitizer tests: 29/29 passed.
- Swift formatting lint: passed.
- Module dependency script: passed.
- Release build: passed.
- Third-party Swift package dependencies: none.

These results do not negate the findings because many tests prove that an operation
completed, not that its output is geometrically, visually, or semantically correct.

## Required remediation order

1. Add strict bounded-input and complete model validation.
2. Define transformed visual-bounds semantics and update every consumer.
3. Replace the layer representation with ordered heterogeneous object nodes.
4. Correct SVG export and make all compatibility loss explicit before writing.
5. Fix dirty-document coordination and command error/coalescing behavior.
6. Validate/decode resources away from rendering and the main thread.
7. Replace snapshot history and hash-based cache identity with bounded, explicit
   revision-aware designs.
8. Add adversarial parser tests, golden rendering tests, UI/accessibility tests, and
   macOS 13/Intel CI coverage.
9. Rerun debug, release, sanitizer, performance, memory, and clean-room audits.
10. Begin Phase 5 only after every critical/high item is closed or explicitly accepted
    by the project owner with documented rationale.

This is an engineering audit, not legal advice or a guarantee that no undiscovered
defect exists.
