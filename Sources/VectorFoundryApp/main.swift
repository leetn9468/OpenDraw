import AppKit
import CanvasRender
import DocumentFormats
import DocumentModel
import EditorCommands
import EditorCore
import EditorTools
import Geometry
import TextEngine
import UniformTypeIdentifiers

@MainActor
final class CanvasView: NSView {
    private struct AnchorRef: Hashable {
        var pathID: ObjectID
        var subpath: Int
        var segment: Int
    }
    private struct ControlRef {
        var pathID: ObjectID
        var subpath: Int
        var segment: Int
        var control: Int
    }
    private enum TransformGesture {
        case scale(TransformHandle)
        case rotate
    }
    var history: CommandHistory
    var activeTool: ActiveTool = .pen
    private var pen = SmoothPenToolState()
    private var penMouseDown: Point?
    private var penPreviewPoint: Point?
    private var dragStart: Point?
    private var dragLast: Point?
    private var selectedIDs: Set<ObjectID> = []
    private var selectedAnchors: Set<AnchorRef> = []
    private var selectedControl: ControlRef?
    private var activeLayerIndex = 0
    private var dragHasMutation = false
    private var dragGestureID: GestureID?
    private(set) var zoom = 1.0
    private(set) var pan = Point(x: 0, y: 0)
    private var spaceDown = false
    private var panDragLocation: NSPoint?
    private var snappingEnabled = true
    private var snapIndicator: Point?
    private var transformGesture: TransformGesture?
    private let renderer = CoreGraphicsRenderer()
    private var changeTask: Task<Void, Never>?
    init(frame: NSRect, document: EditorDocument) {
        history = CommandHistory(document: document)
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("OpenDraw document canvas")
        subscribeToChanges()
    }
    required init?(coder: NSCoder) { nil }
    var hasSelection: Bool { !selectedIDs.isEmpty }
    var hasMultipleSelection: Bool { selectedIDs.count > 1 }
    deinit { changeTask?.cancel() }
    private func subscribeToChanges() {
        changeTask?.cancel()
        let stream = history.changes()
        changeTask = Task { @MainActor [weak self] in
            for await _ in stream { self?.needsDisplay = true }
        }
    }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: 24 + pan.x, y: 24 + pan.y)
        context.scaleBy(x: zoom, y: zoom)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: history.document.width, height: history.document.height))
        renderer.render(history.document, in: context)
        if activeTool == .directSelection {
            context.setFillColor(NSColor.controlAccentColor.cgColor)
            for id in selectedIDs {
                guard let path = history.document.path(id: id) else { continue }
                for subpath in path.path.subpaths {
                    for segment in subpath.segments {
                        if let anchor = history.document.documentPoint(pathID: id, localPoint: segment.start) {
                            context.fillEllipse(
                                in: CGRect(
                                    x: anchor.x - 3 / zoom, y: anchor.y - 3 / zoom,
                                    width: 6 / zoom, height: 6 / zoom))
                        }
                        if let anchor = history.document.documentPoint(pathID: id, localPoint: segment.start),
                            let c1 = history.document.documentPoint(pathID: id, localPoint: segment.control1),
                            let c2 = history.document.documentPoint(pathID: id, localPoint: segment.control2)
                        {
                            context.setStrokeColor(NSColor.controlAccentColor.withAlphaComponent(0.6).cgColor)
                            context.move(to: CGPoint(x: anchor.x, y: anchor.y))
                            context.addLine(to: CGPoint(x: c1.x, y: c1.y))
                            context.addLine(to: CGPoint(x: c2.x, y: c2.y))
                            context.strokePath()
                            context.fillEllipse(
                                in: CGRect(x: c1.x - 2 / zoom, y: c1.y - 2 / zoom, width: 4 / zoom, height: 4 / zoom))
                            context.fillEllipse(
                                in: CGRect(x: c2.x - 2 / zoom, y: c2.y - 2 / zoom, width: 4 / zoom, height: 4 / zoom))
                        }
                    }
                }
            }
        }
        if activeTool == .selection, let bounds = selectionBounds() {
            context.setStrokeColor(NSColor.controlAccentColor.cgColor)
            context.setLineWidth(1 / zoom)
            context.stroke(CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height))
            context.setFillColor(NSColor.controlAccentColor.cgColor)
            for (_, point) in handlePoints(bounds) {
                context.fill(CGRect(x: point.x - 3 / zoom, y: point.y - 3 / zoom, width: 6 / zoom, height: 6 / zoom))
            }
            let rotation = Point(x: bounds.center.x, y: bounds.minY - 20 / zoom)
            context.strokeEllipse(
                in: CGRect(
                    x: rotation.x - 4 / zoom, y: rotation.y - 4 / zoom,
                    width: 8 / zoom, height: 8 / zoom))
        }
        if let snapIndicator {
            context.setStrokeColor(NSColor.systemRed.cgColor)
            context.setLineWidth(1 / zoom)
            context.move(to: CGPoint(x: snapIndicator.x - 8 / zoom, y: snapIndicator.y))
            context.addLine(to: CGPoint(x: snapIndicator.x + 8 / zoom, y: snapIndicator.y))
            context.move(to: CGPoint(x: snapIndicator.x, y: snapIndicator.y - 8 / zoom))
            context.addLine(to: CGPoint(x: snapIndicator.x, y: snapIndicator.y + 8 / zoom))
            context.strokePath()
        }
        if activeTool == .pen, let previewPoint = penPreviewPoint, let preview = pen.preview(to: previewPoint) {
            context.setStrokeColor(NSColor.controlAccentColor.cgColor)
            context.setLineWidth(1 / zoom)
            context.move(to: CGPoint(x: preview.start.x, y: preview.start.y))
            context.addCurve(
                to: CGPoint(x: preview.end.x, y: preview.end.y),
                control1: CGPoint(x: preview.control1.x, y: preview.control1.y),
                control2: CGPoint(x: preview.control2.x, y: preview.control2.y))
            context.strokePath()
        }
        context.restoreGState()
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if spaceDown {
            panDragLocation = location
            return
        }
        let point = documentPoint(location)
        if activeTool == .selection, let bounds = selectionBounds() {
            if let handle = handlePoints(bounds).first(where: { $0.1.distance(to: point) <= 7 / zoom })?.0 {
                transformGesture = .scale(handle)
                dragLast = point
                dragHasMutation = false
                dragGestureID = GestureID()
                return
            }
            let rotation = Point(x: bounds.center.x, y: bounds.minY - 20 / zoom)
            if rotation.distance(to: point) <= 8 / zoom {
                transformGesture = .rotate
                dragLast = point
                dragHasMutation = false
                dragGestureID = GestureID()
                return
            }
        }
        if activeTool == .text {
            createText(at: point)
        } else if activeTool == .pen {
            penMouseDown = point
            penPreviewPoint = point
        } else if activeTool == .selection || activeTool == .directSelection {
            let hit = SelectionTool().hitTest(history.document, pointer: point, zoom: zoom)
            if event.modifierFlags.contains(.shift), let hit {
                selectedIDs.insert(hit)
            } else {
                selectedIDs = hit.map { [$0] } ?? []
            }
            if activeTool == .directSelection, let hit, let path = history.document.path(id: hit) {
                var nearest: (AnchorRef, Double)?
                var nearestControl: (ControlRef, Double)?
                for (subpathIndex, subpath) in path.path.subpaths.enumerated() {
                    for (segmentIndex, segment) in subpath.segments.enumerated() {
                        for (controlIndex, local) in [(1, segment.control1), (2, segment.control2)] {
                            if let position = history.document.documentPoint(pathID: hit, localPoint: local) {
                                let distance = position.distance(to: point)
                                if distance <= 6 / zoom, distance < nearestControl?.1 ?? .infinity {
                                    nearestControl = (
                                        ControlRef(
                                            pathID: hit, subpath: subpathIndex, segment: segmentIndex,
                                            control: controlIndex), distance
                                    )
                                }
                            }
                        }
                        guard
                            let documentAnchor = history.document.documentPoint(pathID: hit, localPoint: segment.start)
                        else { continue }
                        let distance = documentAnchor.distance(to: point)
                        if distance <= 6 / zoom, distance < nearest?.1 ?? .infinity {
                            nearest = (AnchorRef(pathID: hit, subpath: subpathIndex, segment: segmentIndex), distance)
                        }
                    }
                }
                if let control = nearestControl, control.1 < nearest?.1 ?? .infinity {
                    selectedControl = control.0
                    selectedAnchors.removeAll()
                } else if let anchor = nearest?.0 {
                    selectedControl = nil
                    if event.modifierFlags.contains(.shift) {
                        selectedAnchors.insert(anchor)
                    } else {
                        selectedAnchors = [anchor]
                    }
                }
            }
            dragLast = point
            dragHasMutation = false
            dragGestureID = GestureID()
            needsDisplay = true
        } else {
            dragStart = point
        }
    }
    override func mouseDragged(with event: NSEvent) {
        if activeTool == .pen, penMouseDown != nil {
            penPreviewPoint = documentPoint(convert(event.locationInWindow, from: nil))
            needsDisplay = true
            return
        }
        if let prior = panDragLocation {
            let location = convert(event.locationInWindow, from: nil)
            pan = Point(x: pan.x + location.x - prior.x, y: pan.y + location.y - prior.y)
            panDragLocation = location
            needsDisplay = true
            return
        }
        guard !selectedIDs.isEmpty, let prior = dragLast else { return }
        let location = convert(event.locationInWindow, from: nil)
        let rawNext = documentPoint(location)
        let next = snappingEnabled ? snappedPoint(rawNext) : rawNext
        snapIndicator = next == rawNext ? nil : next
        let dx = next.x - prior.x
        let dy = next.y - prior.y
        guard dx != 0 || dy != 0 else { return }
        if let transformGesture, let bounds = selectionBounds() {
            var documentTransform: Geometry.AffineTransform?
            switch transformGesture {
            case .scale(let handle):
                if let factors = TransformInteractions.scale(
                    bounds: bounds, handle: handle, displacement: Point(x: dx, y: dy),
                    uniform: event.modifierFlags.contains(.shift), fromCenter: event.modifierFlags.contains(.option))
                {
                    let pivot = event.modifierFlags.contains(.option) ? bounds.center : oppositePoint(handle, bounds)
                    documentTransform = Geometry.AffineTransform(
                        a: factors.x, d: factors.y, tx: pivot.x * (1 - factors.x), ty: pivot.y * (1 - factors.y))
                }
            case .rotate:
                let pivot = bounds.center
                let delta = atan2(next.y - pivot.y, next.x - pivot.x) - atan2(prior.y - pivot.y, prior.x - pivot.x)
                documentTransform = TransformInteractions.rotation(
                    about: pivot,
                    radians: TransformInteractions.snappedRotation(
                        radians: delta, constrain: event.modifierFlags.contains(.shift)))
            }
            if let documentTransform {
                let ids = selectedIDs
                let command = DocumentCommand(name: "Transform selection") { document in
                    for id in ids { _ = document.applyDocumentTransform(id: id, transform: documentTransform) }
                }
                do {
                    if dragHasMutation, let dragGestureID {
                        try history.coalesce(command, gestureID: dragGestureID)
                    } else {
                        try history.perform(command, gestureID: dragGestureID)
                        dragHasMutation = true
                    }
                } catch { presentCommandError(error, command: "Transform selection") }
            }
            dragLast = next
            needsDisplay = true
            return
        }
        let ids = selectedIDs
        if activeTool == .directSelection, let control = selectedControl {
            let command = SceneCommands.moveControl(
                pathID: control.pathID, subpath: control.subpath,
                segment: control.segment, control: control.control, delta: Point(x: dx, y: dy))
            do {
                if dragHasMutation, let dragGestureID {
                    try history.coalesce(command, gestureID: dragGestureID)
                } else {
                    try history.perform(command, gestureID: dragGestureID)
                    dragHasMutation = true
                }
            } catch { presentCommandError(error, command: "Move direction handle") }
            dragLast = next
            return
        }
        if activeTool == .directSelection, !selectedAnchors.isEmpty {
            do {
                for anchor in selectedAnchors {
                    let command = SceneCommands.moveAnchor(
                        pathID: anchor.pathID, subpath: anchor.subpath,
                        segment: anchor.segment, delta: Point(x: dx, y: dy))
                    if dragHasMutation, let dragGestureID {
                        try history.coalesce(command, gestureID: dragGestureID)
                    } else {
                        try history.perform(command, gestureID: dragGestureID)
                        dragHasMutation = true
                    }
                }
            } catch { presentCommandError(error, command: "Move anchor") }
            dragLast = next
            return
        }
        let command = DocumentCommand(name: "Move path") { document in
            for id in ids { _ = document.translateNode(id: id, documentDX: dx, documentDY: dy) }
        }
        do {
            if dragHasMutation, let dragGestureID {
                try history.coalesce(command, gestureID: dragGestureID)
            } else {
                try history.perform(command, gestureID: dragGestureID)
                dragHasMutation = true
            }
        } catch {
            presentCommandError(error, command: command.name)
        }
        dragLast = next
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if panDragLocation != nil {
            panDragLocation = nil
            return
        }
        if activeTool == .selection || activeTool == .directSelection {
            transformGesture = nil
            dragLast = nil
            dragHasMutation = false
            dragGestureID = nil
            snapIndicator = nil
            return
        }
        if activeTool == .pen, let start = penMouseDown {
            let end = documentPoint(convert(event.locationInWindow, from: nil))
            if let first = pen.anchors.first?.point, pen.anchors.count >= 2, first.distance(to: end) <= 6 / zoom {
                if let object = pen.finish(close: true) { add(object) }
            } else if start.distance(to: end) > 2 / zoom {
                pen.addSmooth(start, outgoing: end)
            } else {
                pen.addCorner(start)
            }
            penMouseDown = nil
            penPreviewPoint = nil
            needsDisplay = true
            return
        }
        guard let start = dragStart else { return }
        dragStart = nil
        let location = convert(event.locationInWindow, from: nil)
        let end = documentPoint(location)
        let object =
            activeTool == .rectangle
            ? ShapeFactory.rectangle(from: start, to: end, constrained: event.modifierFlags.contains(.shift))
            : activeTool == .ellipse
                ? ShapeFactory.ellipse(in: Rect(minX: start.x, minY: start.y, maxX: end.x, maxY: end.y)) : nil
        if let object { add(object) }
    }
    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.option) {
            setZoom(zoom * exp(-event.scrollingDeltaY * 0.01), about: convert(event.locationInWindow, from: nil))
        } else {
            pan = Point(x: pan.x - event.scrollingDeltaX, y: pan.y - event.scrollingDeltaY)
            needsDisplay = true
        }
    }
    override func magnify(with event: NSEvent) {
        setZoom(zoom * (1 + event.magnification), about: convert(event.locationInWindow, from: nil))
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 {
            spaceDown = true
            return
        }
        if [51, 117].contains(event.keyCode), !selectedAnchors.isEmpty {
            do {
                for anchor in selectedAnchors.sorted(by: { $0.segment > $1.segment }) {
                    try history.perform(
                        SceneCommands.deleteAnchor(
                            pathID: anchor.pathID,
                            subpath: anchor.subpath, segment: anchor.segment))
                }
                selectedAnchors.removeAll()
                selectedControl = nil
            } catch { presentCommandError(error, command: "Delete anchor") }
            return
        }
        if activeTool == .pen, event.keyCode == 36 {
            if let object = pen.finish(close: false) { add(object) }
            penPreviewPoint = nil
            return
        }
        if activeTool == .pen, event.keyCode == 53 {
            pen.reset()
            penPreviewPoint = nil
            needsDisplay = true
            return
        }
        super.keyDown(with: event)
    }
    override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 {
            spaceDown = false
            return
        }
        super.keyUp(with: event)
    }
    private func documentPoint(_ viewPoint: NSPoint) -> Point {
        Point(x: (viewPoint.x - 24 - pan.x) / zoom, y: (viewPoint.y - 24 - pan.y) / zoom)
    }
    private func setZoom(_ requested: Double, about viewPoint: NSPoint) {
        let next = TransformInteractions.clampedZoom(requested)
        let screen = Point(x: viewPoint.x - 24, y: viewPoint.y - 24)
        if let nextPan = TransformInteractions.zoomAbout(screenPoint: screen, oldZoom: zoom, newZoom: next, oldPan: pan)
        {
            zoom = next
            pan = nextPan
            needsDisplay = true
        }
    }
    func zoomIn() { setZoom(zoom * 1.25, about: NSPoint(x: bounds.midX, y: bounds.midY)) }
    func zoomOut() { setZoom(zoom / 1.25, about: NSPoint(x: bounds.midX, y: bounds.midY)) }
    func actualSize() { setZoom(1, about: NSPoint(x: bounds.midX, y: bounds.midY)) }
    func zoomToFit() {
        let availableWidth = Double(max(1, bounds.width - 48))
        let availableHeight = Double(max(1, bounds.height - 48))
        zoom = TransformInteractions.clampedZoom(
            min(availableWidth / history.document.width, availableHeight / history.document.height))
        pan = Point(
            x: (availableWidth - history.document.width * zoom) / 2,
            y: (availableHeight - history.document.height * zoom) / 2)
        needsDisplay = true
    }
    func toggleSnapping() {
        snappingEnabled.toggle()
        snapIndicator = nil
        needsDisplay = true
    }
    private func selectionBounds() -> Rect? {
        selectedIDs.compactMap { history.document.visualBounds(for: $0) }
            .reduce(nil) { partial, next in partial.map { $0.union(next) } ?? next }
    }
    private func handlePoints(_ bounds: Rect) -> [(TransformHandle, Point)] {
        [
            (.topLeft, Point(x: bounds.minX, y: bounds.minY)), (.top, Point(x: bounds.center.x, y: bounds.minY)),
            (.topRight, Point(x: bounds.maxX, y: bounds.minY)), (.right, Point(x: bounds.maxX, y: bounds.center.y)),
            (.bottomRight, Point(x: bounds.maxX, y: bounds.maxY)), (.bottom, Point(x: bounds.center.x, y: bounds.maxY)),
            (.bottomLeft, Point(x: bounds.minX, y: bounds.maxY)), (.left, Point(x: bounds.minX, y: bounds.center.y)),
        ]
    }
    private func oppositePoint(_ handle: TransformHandle, _ bounds: Rect) -> Point {
        switch handle {
        case .topLeft: Point(x: bounds.maxX, y: bounds.maxY)
        case .top: Point(x: bounds.center.x, y: bounds.maxY)
        case .topRight: Point(x: bounds.minX, y: bounds.maxY)
        case .right: Point(x: bounds.minX, y: bounds.center.y)
        case .bottomRight: Point(x: bounds.minX, y: bounds.minY)
        case .bottom: Point(x: bounds.center.x, y: bounds.minY)
        case .bottomLeft: Point(x: bounds.maxX, y: bounds.minY)
        case .left: Point(x: bounds.maxX, y: bounds.center.y)
        }
    }
    private func snappedPoint(_ point: Point) -> Point {
        var xCandidates: [Double] = []
        var yCandidates: [Double] = []
        for layer in history.document.layers where layer.isVisible && !layer.isLocked {
            for node in layer.nodes where !selectedIDs.contains(node.id) {
                if let bounds = node.visualBounds {
                    xCandidates += [bounds.minX, bounds.center.x, bounds.maxX]
                    yCandidates += [bounds.minY, bounds.center.y, bounds.maxY]
                }
            }
        }
        let grid = 10.0
        xCandidates.append((point.x / grid).rounded() * grid)
        yCandidates.append((point.y / grid).rounded() * grid)
        return SnapPolicy(toleranceInScreenPoints: 6).snap(
            point, xCandidates: xCandidates, yCandidates: yCandidates, zoom: zoom)
    }
    private func add(_ object: PathObject) {
        let layerIndex = activeLayerIndex
        do {
            try history.perform(
                DocumentCommand(name: "Create object") { $0.layers[layerIndex].nodes.append(.path(object)) })
        } catch { presentCommandError(error, command: "Create object") }
        needsDisplay = true
    }
    private func createText(at point: Point) {
        let alert = NSAlert()
        alert.messageText = "Create Text"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let content = NSTextField(string: "Text")
        let font = NSTextField(string: "Helvetica")
        let size = NSTextField(string: "24")
        let stack = NSStackView(views: [
            NSTextField(labelWithString: "Content"), content,
            NSTextField(labelWithString: "Font"), font, NSTextField(labelWithString: "Size"), size,
        ])
        stack.orientation = .vertical
        stack.spacing = 5
        stack.frame = NSRect(x: 0, y: 0, width: 260, height: 150)
        alert.accessoryView = stack
        guard alert.runModal() == .alertFirstButtonReturn, let fontSize = Double(size.stringValue), fontSize > 0 else {
            return
        }
        let text = TextObject(text: content.stringValue, origin: point, fontName: font.stringValue, fontSize: fontSize)
        let layerIndex = activeLayerIndex
        do {
            try history.perform(
                DocumentCommand(name: "Create text") { $0.layers[layerIndex].nodes.append(.text(text)) })
        } catch { presentCommandError(error, command: "Create text") }
    }
    func placeEmbeddedImage(data: Data) throws {
        let image = try RasterResourceLoader().embedded(
            data: data,
            frame: Rect(minX: 40, minY: 40, maxX: 240, maxY: 240))
        let layerIndex = activeLayerIndex
        try history.perform(DocumentCommand(name: "Place image") { $0.layers[layerIndex].nodes.append(.image(image)) })
    }
    func placeLinkedImage(relativePath: String, pixelWidth: Int, pixelHeight: Int) throws {
        let image = try RasterResourceLoader().linked(
            relativePath: relativePath,
            frame: Rect(minX: 40, minY: 40, maxX: 240, maxY: 240), pixelWidth: pixelWidth, pixelHeight: pixelHeight)
        let layerIndex = activeLayerIndex
        try history.perform(
            DocumentCommand(name: "Place linked image") { $0.layers[layerIndex].nodes.append(.image(image)) })
    }
    func editSelectedProperties() {
        guard let id = selectedIDs.first else { return }
        let alert = NSAlert()
        alert.messageText = "Path Properties"
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")
        let width = NSTextField(string: "1")
        let opacity = NSTextField(string: "1")
        let dash = NSTextField(string: "")
        let fill = NSTextField(string: "#FFFFFF")
        let miter = NSTextField(string: "10")
        let cap = NSPopUpButton()
        cap.addItems(withTitles: ["Butt", "Round", "Square"])
        let join = NSPopUpButton()
        join.addItems(withTitles: ["Miter", "Round", "Bevel"])
        let swatch = NSPopUpButton()
        swatch.addItem(withTitle: "No swatch")
        swatch.addItems(withTitles: history.document.swatches.map(\.name))
        let stack = NSStackView(views: [
            NSTextField(labelWithString: "Fill #RRGGBB"), fill, NSTextField(labelWithString: "Fill swatch"), swatch,
            NSTextField(labelWithString: "Stroke width"), width, cap, join, NSTextField(labelWithString: "Miter limit"),
            miter,
            NSTextField(labelWithString: "Opacity (0–1)"), opacity, NSTextField(labelWithString: "Dash values"), dash,
        ])
        stack.orientation = .vertical
        stack.spacing = 5
        stack.frame = NSRect(x: 0, y: 0, width: 260, height: 300)
        alert.accessoryView = stack
        guard alert.runModal() == .alertFirstButtonReturn, let strokeWidth = Double(width.stringValue),
            let alpha = Double(opacity.stringValue), let miterLimit = Double(miter.stringValue),
            let fillColor = parseColor(fill.stringValue)
        else { return }
        let dashes = dash.stringValue.split(separator: ",").compactMap {
            Double($0.trimmingCharacters(in: .whitespaces))
        }
        let lineCap: LineCap = [.butt, .round, .square][cap.indexOfSelectedItem]
        let lineJoin: LineJoin = [.miter, .round, .bevel][join.indexOfSelectedItem]
        let swatchID =
            swatch.indexOfSelectedItem > 0 ? history.document.swatches[swatch.indexOfSelectedItem - 1].id : nil
        do {
            try history.perform(
                DocumentCommand(name: "Edit properties") { document in
                    guard
                        document.mutatePath(
                            id: id,
                            { path in
                                path.style.strokeWidth = strokeWidth
                                path.style.opacity = alpha
                                path.style.dash = dashes
                                path.style.fill = fillColor
                                path.style.fillSwatchID = swatchID
                                path.style.lineCap = lineCap
                                path.style.lineJoin = lineJoin
                                path.style.miterLimit = miterLimit
                            })
                    else { throw SceneCommandError.selectionNotFound }
                })
        } catch { presentCommandError(error, command: "Edit properties") }
    }
    private func parseColor(_ value: String) -> SRGBColor? {
        guard value.count == 7, value.first == "#", let raw = Int(value.dropFirst(), radix: 16) else { return nil }
        return SRGBColor(
            red: Double((raw >> 16) & 255) / 255,
            green: Double((raw >> 8) & 255) / 255, blue: Double(raw & 255) / 255)
    }
    func alignSelectedLeft() {
        guard selectedIDs.count > 1 else { return }
        do { try history.perform(AlignmentCommands.align(pathIDs: selectedIDs, axis: .left)) } catch {
            presentCommandError(error, command: "Align left")
        }
    }
    func groupSelected() {
        guard selectedIDs.count > 1,
            let layer = history.document.layers.first(where: { layer in
                selectedIDs.allSatisfy { id in layer.nodes.contains { $0.id == id } }
            })
        else { return }
        do {
            try history.perform(SceneCommands.group(layerID: layer.id, nodeIDs: selectedIDs))
            selectedIDs.removeAll()
        } catch { presentCommandError(error, command: "Group") }
    }
    func ungroupSelected() {
        guard selectedIDs.count == 1, let id = selectedIDs.first,
            let layer = history.document.layers.first(where: { $0.nodes.contains { $0.id == id } })
        else { return }
        do {
            try history.perform(SceneCommands.ungroup(layerID: layer.id, groupID: id))
            selectedIDs.removeAll()
        } catch { presentCommandError(error, command: "Ungroup") }
    }
    func makeCompoundSelected() {
        guard selectedIDs.count > 1,
            let layer = history.document.layers.first(where: { layer in
                selectedIDs.allSatisfy { id in layer.nodes.contains { $0.id == id } }
            })
        else { return }
        do {
            try history.perform(SceneCommands.makeCompound(layerID: layer.id, pathIDs: selectedIDs))
            selectedIDs.removeAll()
        } catch { presentCommandError(error, command: "Make compound") }
    }
    func releaseCompoundSelected() {
        guard selectedIDs.count == 1, let id = selectedIDs.first,
            let layer = history.document.layers.first(where: { $0.nodes.contains { $0.id == id } })
        else { return }
        do {
            try history.perform(SceneCommands.releaseCompound(layerID: layer.id, pathID: id))
            selectedIDs.removeAll()
        } catch { presentCommandError(error, command: "Release compound") }
    }
    func editLayers() {
        let alert = NSAlert()
        alert.messageText = "Layers"
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Add Layer")
        alert.addButton(withTitle: "Cancel")
        let popup = NSPopUpButton()
        popup.addItems(withTitles: history.document.layers.map(\.name))
        popup.selectItem(at: activeLayerIndex)
        let name = NSTextField(string: history.document.layers[activeLayerIndex].name)
        let visible = NSButton(checkboxWithTitle: "Visible", target: nil, action: nil)
        let locked = NSButton(checkboxWithTitle: "Locked", target: nil, action: nil)
        visible.state = history.document.layers[activeLayerIndex].isVisible ? .on : .off
        locked.state = history.document.layers[activeLayerIndex].isLocked ? .on : .off
        let order = NSSegmentedControl(
            labels: ["Move Up", "Move Down"], trackingMode: .selectOne, target: nil, action: nil)
        let stack = NSStackView(views: [popup, name, visible, locked, order])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.frame = NSRect(x: 0, y: 0, width: 250, height: 150)
        alert.accessoryView = stack
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            do {
                try history.perform(
                    DocumentCommand(name: "Add layer") { $0.layers.append(Layer(name: "Layer \($0.layers.count + 1)")) }
                )
                activeLayerIndex = history.document.layers.count - 1
            } catch { presentCommandError(error, command: "Add layer") }
            return
        }
        guard response == .alertFirstButtonReturn else { return }
        let index = popup.indexOfSelectedItem
        let nextName = name.stringValue
        let nextVisible = visible.state == .on
        let nextLocked = locked.state == .on
        let moveDirection = order.selectedSegment
        do {
            try history.perform(
                DocumentCommand(name: "Edit layer") { document in
                    document.layers[index].name = nextName
                    document.layers[index].isVisible = nextVisible
                    document.layers[index].isLocked = nextLocked
                    if moveDirection == 0, index > 0 { document.layers.swapAt(index, index - 1) }
                    if moveDirection == 1, index + 1 < document.layers.count {
                        document.layers.swapAt(index, index + 1)
                    }
                })
            activeLayerIndex = min(index, history.document.layers.count - 1)
        } catch { presentCommandError(error, command: "Edit layer") }
    }
    func editGradient() {
        guard let pathID = selectedIDs.first else { return }
        let alert = NSAlert()
        alert.messageText = "Gradient"
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")
        let kind = NSPopUpButton()
        kind.addItems(withTitles: ["Linear", "Radial"])
        let start = NSTextField(string: "0,0")
        let end = NSTextField(string: "100,0")
        let stops = NSTextField(string: "0:#000000, 1:#FFFFFF")
        let stack = NSStackView(views: [
            kind, NSTextField(labelWithString: "Start x,y"), start,
            NSTextField(labelWithString: "End x,y"), end, NSTextField(labelWithString: "Stops offset:#RRGGBB"), stops,
        ])
        stack.orientation = .vertical
        stack.spacing = 5
        stack.frame = NSRect(x: 0, y: 0, width: 280, height: 180)
        alert.accessoryView = stack
        guard alert.runModal() == .alertFirstButtonReturn,
            let startPoint = parsePoint(start.stringValue), let endPoint = parsePoint(end.stringValue),
            let parsedStops = parseStops(stops.stringValue), parsedStops.count >= 2
        else { return }
        let gradient = GradientResource(
            name: "Gradient", kind: kind.indexOfSelectedItem == 0 ? .linear : .radial,
            start: startPoint, end: endPoint, stops: parsedStops)
        do {
            try history.perform(
                DocumentCommand(name: "Apply gradient") { document in
                    document.gradients.append(gradient)
                    guard document.mutatePath(id: pathID, { $0.style.fillGradientID = gradient.id })
                    else { throw SceneCommandError.selectionNotFound }
                })
        } catch { presentCommandError(error, command: "Apply gradient") }
    }
    private func parsePoint(_ value: String) -> Point? {
        let pieces = value.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        return pieces.count == 2 ? Point(x: pieces[0], y: pieces[1]) : nil
    }
    private func parseStops(_ value: String) -> [ColorStop]? {
        let result = value.split(separator: ",").compactMap { item -> ColorStop? in
            let pieces = item.split(separator: ":", maxSplits: 1)
            guard pieces.count == 2, let offset = Double(pieces[0].trimmingCharacters(in: .whitespaces)),
                offset >= 0, offset <= 1
            else { return nil }
            let hex = pieces[1].trimmingCharacters(in: .whitespaces)
            guard hex.count == 7, hex.first == "#", let raw = Int(hex.dropFirst(), radix: 16) else { return nil }
            return ColorStop(
                offset: offset,
                color: SRGBColor(
                    red: Double((raw >> 16) & 255) / 255,
                    green: Double((raw >> 8) & 255) / 255, blue: Double(raw & 255) / 255))
        }.sorted { $0.offset < $1.offset }
        return result.count == value.split(separator: ",").count ? result : nil
    }
    func undo() {
        history.undo()
        needsDisplay = true
    }
    func redo() {
        history.redo()
        needsDisplay = true
    }
    func applyAccentStyle() {
        guard let id = selectedIDs.first ?? history.document.layers.first?.nodes.last?.id else { return }
        do {
            try history.perform(
                DocumentCommand(name: "Apply style") { document in
                    _ = document.mutatePath(id: id) {
                        $0.style.stroke = SRGBColor(red: 0.85, green: 0.18, blue: 0.35)
                        $0.style.strokeWidth = 6
                    }
                })
        } catch { presentCommandError(error, command: "Apply style") }
        needsDisplay = true
    }
    private func presentCommandError(_ error: Error, command: String) {
        Diagnostics.documents.error(
            "Command \(command, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        NSAlert(error: error).runModal()
    }
    func replaceDocument(_ document: EditorDocument) {
        history = CommandHistory(document: document)
        subscribeToChanges()
        selectedIDs.removeAll()
        selectedAnchors.removeAll()
        activeLayerIndex = 0
        needsDisplay = true
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var canvas: CanvasView?
    private var autosaveTimer: Timer?
    private var currentURL: URL?
    private let recoveryID = "active-document"
    private let unsavedCoordinator = UnsavedChangesCoordinator()
    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.installCrashContext()
        let frame = NSRect(x: 0, y: 0, width: 800, height: 620)
        let window = NSWindow(
            contentRect: frame, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
            defer: false)
        window.title = "OpenDraw"
        let document: EditorDocument
        do { document = try EditorDocument.sample() } catch {
            NSAlert(error: error).runModal()
            NSApp.terminate(nil)
            return
        }
        var launchDocument = document
        if let recovered = try? RecoveryStore.applicationSupport().recover(documentID: recoveryID, newerThan: nil) {
            let alert = NSAlert()
            alert.messageText = "Recover unsaved drawing?"
            alert.informativeText = "A newer autosave was found."
            alert.addButton(withTitle: "Restore")
            alert.addButton(withTitle: "Discard")
            if alert.runModal() == .alertFirstButtonReturn {
                launchDocument = recovered
            } else {
                try? RecoveryStore.applicationSupport().discard(documentID: recoveryID)
            }
        }
        let canvas = CanvasView(frame: frame, document: launchDocument)
        window.contentView = canvas
        self.canvas = canvas
        let toolbar = NSToolbar(identifier: "tools")
        toolbar.delegate = self
        window.toolbar = toolbar
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: RecoverySettings.defaultInterval, repeats: true) {
            [weak self] _ in Task { @MainActor in self?.writeRecoveryIfDirty() }
        }
        NSApp.activate(ignoringOtherApps: true)
    }
    private func writeRecoveryIfDirty() {
        guard let canvas, canvas.history.isDirty else { return }
        try? RecoveryStore.applicationSupport().save(canvas.history.document, documentID: recoveryID)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let canvas else { return .terminateNow }
        do {
            let proceed = try unsavedCoordinator.resolve(
                isDirty: canvas.history.isDirty, decision: unsavedDecision, save: { try saveNative(canvas) },
                operation: {})
            return proceed ? .terminateNow : .terminateCancel
        } catch {
            NSAlert(error: error).runModal()
            return .terminateCancel
        }
    }
    private func unsavedDecision() -> UnsavedResolution {
        let alert = NSAlert()
        alert.messageText = "Save changes?"
        alert.informativeText = "Your drawing has unsaved changes."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .save
        case .alertSecondButtonReturn: return .discard
        default: return .cancel
        }
    }
}

extension AppDelegate: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .new, .open, .save, .export, .undo, .redo, .selection, .directSelection, .pen, .rectangle, .ellipse, .text,
            .image, .style, .properties, .zoomOut, .actualSize, .zoomIn, .zoomFit,
            .alignLeft, .group, .ungroup, .makeCompound, .releaseCompound, .layers, .gradient,
            .snap,
        ]
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }
    func toolbar(
        _ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = id.rawValue.capitalized
        item.target = self
        item.action = #selector(toolbarAction(_:))
        return item
    }
    @objc private func toolbarAction(_ sender: NSToolbarItem) {
        guard let canvas else { return }
        switch sender.itemIdentifier {
        case .new: newDocument()
        case .open: openDocument()
        case .selection: canvas.activeTool = .selection
        case .directSelection: canvas.activeTool = .directSelection
        case .pen: canvas.activeTool = .pen
        case .rectangle: canvas.activeTool = .rectangle
        case .ellipse: canvas.activeTool = .ellipse
        case .text: canvas.activeTool = .text
        case .image: placeImage()
        case .undo: canvas.undo()
        case .redo: canvas.redo()
        case .style: canvas.applyAccentStyle()
        case .properties: canvas.editSelectedProperties()
        case .alignLeft: canvas.alignSelectedLeft()
        case .group: canvas.groupSelected()
        case .ungroup: canvas.ungroupSelected()
        case .makeCompound: canvas.makeCompoundSelected()
        case .releaseCompound: canvas.releaseCompoundSelected()
        case .layers: canvas.editLayers()
        case .gradient: canvas.editGradient()
        case .snap: canvas.toggleSnapping()
        case .zoomIn: canvas.zoomIn()
        case .zoomOut: canvas.zoomOut()
        case .actualSize: canvas.actualSize()
        case .zoomFit: canvas.zoomToFit()
        case .save:
            do { try saveNative(canvas) } catch { NSAlert(error: error).runModal() }
        case .export: save(canvas, svg: true)
        default: break
        }
    }
    private func placeImage() {
        guard let canvas else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .tiff]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try BoundedFileReader().read(url, maximumBytes: RasterResourceLoader.maximumBytes)
            let validated = try RasterResourceLoader().embedded(
                data: data,
                frame: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1))
            let choice = NSAlert()
            choice.messageText = "Place Image"
            choice.addButton(withTitle: "Embed")
            choice.addButton(withTitle: "Link")
            choice.addButton(withTitle: "Cancel")
            switch choice.runModal() {
            case .alertFirstButtonReturn: try canvas.placeEmbeddedImage(data: data)
            case .alertSecondButtonReturn:
                guard let root = currentURL?.deletingLastPathComponent(), url.deletingLastPathComponent() == root else {
                    throw ImageApprovalError.pathEscape
                }
                _ = try LinkedResourceResolver(root: root).resolve(url.lastPathComponent)
                try canvas.placeLinkedImage(
                    relativePath: url.lastPathComponent,
                    pixelWidth: validated.pixelWidth, pixelHeight: validated.pixelHeight)
            default: return
            }
        } catch { NSAlert(error: error).runModal() }
    }
    private func saveNative(_ canvas: CanvasView, forceSaveAs: Bool = false) throws {
        var destination = forceSaveAs ? nil : currentURL
        if destination == nil {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "Drawing.odraw"
            guard panel.runModal() == .OK, let url = panel.url else { throw CocoaError(.userCancelled) }
            destination = url
        }
        let url = destination!
        try NativeDocumentCodec().saveAtomically(canvas.history.document, to: url)
        canvas.history.markSaved()
        currentURL = url
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        try? RecoveryStore.applicationSupport().discard(documentID: recoveryID)
    }
    private func newDocument() {
        guard let canvas else { return }
        do {
            _ = try unsavedCoordinator.resolve(
                isDirty: canvas.history.isDirty, decision: unsavedDecision, save: { try saveNative(canvas) }
            ) {
                guard let document = try promptForNewDocument() else { return }
                canvas.replaceDocument(document)
                currentURL = nil
            }
        } catch { NSAlert(error: error).runModal() }
    }
    private func promptForNewDocument() throws -> EditorDocument? {
        let alert = NSAlert()
        alert.messageText = "New Drawing"
        alert.informativeText = "Enter the artboard size in points."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let width = NSTextField(string: "640")
        let height = NSTextField(string: "480")
        width.placeholderString = "Width"
        height.placeholderString = "Height"
        let stack = NSStackView(views: [
            NSTextField(labelWithString: "Width"), width,
            NSTextField(labelWithString: "Height"), height,
        ])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.frame = NSRect(x: 0, y: 0, width: 240, height: 100)
        alert.accessoryView = stack
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        guard let w = Double(width.stringValue), let h = Double(height.stringValue), w > 0, h > 0 else {
            throw EditorError.invalidValue("Artboard dimensions must be positive numbers")
        }
        return try EditorDocument(width: w, height: h)
    }
    private func save(_ canvas: CanvasView, svg: Bool) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = svg ? "Drawing.svg" : "Drawing.odraw"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if svg {
                let result = try SVGExporter().export(canvas.history.document)
                if !result.warnings.isEmpty {
                    let alert = NSAlert()
                    alert.messageText = "Review export limitations"
                    alert.informativeText = result.warnings.map(\.message).joined(separator: "\n")
                    alert.addButton(withTitle: "Export")
                    alert.addButton(withTitle: "Cancel")
                    guard alert.runModal() == .alertFirstButtonReturn else { return }
                }
                try DurableFileWriter().write(result.data, to: url)
            } else {
                try saveNative(canvas, forceSaveAs: true)
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
    private func openDocument() {
        guard let canvas else { return }
        do {
            _ = try unsavedCoordinator.resolve(
                isDirty: canvas.history.isDirty, decision: unsavedDecision, save: { try saveNative(canvas) }
            ) {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                guard panel.runModal() == .OK, let url = panel.url else { return }
                let document =
                    url.pathExtension.lowercased() == "svg"
                    ? try SVGImporter().importFile(url).document : try NativeDocumentCodec().load(from: url)
                canvas.replaceDocument(document)
                currentURL = url
                NSDocumentController.shared.noteNewRecentDocumentURL(url)
            }
        } catch { NSAlert(error: error).runModal() }
    }
}

extension AppDelegate: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        guard let canvas else { return false }
        switch item.itemIdentifier {
        case .undo: return canvas.history.canUndo
        case .redo: return canvas.history.canRedo
        case .style, .properties, .gradient: return canvas.hasSelection
        case .alignLeft, .group, .makeCompound: return canvas.hasMultipleSelection
        case .ungroup, .releaseCompound: return canvas.hasSelection
        default: return true
        }
    }
}

extension NSToolbarItem.Identifier {
    static let new = Self("new"), open = Self("open"), save = Self("save"), export = Self("export"),
        undo = Self("undo"),
        redo = Self("redo"), selection = Self("select"), directSelection = Self("direct-select"), pen = Self("pen"),
        rectangle = Self("rectangle"),
        ellipse = Self("ellipse"), style = Self("style")
    static let text = Self("text"), image = Self("image"), properties = Self("properties")
    static let alignLeft = Self("align-left"), group = Self("group")
    static let ungroup = Self("ungroup"), makeCompound = Self("make-compound"),
        releaseCompound = Self("release-compound")
    static let layers = Self("layers")
    static let gradient = Self("gradient")
    static let snap = Self("snap")
    static let zoomIn = Self("zoom-in"), zoomOut = Self("zoom-out"), actualSize = Self("zoom-100"),
        zoomFit = Self("zoom-fit")
}

if CommandLine.arguments.contains("--smoke") {
    do {
        let codec = NativeDocumentCodec()
        var document = try EditorDocument.sample()
        for _ in 0..<100 { document = try codec.decode(codec.encode(document)) }
        print("OpenDraw smoke: 100 native round trips passed")
        exit(EXIT_SUCCESS)
    } catch {
        fputs("OpenDraw smoke failed: \(error)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
