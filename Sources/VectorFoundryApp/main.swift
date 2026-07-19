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

private let processStartupStart = ProcessInfo.processInfo.systemUptime
private let startupProbeEnabled = CommandLine.arguments.contains("--startup-probe")

private func registerEmbeddedAssets(
    in document: EditorDocument, with store: ApprovedAssetStore
) {
    func register(_ node: SceneNode) {
        switch node {
        case .image(let image):
            if case .embedded(let data) = image.storage {
                store.registerApproved(data)
            }
        case .group(let group):
            group.children.forEach(register)
        default:
            break
        }
    }
    document.layers.flatMap(\.nodes).forEach(register)
}

@MainActor
final class CanvasView: NSView, NSTextFieldDelegate {
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
    private enum TextEditTarget {
        case new(Point)
        case existing(ObjectID)
    }
    var history: DeltaCommandHistory
    private let assetStore: ApprovedAssetStore
    var activeTool: ActiveTool = .pen {
        didSet { onToolChange?(activeTool) }
    }
    private var pen = SmoothPenToolState()
    private var penMouseDown: Point?
    private var penPreviewPoint: Point?
    private var dragStart: Point?
    private var dragLast: Point?
    private var marqueeOrigin: Point?
    private var marqueeCurrent: Point?
    private var marqueeBaseSelection: Set<ObjectID> = []
    private var selectedIDs: Set<ObjectID> = [] {
        didSet {
            guard selectedIDs != oldValue else { return }
            onSelectionChange?()
        }
    }
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
    private var rotationReadout: (pointer: NSPoint, degrees: Double)?
    private var rotationDeltaRadians = 0.0
    private var inlineTextField: NSTextField?
    private var textEditTarget: TextEditTarget?
    private var isCommittingInlineText = false
    private let renderer = TileCompositeRenderer()
    private var isZoomGestureActive = false
    private var zoomSettleTask: Task<Void, Never>?
    private var changeTask: Task<Void, Never>?
    var onSelectionChange: (() -> Void)?
    var onDocumentChange: (() -> Void)?
    var onToolChange: ((ActiveTool) -> Void)?
    var onZoomChange: ((Double) -> Void)?
    init(frame: NSRect, document: EditorDocument) throws {
        let assetStore = ApprovedAssetStore()
        registerEmbeddedAssets(in: document, with: assetStore)
        self.assetStore = assetStore
        history = try DeltaCommandHistory(document: document, assetStore: assetStore)
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("OpenDraw document canvas")
        renderer.subscribe(to: history)
        subscribeToChanges()
    }
    required init?(coder: NSCoder) { nil }
    var hasSelection: Bool { !selectedIDs.isEmpty }
    var hasMultipleSelection: Bool { selectedIDs.count > 1 }
    deinit {
        changeTask?.cancel()
        zoomSettleTask?.cancel()
    }
    private func subscribeToChanges() {
        changeTask?.cancel()
        let stream = history.changes()
        changeTask = Task { @MainActor [weak self] in
            for await _ in stream {
                self?.needsDisplay = true
                self?.onDocumentChange?()
            }
        }
    }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        Theme.Color.workspace.setFill()
        dirtyRect.fill()
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: 24 + pan.x, y: 24 + pan.y)
        context.scaleBy(x: zoom, y: zoom)
        context.setFillColor(Theme.Color.artboard.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: history.document.width, height: history.document.height))
        renderDocument(in: context, dirtyRect: dirtyRect)
        if activeTool == .directSelection { drawDirectSelectionChrome(in: context) }
        if activeTool == .selection, let bounds = selectionBounds() {
            drawSelectionChrome(bounds: bounds, in: context)
        }
        if let marqueeOrigin, let marqueeCurrent {
            drawMarquee(from: marqueeOrigin, to: marqueeCurrent, in: context)
        }
        if let snapIndicator {
            context.setStrokeColor(Theme.Color.guideSnap.cgColor)
            context.setLineWidth(Theme.Metric.snapGuideLineWidth / zoom)
            context.move(to: CGPoint(x: 0, y: snapIndicator.y))
            context.addLine(to: CGPoint(x: history.document.width, y: snapIndicator.y))
            context.move(to: CGPoint(x: snapIndicator.x, y: 0))
            context.addLine(to: CGPoint(x: snapIndicator.x, y: history.document.height))
            let crossRadius = Theme.Metric.snapGuideCrossSpan / 2 / zoom
            context.move(to: CGPoint(x: snapIndicator.x - crossRadius, y: snapIndicator.y))
            context.addLine(to: CGPoint(x: snapIndicator.x + crossRadius, y: snapIndicator.y))
            context.move(to: CGPoint(x: snapIndicator.x, y: snapIndicator.y - crossRadius))
            context.addLine(to: CGPoint(x: snapIndicator.x, y: snapIndicator.y + crossRadius))
            context.strokePath()
        }
        if activeTool == .pen, let previewPoint = penPreviewPoint, let preview = pen.preview(to: previewPoint) {
            context.setStrokeColor(Theme.Color.accent.cgColor)
            context.setLineWidth(Theme.Metric.penPreviewLineWidth / zoom)
            context.move(to: CGPoint(x: preview.start.x, y: preview.start.y))
            context.addCurve(
                to: CGPoint(x: preview.end.x, y: preview.end.y),
                control1: CGPoint(x: preview.control1.x, y: preview.control1.y),
                control2: CGPoint(x: preview.control2.x, y: preview.control2.y))
            context.strokePath()
        }
        context.restoreGState()
        drawRotationReadout()
    }

    private func drawDirectSelectionChrome(in context: CGContext) {
        let anchorSize = Theme.Metric.anchorSize / zoom
        let directionSize = Theme.Metric.directionDotSize / zoom
        context.setLineWidth(Theme.Metric.directionStemWidth / zoom)
        for id in selectedIDs {
            guard let path = history.document.path(id: id) else { continue }
            for (subpathIndex, subpath) in path.path.subpaths.enumerated() {
                for (segmentIndex, segment) in subpath.segments.enumerated() {
                    let reference = AnchorRef(pathID: id, subpath: subpathIndex, segment: segmentIndex)
                    let location = PathAnchorLocation(
                        pathID: id, subpathIndex: subpathIndex, anchorIndex: segmentIndex)
                    guard let anchor = history.document.documentPoint(pathID: id, localPoint: segment.start),
                        let slice = try? AnchorGeometryCommands.slice(in: history.document, at: location)
                    else { continue }
                    let selected = selectedAnchors.contains(reference)
                    context.setFillColor(
                        (selected ? Theme.Color.anchorSelectedFill : Theme.Color.handleFill).cgColor)
                    context.setStrokeColor(
                        (selected ? Theme.Color.anchorSelectedStroke : Theme.Color.handleStroke).cgColor)
                    let anchorRect = CGRect(
                        x: anchor.x - anchorSize / 2, y: anchor.y - anchorSize / 2,
                        width: anchorSize, height: anchorSize)
                    if AnchorGeometryCommands.isSmooth(slice) {
                        context.fillEllipse(in: anchorRect)
                        context.strokeEllipse(in: anchorRect)
                    } else {
                        context.fill(anchorRect)
                        context.stroke(anchorRect)
                    }
                    guard
                        let control1 = history.document.documentPoint(pathID: id, localPoint: segment.control1),
                        let control2 = history.document.documentPoint(pathID: id, localPoint: segment.control2)
                    else { continue }
                    context.setStrokeColor(Theme.Color.directionStem.cgColor)
                    context.move(to: CGPoint(x: anchor.x, y: anchor.y))
                    context.addLine(to: CGPoint(x: control1.x, y: control1.y))
                    context.addLine(to: CGPoint(x: control2.x, y: control2.y))
                    context.strokePath()
                    context.setFillColor(Theme.Color.handleFill.cgColor)
                    context.setStrokeColor(Theme.Color.handleStroke.cgColor)
                    for control in [control1, control2] {
                        let rect = CGRect(
                            x: control.x - directionSize / 2, y: control.y - directionSize / 2,
                            width: directionSize, height: directionSize)
                        context.fillEllipse(in: rect)
                        context.strokeEllipse(in: rect)
                    }
                }
            }
        }
    }

    private func drawSelectionChrome(bounds: Rect, in context: CGContext) {
        context.setStrokeColor(Theme.Color.accent.cgColor)
        context.setLineWidth(Theme.Metric.selectionBoundsLineWidth / zoom)
        context.stroke(CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height))
        let handleSize = Theme.Metric.selectionHandleSize / zoom
        context.setFillColor(Theme.Color.handleFill.cgColor)
        context.setStrokeColor(Theme.Color.handleStroke.cgColor)
        context.setLineWidth(Theme.Metric.selectionHandleStrokeWidth / zoom)
        for (_, point) in handlePoints(bounds) {
            let rect = CGRect(
                x: point.x - handleSize / 2, y: point.y - handleSize / 2,
                width: handleSize, height: handleSize)
            context.fill(rect)
            context.stroke(rect)
        }
        let rotation = Point(x: bounds.center.x, y: bounds.minY - Theme.Metric.rotationStemOffset / zoom)
        let ringSize = Theme.Metric.rotationRingSize / zoom
        context.setLineWidth(Theme.Metric.selectionBoundsLineWidth / zoom)
        context.move(to: CGPoint(x: bounds.center.x, y: bounds.minY))
        context.addLine(to: CGPoint(x: rotation.x, y: rotation.y + ringSize / 2))
        context.strokePath()
        let ring = CGRect(
            x: rotation.x - ringSize / 2, y: rotation.y - ringSize / 2,
            width: ringSize, height: ringSize)
        context.fillEllipse(in: ring)
        context.strokeEllipse(in: ring)
    }

    private func drawMarquee(from start: Point, to end: Point, in context: CGContext) {
        let rect = CGRect(
            x: min(start.x, end.x), y: min(start.y, end.y),
            width: abs(end.x - start.x), height: abs(end.y - start.y))
        context.setFillColor(Theme.Color.marqueeFill.cgColor)
        context.fill(rect)
        context.setStrokeColor(Theme.Color.accent.cgColor)
        context.setLineWidth(Theme.Metric.marqueeLineWidth / zoom)
        context.stroke(rect)
    }

    private func drawRotationReadout() {
        guard let rotationReadout else { return }
        let roundedDegrees = String(format: "%.1f", rotationReadout.degrees)
            .replacingOccurrences(of: ".0", with: "")
        let text = "Δ \(roundedDegrees)°" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Theme.Font.badge,
            .foregroundColor: Theme.Color.badgeReadoutText,
        ]
        let textSize = text.size(withAttributes: attributes)
        let origin = NSPoint(
            x: rotationReadout.pointer.x + Theme.Metric.badgePointerOffset,
            y: rotationReadout.pointer.y + Theme.Metric.badgePointerOffset)
        let badge = NSRect(
            x: origin.x, y: origin.y,
            width: textSize.width + 2 * Theme.Metric.badgeHorizontalInset,
            height: textSize.height + 2 * Theme.Metric.badgeVerticalInset)
        Theme.Color.badgeReadoutBackground.setFill()
        NSBezierPath(
            roundedRect: badge,
            xRadius: Theme.Metric.badgeCornerRadius,
            yRadius: Theme.Metric.badgeCornerRadius
        ).fill()
        text.draw(
            at: NSPoint(
                x: badge.minX + Theme.Metric.badgeHorizontalInset,
                y: badge.minY + Theme.Metric.badgeVerticalInset),
            withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        if inlineTextField != nil { commitInlineTextEditing() }
        let location = convert(event.locationInWindow, from: nil)
        if spaceDown {
            panDragLocation = location
            return
        }
        let point = documentPoint(location)
        if activeTool == .selection, let bounds = selectionBounds() {
            if let handle = handlePoints(bounds).first(where: {
                $0.1.distance(to: point) <= Theme.HitTarget.transformHandleRadius / zoom
            })?.0 {
                transformGesture = .scale(handle)
                dragLast = point
                dragHasMutation = false
                dragGestureID = nil
                return
            }
            let rotation = Point(
                x: bounds.center.x,
                y: bounds.minY - Double(Theme.Metric.rotationStemOffset) / zoom)
            if rotation.distance(to: point) <= Theme.HitTarget.rotationRadius / zoom {
                transformGesture = .rotate
                dragLast = point
                dragHasMutation = false
                dragGestureID = nil
                rotationDeltaRadians = 0
                return
            }
        }
        if activeTool == .text {
            let hit = SelectionTool().hitTest(history.document, pointer: point, zoom: zoom)
            if let hit, case .text? = try? StructuralCommands.slot(for: hit, in: history.document).node {
                beginInlineTextEditing(existing: hit)
            } else {
                beginInlineTextEditing(newAt: point)
            }
        } else if activeTool == .pen {
            penMouseDown = point
            penPreviewPoint = point
        } else if activeTool == .selection || activeTool == .directSelection {
            let hit = SelectionTool().hitTest(history.document, pointer: point, zoom: zoom)
            selectedControl = nil
            selectedAnchors.removeAll()
            if activeTool == .selection, hit == nil {
                marqueeOrigin = point
                marqueeCurrent = nil
                marqueeBaseSelection = event.modifierFlags.contains(.shift) ? selectedIDs : []
                selectedIDs = marqueeBaseSelection
                dragLast = nil
                needsDisplay = true
                return
            }
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
                                if distance <= Theme.HitTarget.anchorRadius / zoom,
                                    distance < nearestControl?.1 ?? .infinity
                                {
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
                        if distance <= Theme.HitTarget.anchorRadius / zoom,
                            distance < nearest?.1 ?? .infinity
                        {
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
            dragGestureID = nil
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
        let location = convert(event.locationInWindow, from: nil)
        let rawNext = documentPoint(location)
        if let marqueeOrigin {
            if MarqueeInteraction.hasCrossedThreshold(
                start: marqueeOrigin, current: rawNext, zoom: zoom,
                thresholdInScreenPoints: Double(Theme.Metric.marqueeDragThreshold))
            {
                marqueeCurrent = rawNext
                needsDisplay = true
            }
            return
        }
        guard !selectedIDs.isEmpty, let prior = dragLast else { return }
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
                        radians: delta,
                        constrain: TransformInteractions.shouldSnapRotation(
                            globalSnapEnabled: snappingEnabled,
                            shiftHeld: event.modifierFlags.contains(.shift))))
                if let documentTransform {
                    rotationDeltaRadians += atan2(documentTransform.b, documentTransform.a)
                    rotationReadout = (
                        pointer: location,
                        degrees: rotationDeltaRadians * 180 / .pi
                    )
                }
            }
            if let documentTransform {
                do {
                    if dragGestureID == nil {
                        dragGestureID = try history.beginTransformGesture(nodeIDs: selectedIDs)
                    }
                    try history.updateDocumentTransformGesture(
                        dragGestureID!, documentTransform: documentTransform)
                    dragHasMutation = true
                } catch {
                    cancelActiveDragGesture()
                    presentCommandError(error, command: "Transform selection")
                }
            }
            dragLast = next
            needsDisplay = true
            return
        }
        if activeTool == .directSelection, let control = selectedControl {
            do {
                let location = try anchorLocation(for: control)
                if dragGestureID == nil {
                    dragGestureID = try history.beginAnchorGesture(at: location)
                }
                var planned = history.document
                guard
                    planned.movePathControl(
                        id: control.pathID, subpath: control.subpath,
                        segment: control.segment, control: control.control,
                        documentDelta: Point(x: dx, y: dy))
                else { throw AnchorGeometryCommandError.handleNotFound }
                let current = try AnchorGeometryCommands.slice(in: history.document, at: location)
                let moved = try AnchorGeometryCommands.slice(in: planned, at: location)
                let side: PathHandleSide = control.control == 1 ? .outgoing : .incoming
                guard let movedPoint = side == .outgoing ? moved.outgoing : moved.incoming else {
                    throw AnchorGeometryCommandError.handleNotFound
                }
                try history.updateAnchorGesture(
                    dragGestureID!,
                    newValue: AnchorGeometryCommands.handleDragSlice(
                        from: current, side: side, to: movedPoint,
                        breakSmooth: event.modifierFlags.contains(.option)))
                dragHasMutation = true
            } catch {
                cancelActiveDragGesture()
                presentCommandError(error, command: "Move direction handle")
            }
            dragLast = next
            return
        }
        if activeTool == .directSelection, !selectedAnchors.isEmpty {
            do {
                let anchors = selectedAnchors.sorted(by: anchorOrder)
                let locations = anchors.map {
                    PathAnchorLocation(
                        pathID: $0.pathID, subpathIndex: $0.subpath,
                        anchorIndex: $0.segment)
                }
                if dragGestureID == nil {
                    dragGestureID = try history.beginAnchorGesture(at: locations)
                }
                var planned = history.document
                for anchor in anchors {
                    guard
                        planned.movePathAnchor(
                            id: anchor.pathID, subpath: anchor.subpath,
                            segment: anchor.segment,
                            documentDelta: Point(x: dx, y: dy))
                    else {
                        throw AnchorGeometryCommandError.anchorNotFound
                    }
                }
                var values: [PathAnchorLocation: PathAnchorSlice] = [:]
                for location in locations {
                    values[location] = try AnchorGeometryCommands.slice(
                        in: planned, at: location)
                }
                try history.updateAnchorGesture(dragGestureID!, newValues: values)
                dragHasMutation = true
            } catch {
                cancelActiveDragGesture()
                presentCommandError(error, command: "Move anchor")
            }
            dragLast = next
            return
        }
        do {
            if dragGestureID == nil {
                dragGestureID = try history.beginTransformGesture(nodeIDs: selectedIDs)
            }
            try history.updateDocumentTransformGesture(
                dragGestureID!,
                documentTransform: Geometry.AffineTransform(tx: dx, ty: dy))
            dragHasMutation = true
        } catch {
            cancelActiveDragGesture()
            presentCommandError(error, command: "Move selection")
        }
        dragLast = next
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if panDragLocation != nil {
            panDragLocation = nil
            return
        }
        if let marqueeOrigin {
            if let marqueeCurrent {
                selectedIDs = marqueeBaseSelection.union(
                    marqueeSelection(
                        in: Rect(
                            minX: marqueeOrigin.x, minY: marqueeOrigin.y,
                            maxX: marqueeCurrent.x, maxY: marqueeCurrent.y)))
            }
            self.marqueeOrigin = nil
            marqueeCurrent = nil
            marqueeBaseSelection.removeAll()
            needsDisplay = true
            return
        }
        if activeTool == .selection || activeTool == .directSelection {
            if dragHasMutation, let dragGestureID {
                do { try history.endGesture(dragGestureID) } catch {
                    cancelActiveDragGesture()
                    presentCommandError(error, command: "Commit gesture")
                }
            }
            transformGesture = nil
            dragLast = nil
            dragHasMutation = false
            dragGestureID = nil
            snapIndicator = nil
            rotationReadout = nil
            rotationDeltaRadians = 0
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
            updateZoomGestureState(for: event)
            scheduleZoomSettleIfNeeded()
            setZoom(zoom * exp(-event.scrollingDeltaY * 0.01), about: convert(event.locationInWindow, from: nil))
        } else {
            pan = Point(x: pan.x - event.scrollingDeltaX, y: pan.y - event.scrollingDeltaY)
            needsDisplay = true
        }
    }
    override func magnify(with event: NSEvent) {
        updateZoomGestureState(for: event)
        scheduleZoomSettleIfNeeded()
        setZoom(zoom * (1 + event.magnification), about: convert(event.locationInWindow, from: nil))
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 {
            spaceDown = true
            return
        }
        if event.keyCode == 53, dragGestureID != nil {
            cancelActiveDragGesture()
            transformGesture = nil
            dragLast = nil
            snapIndicator = nil
            rotationReadout = nil
            rotationDeltaRadians = 0
            needsDisplay = true
            return
        }
        if [51, 117].contains(event.keyCode), !selectedAnchors.isEmpty {
            do {
                var staged = history.document
                var children: [DocumentCommand] = []
                for anchor in selectedAnchors.sorted(by: { $0.segment > $1.segment }) {
                    guard
                        let path = staged.path(id: anchor.pathID),
                        path.path.subpaths.indices.contains(anchor.subpath),
                        path.path.subpaths[anchor.subpath].segments.count > 1
                    else { throw AnchorGeometryCommandError.invalidSegmentRange }
                    let command = try AnchorGeometryCommands.replaceSegments(
                        in: staged, pathID: anchor.pathID,
                        subpathIndex: anchor.subpath,
                        range: anchor.segment..<(anchor.segment + 1), with: [])
                    try command.apply(to: &staged)
                    children.append(command)
                }
                try history.commit(
                    CompositeCommands.ordered(
                        name: "Delete anchors", children: children))
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
    private func renderDocument(in context: CGContext, dirtyRect: NSRect) {
        let origin = NSPoint(x: 24 + pan.x, y: 24 + pan.y)
        let artboard = NSRect(
            x: origin.x, y: origin.y,
            width: history.document.width * zoom,
            height: history.document.height * zoom)
        let visibleViewRect = dirtyRect.intersection(artboard)
        guard !visibleViewRect.isEmpty else { return }
        let documentRect = Rect(
            minX: max(0, (visibleViewRect.minX - origin.x) / zoom),
            minY: max(0, (visibleViewRect.minY - origin.y) / zoom),
            maxX: min(history.document.width, (visibleViewRect.maxX - origin.x) / zoom),
            maxY: min(history.document.height, (visibleViewRect.maxY - origin.y) / zoom))
        guard documentRect.width > 0, documentRect.height > 0 else { return }
        if isZoomGestureActive {
            renderer.renderZoomGestureDirect(
                history.document, in: context,
                viewport: RenderViewport(clip: documentRect))
            return
        }
        let backingScale = window?.backingScaleFactor ?? 1
        let deviceScale = zoom * backingScale
        let visibleDeviceRect = DevicePixelRect(
            minX: Int(floor(documentRect.minX * deviceScale)),
            minY: Int(floor(documentRect.minY * deviceScale)),
            maxX: Int(ceil(documentRect.maxX * deviceScale)),
            maxY: Int(ceil(documentRect.maxY * deviceScale)))
        do {
            try renderer.compositeDocumentCoordinates(
                history.document, in: context, zoom: zoom,
                backingScale: backingScale, visibleDeviceRect: visibleDeviceRect)
        } catch {
            Diagnostics.rendering.error(
                "Tile composite failed: \(String(describing: error), privacy: .public)")
        }
    }
    private func updateZoomGestureState(for event: NSEvent) {
        if event.phase.isEmpty && event.momentumPhase.isEmpty {
            isZoomGestureActive = true
        } else if event.phase.contains(.began) || event.phase.contains(.changed)
            || event.momentumPhase.contains(.began) || event.momentumPhase.contains(.changed)
        {
            isZoomGestureActive = true
        }
        if event.phase.contains(.ended) || event.phase.contains(.cancelled)
            || event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled)
        {
            isZoomGestureActive = false
            zoomSettleTask?.cancel()
        }
    }
    private func scheduleZoomSettleIfNeeded() {
        guard isZoomGestureActive else { return }
        zoomSettleTask?.cancel()
        zoomSettleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            self?.isZoomGestureActive = false
            self?.needsDisplay = true
        }
    }
    private func anchorOrder(_ lhs: AnchorRef, _ rhs: AnchorRef) -> Bool {
        if lhs.pathID != rhs.pathID {
            return lhs.pathID.rawValue.uuidString < rhs.pathID.rawValue.uuidString
        }
        if lhs.subpath != rhs.subpath { return lhs.subpath < rhs.subpath }
        return lhs.segment < rhs.segment
    }
    private func anchorLocation(for control: ControlRef) throws -> PathAnchorLocation {
        guard let path = history.document.path(id: control.pathID),
            path.path.subpaths.indices.contains(control.subpath)
        else { throw AnchorGeometryCommandError.pathNotFound }
        let subpath = path.path.subpaths[control.subpath]
        guard subpath.segments.indices.contains(control.segment) else {
            throw AnchorGeometryCommandError.anchorNotFound
        }
        let anchorIndex: Int
        if control.control == 1 {
            anchorIndex = control.segment
        } else if subpath.isClosed {
            anchorIndex = (control.segment + 1) % subpath.segments.count
        } else {
            anchorIndex = control.segment + 1
        }
        return PathAnchorLocation(
            pathID: control.pathID, subpathIndex: control.subpath,
            anchorIndex: anchorIndex)
    }
    private func cancelActiveDragGesture() {
        if let dragGestureID {
            try? history.cancelDeltaGesture(dragGestureID)
        }
        dragGestureID = nil
        dragHasMutation = false
        rotationReadout = nil
        rotationDeltaRadians = 0
    }
    private func setZoom(_ requested: Double, about viewPoint: NSPoint) {
        let next = TransformInteractions.clampedZoom(requested)
        let screen = Point(x: viewPoint.x - 24, y: viewPoint.y - 24)
        if let nextPan = TransformInteractions.zoomAbout(screenPoint: screen, oldZoom: zoom, newZoom: next, oldPan: pan)
        {
            zoom = next
            pan = nextPan
            onZoomChange?(zoom)
            needsDisplay = true
        }
    }
    func zoomIn() {
        isZoomGestureActive = false
        setZoom(zoom * 1.25, about: NSPoint(x: bounds.midX, y: bounds.midY))
    }
    func zoomOut() {
        isZoomGestureActive = false
        setZoom(zoom / 1.25, about: NSPoint(x: bounds.midX, y: bounds.midY))
    }
    func actualSize() {
        isZoomGestureActive = false
        setZoom(1, about: NSPoint(x: bounds.midX, y: bounds.midY))
    }
    func zoomToFit() {
        isZoomGestureActive = false
        let availableWidth = Double(max(1, bounds.width - 48))
        let availableHeight = Double(max(1, bounds.height - 48))
        zoom = TransformInteractions.clampedZoom(
            min(availableWidth / history.document.width, availableHeight / history.document.height))
        pan = Point(
            x: (availableWidth - history.document.width * zoom) / 2,
            y: (availableHeight - history.document.height * zoom) / 2)
        onZoomChange?(zoom)
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
    private func marqueeSelection(in marquee: Rect) -> Set<ObjectID> {
        var result: Set<ObjectID> = []
        func collect(_ nodes: [SceneNode]) {
            for node in nodes {
                if case .group(let group) = node {
                    collect(group.children)
                } else if let bounds = history.document.visualBounds(for: node.id),
                    bounds.intersection(marquee) != nil
                {
                    result.insert(node.id)
                }
            }
        }
        for layer in history.document.layers where layer.isVisible && !layer.isLocked {
            collect(layer.nodes)
        }
        return result
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
        do {
            let layer = history.document.layers[activeLayerIndex]
            try history.commit(
                StructuralCommands.createShape(
                    object, in: history.document, parent: .layer(layer.id),
                    at: layer.nodes.count, assetStore: assetStore))
        } catch { presentCommandError(error, command: "Create object") }
        needsDisplay = true
    }
    private func beginInlineTextEditing(newAt point: Point) {
        beginInlineTextEditing(
            target: .new(point), text: "", fontName: Theme.DefaultValue.textFontName,
            fontSize: Double(Theme.Metric.inlineTextFontSize), documentBounds: nil)
    }
    private func beginInlineTextEditing(existing nodeID: ObjectID) {
        guard case .text(let text)? = try? StructuralCommands.slot(for: nodeID, in: history.document).node else {
            return
        }
        selectedIDs = [nodeID]
        beginInlineTextEditing(
            target: .existing(nodeID), text: text.text, fontName: text.fontName,
            fontSize: text.fontSize, documentBounds: history.document.visualBounds(for: nodeID))
    }
    private func beginInlineTextEditing(
        target: TextEditTarget, text: String, fontName: String, fontSize: Double,
        documentBounds: Rect?
    ) {
        commitInlineTextEditing()
        let field = NSTextField(string: text)
        field.placeholderString = "Type"
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        field.font = Theme.Font.inlineText(name: fontName, size: fontSize * zoom)
        field.textColor = Theme.Color.textPrimary
        field.delegate = self
        field.setAccessibilityLabel("In-place text editor")
        field.wantsLayer = true
        field.layer?.borderColor = Theme.Color.accent.cgColor
        field.layer?.borderWidth = Theme.Metric.inlineTextOutlineWidth
        let origin: Point
        switch target {
        case .new(let point): origin = point
        case .existing:
            origin = Point(
                x: documentBounds?.minX ?? 0,
                y: documentBounds?.minY ?? 0)
        }
        let width = max(
            Theme.Metric.inlineTextMinimumWidth,
            CGFloat(documentBounds?.width ?? 0) * zoom + 2 * Theme.Metric.badgeHorizontalInset)
        let height = max(
            Theme.Metric.inlineTextMinimumHeight,
            CGFloat(documentBounds?.height ?? fontSize) * zoom)
        field.frame = NSRect(
            x: Theme.Metric.artboardInset + pan.x + origin.x * zoom,
            y: Theme.Metric.artboardInset + pan.y + origin.y * zoom,
            width: width, height: height)
        textEditTarget = target
        inlineTextField = field
        addSubview(field)
        window?.makeFirstResponder(field)
        field.currentEditor()?.selectedRange = NSRange(location: 0, length: field.stringValue.utf16.count)
    }
    private func commitInlineTextEditing() {
        guard !isCommittingInlineText, let field = inlineTextField, let target = textEditTarget else { return }
        isCommittingInlineText = true
        let value = field.stringValue
        field.delegate = nil
        inlineTextField = nil
        textEditTarget = nil
        field.removeFromSuperview()
        defer { isCommittingInlineText = false }
        do {
            switch target {
            case .new(let point):
                let layer = history.document.layers[activeLayerIndex]
                let text = TextObject(
                    text: value, origin: point,
                    fontName: Theme.DefaultValue.textFontName,
                    fontSize: Double(Theme.Metric.inlineTextFontSize))
                if let command = try InPlaceTextEditing.createCommand(
                    text: text, in: history.document, parent: .layer(layer.id),
                    at: layer.nodes.count, assetStore: assetStore)
                {
                    try history.commit(command)
                    selectedIDs = [text.id]
                }
            case .existing(let nodeID):
                try history.commit(
                    InPlaceTextEditing.editCommand(
                        nodeID: nodeID, text: value, in: history.document))
                selectedIDs = [nodeID]
            }
        } catch { presentCommandError(error, command: "Edit text") }
        needsDisplay = true
    }
    func control(
        _ control: NSControl, textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        guard control === inlineTextField else { return false }
        if commandSelector == #selector(NSResponder.cancelOperation(_:))
            || commandSelector == #selector(NSResponder.insertNewline(_:))
        {
            commitInlineTextEditing()
            window?.makeFirstResponder(self)
            return true
        }
        return false
    }
    func controlTextDidEndEditing(_ notification: Notification) {
        guard notification.object as? NSTextField === inlineTextField else { return }
        commitInlineTextEditing()
    }
    func placeEmbeddedImage(data: Data) throws {
        let image = try RasterResourceLoader().embedded(
            data: data,
            frame: Rect(minX: 40, minY: 40, maxX: 240, maxY: 240))
        assetStore.registerApproved(data)
        let layer = history.document.layers[activeLayerIndex]
        try history.commit(
            StructuralCommands.createImage(
                image, in: history.document, parent: .layer(layer.id),
                at: layer.nodes.count, assetStore: assetStore))
    }
    func placeLinkedImage(relativePath: String, pixelWidth: Int, pixelHeight: Int) throws {
        let image = try RasterResourceLoader().linked(
            relativePath: relativePath,
            frame: Rect(minX: 40, minY: 40, maxX: 240, maxY: 240), pixelWidth: pixelWidth, pixelHeight: pixelHeight)
        let layer = history.document.layers[activeLayerIndex]
        try history.commit(
            StructuralCommands.createImage(
                image, in: history.document, parent: .layer(layer.id),
                at: layer.nodes.count, assetStore: assetStore))
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
            guard var style = history.document.path(id: id)?.style else { return }
            style.strokeWidth = strokeWidth
            style.opacity = alpha
            style.dash = dashes
            style.fill = fillColor
            style.fillSwatchID = swatchID
            style.lineCap = lineCap
            style.lineJoin = lineJoin
            style.miterLimit = miterLimit
            try history.commit(
                ValueSwapCommands.pathStyle(
                    in: history.document, nodeID: id, newValue: style))
        } catch { presentCommandError(error, command: "Edit properties") }
    }
    private func parseColor(_ value: String) -> SRGBColor? {
        guard value.count == 7, value.first == "#", let raw = Int(value.dropFirst(), radix: 16) else { return nil }
        return SRGBColor(
            red: Double((raw >> 16) & 255) / 255,
            green: Double((raw >> 8) & 255) / 255, blue: Double(raw & 255) / 255)
    }
    func alignSelectedLeft() {
        alignSelected(.left)
    }
    func alignSelected(_ axis: AlignmentAxis) {
        guard selectedIDs.count > 1 else { return }
        do {
            try history.commit(
                CompositeSceneCommands.align(
                    in: history.document, nodeIDs: selectedIDs, axis: axis))
        } catch {
            presentCommandError(error, command: "Align selection")
        }
    }
    func groupSelected() {
        guard selectedIDs.count > 1,
            history.document.layers.contains(where: { layer in
                selectedIDs.allSatisfy { id in layer.nodes.contains { $0.id == id } }
            })
        else { return }
        do {
            try history.commit(
                CompositeSceneCommands.group(
                    in: history.document,
                    nodeIDs: selectedIDs.sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }))
            selectedIDs.removeAll()
        } catch { presentCommandError(error, command: "Group") }
    }
    func ungroupSelected() {
        guard selectedIDs.count == 1, let id = selectedIDs.first else { return }
        do {
            try history.commit(
                CompositeSceneCommands.ungroup(in: history.document, groupID: id))
            selectedIDs.removeAll()
        } catch { presentCommandError(error, command: "Ungroup") }
    }
    func makeCompoundSelected() {
        guard selectedIDs.count > 1,
            history.document.layers.contains(where: { layer in
                selectedIDs.allSatisfy { id in layer.nodes.contains { $0.id == id } }
            })
        else { return }
        do {
            try history.commit(
                CompositeSceneCommands.makeCompound(
                    in: history.document,
                    pathIDs: selectedIDs.sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }))
            selectedIDs.removeAll()
        } catch { presentCommandError(error, command: "Make compound") }
    }
    func releaseCompoundSelected() {
        guard selectedIDs.count == 1, let id = selectedIDs.first,
            let path = history.document.path(id: id)
        else { return }
        do {
            let releasedIDs = path.path.subpaths.indices.map { $0 == 0 ? id : ObjectID() }
            try history.commit(
                CompositeSceneCommands.releaseCompound(
                    in: history.document, pathID: id, releasedIDs: releasedIDs))
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
                let layer = Layer(name: "Layer \(history.document.layers.count + 1)")
                try history.commit(
                    StructuralCommands.insertLayer(
                        layer, in: history.document, at: history.document.layers.count,
                        assetStore: assetStore))
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
            let layerID = history.document.layers[index].id
            var staged = history.document
            var children: [DocumentCommand] = []
            let nameCommand = try ValueSwapCommands.layerName(
                in: staged, layerID: layerID, newValue: nextName)
            try nameCommand.apply(to: &staged)
            children.append(nameCommand)
            let stateCommand = try ValueSwapCommands.layerVisibilityAndLock(
                in: staged, layerID: layerID,
                newValue: LayerVisibilityAndLock(
                    isVisible: nextVisible, isLocked: nextLocked))
            try stateCommand.apply(to: &staged)
            children.append(stateCommand)
            let destination =
                moveDirection == 0 && index > 0
                ? index - 1
                : moveDirection == 1 && index + 1 < staged.layers.count ? index + 1 : index
            let reorder = try StructuralCommands.reorderLayer(
                in: staged, layerID: layerID, to: destination)
            children.append(reorder)
            try history.commit(
                CompositeCommands.ordered(name: "Edit layer", children: children))
            activeLayerIndex = min(index, history.document.layers.count - 1)
        } catch { presentCommandError(error, command: "Edit layer") }
    }
    func editGradient() {
        guard selectedIDs.first != nil else { return }
        let alert = NSAlert()
        alert.messageText = "Gradient"
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")
        let kind = NSPopUpButton()
        kind.addItems(withTitles: ["Linear", "Radial"])
        let start = NSTextField(string: Theme.DefaultValue.gradientStart)
        let end = NSTextField(string: Theme.DefaultValue.gradientEnd)
        let stops = NSTextField(string: Theme.DefaultValue.gradientStops)
        let stack = NSStackView(views: [
            kind, NSTextField(labelWithString: "Start x,y"), start,
            NSTextField(labelWithString: "End x,y"), end, NSTextField(labelWithString: "Stops offset:#RRGGBB"), stops,
        ])
        stack.orientation = .vertical
        stack.spacing = 5
        stack.frame = NSRect(x: 0, y: 0, width: 280, height: 180)
        alert.accessoryView = stack
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        _ = applyGradient(
            kindIndex: kind.indexOfSelectedItem, start: start.stringValue,
            end: end.stringValue, stops: stops.stringValue)
    }
    @discardableResult func applyGradient(
        kindIndex: Int, start: String, end: String, stops: String
    ) -> Bool {
        guard let pathID = selectedIDs.first, let startPoint = parsePoint(start),
            let endPoint = parsePoint(end), let parsedStops = parseStops(stops),
            parsedStops.count >= 2
        else { return false }
        let gradient = GradientResource(
            name: "Gradient", kind: kindIndex == 0 ? .linear : .radial,
            start: startPoint, end: endPoint, stops: parsedStops)
        do {
            var staged = history.document
            let insert = try ResourceCommands.insertGradient(
                gradient, in: staged, at: staged.gradients.count)
            try insert.apply(to: &staged)
            guard var style = staged.path(id: pathID)?.style else { return false }
            style.fillGradientID = gradient.id
            let applyStyle = try ValueSwapCommands.pathStyle(
                in: staged, nodeID: pathID, newValue: style)
            try history.commit(
                CompositeCommands.ordered(
                    name: "Apply gradient", children: [insert, applyStyle]))
            return true
        } catch {
            presentCommandError(error, command: "Apply gradient")
            return false
        }
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
        do { try history.undo() } catch { presentCommandError(error, command: "Undo") }
        needsDisplay = true
    }
    func redo() {
        do { try history.redo() } catch { presentCommandError(error, command: "Redo") }
        needsDisplay = true
    }
    func applyMemorySafetyNet() {
        let tileRemoval = renderer.cache.removeAll()
        let dropped = history.applyMemorySafetyNet()
        Diagnostics.documents.info(
            "Memory safety net dropped \(tileRemoval.count, privacy: .public) tiles (\(tileRemoval.byteCount, privacy: .public) bytes) before \(dropped, privacy: .public) periodic checkpoints"
        )
    }
    func applyAccentStyle() {
        guard let id = selectedIDs.first ?? history.document.layers.first?.nodes.last?.id else { return }
        do {
            guard var style = history.document.path(id: id)?.style else { return }
            style.stroke = SRGBColor(red: 0.85, green: 0.18, blue: 0.35)
            style.strokeWidth = 6
            try history.commit(
                ValueSwapCommands.pathStyle(
                    in: history.document, nodeID: id, newValue: style))
        } catch { presentCommandError(error, command: "Apply style") }
        needsDisplay = true
    }
    var selectedNodeIDs: Set<ObjectID> { selectedIDs }
    var selectedBounds: Rect? { selectionBounds() }
    var selectedPathStyle: PathStyle? {
        guard selectedIDs.count == 1, let id = selectedIDs.first else { return nil }
        return history.document.path(id: id)?.style
    }
    var selectedTextObject: TextObject? {
        guard case .text(let text)? = selectedSceneNode else { return nil }
        return text
    }
    var selectedSceneNode: SceneNode? {
        guard selectedIDs.count == 1, let id = selectedIDs.first else { return nil }
        return try? StructuralCommands.slot(for: id, in: history.document).node
    }
    var canGroupSelection: Bool {
        guard selectedIDs.count > 1 else { return false }
        let slots = selectedIDs.compactMap { try? StructuralCommands.slot(for: $0, in: history.document) }
        return slots.count == selectedIDs.count && Set(slots.map(\.parent)).count == 1
    }
    var canUngroupSelection: Bool {
        guard case .group? = selectedSceneNode else { return false }
        return true
    }
    var canMakeCompoundSelection: Bool {
        guard canGroupSelection else { return false }
        return selectedIDs.allSatisfy { history.document.path(id: $0) != nil }
    }
    var canReleaseCompoundSelection: Bool {
        guard case .path(let path)? = selectedSceneNode else { return false }
        return path.path.subpaths.count > 1
    }
    var selectedTransform: Geometry.AffineTransform? {
        guard let node = selectedSceneNode else { return nil }
        switch node {
        case .path(let value): return value.transform
        case .text(let value): return value.transform
        case .image(let value): return value.transform
        case .group(let value): return value.transform
        }
    }
    func selectNode(_ id: ObjectID?) {
        selectedIDs = id.map { [$0] } ?? []
        selectedAnchors.removeAll()
        selectedControl = nil
        needsDisplay = true
    }
    func activateLayer(_ id: ObjectID) {
        guard let index = history.document.layers.firstIndex(where: { $0.id == id }) else { return }
        activeLayerIndex = index
        selectNode(nil)
    }
    func commitDocumentTransform(_ transform: Geometry.AffineTransform) {
        guard !selectedIDs.isEmpty else { return }
        do {
            try history.commit(
                CompositeSceneCommands.documentTransform(
                    in: history.document, nodeIDs: selectedIDs, transform: transform))
        } catch { presentCommandError(error, command: "Transform selection") }
    }
    func commitPathStyle(_ mutation: (inout PathStyle) -> Void) {
        guard selectedIDs.count == 1, let id = selectedIDs.first,
            var style = history.document.path(id: id)?.style
        else { return }
        mutation(&style)
        do {
            try history.commit(
                ValueSwapCommands.pathStyle(
                    in: history.document, nodeID: id, newValue: style))
        } catch { presentCommandError(error, command: "Edit style") }
    }
    func commitSelectedTextContent(_ value: String) {
        guard let id = selectedIDs.first, selectedTextObject != nil else { return }
        do {
            try history.commit(
                InPlaceTextEditing.editCommand(
                    nodeID: id, text: value, in: history.document))
        } catch { presentCommandError(error, command: "Edit text content") }
    }
    func commitSelectedTextFontName(_ value: String) {
        guard let id = selectedIDs.first, selectedTextObject != nil else { return }
        do {
            try history.commit(
                ValueSwapCommands.nodeProperty(
                    in: history.document, nodeID: id,
                    newValue: .textFontName(value)))
        } catch { presentCommandError(error, command: "Edit text font") }
    }
    func commitSelectedTextFontSize(_ value: Double) {
        guard let id = selectedIDs.first, selectedTextObject != nil else { return }
        do {
            try history.commit(
                ValueSwapCommands.nodeProperty(
                    in: history.document, nodeID: id,
                    newValue: .textFontSize(value)))
        } catch { presentCommandError(error, command: "Edit text size") }
    }
    func commitArtboard(width: Double? = nil, height: Double? = nil) {
        let document = history.document
        let value = ArtboardProperties(
            width: width ?? document.width, height: height ?? document.height,
            unit: document.unit)
        do {
            try history.commit(
                ValueSwapCommands.artboardProperties(
                    in: document, newValue: value))
        } catch { presentCommandError(error, command: "Edit artboard") }
    }
    func commitLayerState(_ layerID: ObjectID, visible: Bool? = nil, locked: Bool? = nil) {
        guard let layer = history.document.layers.first(where: { $0.id == layerID }) else { return }
        do {
            try history.commit(
                ValueSwapCommands.layerVisibilityAndLock(
                    in: history.document, layerID: layerID,
                    newValue: LayerVisibilityAndLock(
                        isVisible: visible ?? layer.isVisible,
                        isLocked: locked ?? layer.isLocked)))
        } catch { presentCommandError(error, command: "Edit layer") }
    }
    func reorderLayer(_ layerID: ObjectID, to index: Int) {
        do {
            try history.commit(
                StructuralCommands.reorderLayer(
                    in: history.document, layerID: layerID, to: index))
            activeLayerIndex = index
        } catch { presentCommandError(error, command: "Reorder layer") }
    }
    func reorderNode(_ nodeID: ObjectID, to parent: SceneParent, at index: Int) {
        do {
            try history.commit(
                StructuralCommands.reorderNode(
                    in: history.document, nodeID: nodeID, to: parent, at: index))
            selectNode(nodeID)
        } catch { presentCommandError(error, command: "Reorder object") }
    }
    func setZoomPercentage(_ percentage: Double) {
        guard percentage.isFinite, percentage > 0 else { return }
        setZoom(percentage / 100, about: NSPoint(x: bounds.midX, y: bounds.midY))
    }
    func prepareVisualAcceptanceState() {
        activeTool = .selection
        if let id = history.document.layers.first?.nodes.first?.id {
            selectNode(id)
            if let bounds = selectionBounds() {
                let pointer = NSPoint(
                    x: Theme.Metric.artboardInset + pan.x + bounds.maxX * zoom,
                    y: Theme.Metric.artboardInset + pan.y + bounds.minY * zoom)
                rotationReadout = (pointer: pointer, degrees: 15)
                snapIndicator = bounds.center
            }
        }
    }
    private func presentCommandError(_ error: Error, command: String) {
        Diagnostics.documents.error(
            "Command \(command, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        NSAlert(error: error).runModal()
    }
    func replaceDocument(_ document: EditorDocument) throws {
        registerEmbeddedAssets(in: document, with: assetStore)
        renderer.cache.bumpGeneration()
        history = try DeltaCommandHistory(document: document, assetStore: assetStore)
        renderer.subscribe(to: history)
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
    private var shell: EditorShellView?
    private weak var zoomToolbarView: ZoomToolbarView?
    private var autosaveTimer: Timer?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var currentURL: URL?
    private let recoveryID = "active-document"
    private let unsavedCoordinator = UnsavedChangesCoordinator()
    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.installCrashContext()
        let frame = NSRect(x: 0, y: 0, width: 1_440, height: 880)
        let window = NSWindow(
            contentRect: frame, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
            defer: false)
        window.title = "Drawing.odraw"
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
        let canvas: CanvasView
        do {
            canvas = try CanvasView(frame: frame, document: launchDocument)
        } catch {
            NSAlert(error: error).runModal()
            NSApp.terminate(nil)
            return
        }
        let shell = EditorShellView(canvas: canvas)
        shell.rail.onPlaceImage = { [weak self] in self?.placeImage() }
        shell.onDocumentChange = { [weak self] in self?.updateWindowDocumentState() }
        window.contentView = shell
        window.minSize = NSSize(width: 960, height: 620)
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .unifiedCompact
        self.canvas = canvas
        self.shell = shell
        let memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical], queue: .main)
        memoryPressureSource.setEventHandler { [weak canvas] in
            canvas?.applyMemorySafetyNet()
        }
        memoryPressureSource.resume()
        self.memoryPressureSource = memoryPressureSource
        let toolbar = NSToolbar(identifier: "tools")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        buildMainMenu()
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        if let screenshotIndex = CommandLine.arguments.firstIndex(of: "--ui-screenshot"),
            CommandLine.arguments.indices.contains(screenshotIndex + 1)
        {
            let destination = CommandLine.arguments[screenshotIndex + 1]
            canvas.prepareVisualAcceptanceState()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                self?.captureWindow(to: destination)
                NSApp.terminate(nil)
            }
        }
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: RecoverySettings.defaultInterval, repeats: true) {
            [weak self] _ in Task { @MainActor in self?.writeRecoveryIfDirty() }
        }
        NSApp.activate(ignoringOtherApps: true)
        if startupProbeEnabled {
            canvas.displayIfNeeded()
            let elapsed = (ProcessInfo.processInfo.systemUptime - processStartupStart) * 1_000
            print(String(format: "STARTUP_READY_MS=%.3f", elapsed))
            fflush(stdout)
            NSApp.terminate(nil)
        }
    }
    private func writeRecoveryIfDirty() {
        guard let canvas, canvas.history.isDirty else { return }
        try? RecoveryStore.applicationSupport().save(canvas.history.document, documentID: recoveryID)
    }
    private func updateWindowDocumentState() {
        window?.title = currentURL?.lastPathComponent ?? "Drawing.odraw"
        window?.representedURL = currentURL
        window?.isDocumentEdited = canvas?.history.isDirty ?? false
    }
    private func captureWindow(to path: String) {
        if let window {
            let capture = Process()
            capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            capture.arguments = ["-x", "-l\(window.windowNumber)", path]
            try? capture.run()
            capture.waitUntilExit()
            if capture.terminationStatus == 0 { return }
        }
        guard let view = window?.contentView?.superview,
            let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds)
        else { return }
        view.cacheDisplay(in: view.bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
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
    private func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu(title: "OpenDraw")
        appMenu.addItem(withTitle: "About OpenDraw", action: nil, keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit OpenDraw", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        main.addItem(
            menu(
                "File",
                [
                    command("New", .new, "n"), command("Open…", .open, "o"),
                    command("Import SVG…", .open, "", [.command, .shift]),
                    command("Save", .save, "s"), command("Export SVG…", .export, "e", [.command, .shift]),
                    .separator(), command("Place Image…", .image, "i", [.command, .shift]),
                ]))
        main.addItem(
            menu(
                "Edit",
                [
                    command("Undo", .undo, "z"), command("Redo", .redo, "z", [.command, .shift]),
                ]))
        main.addItem(
            menu(
                "View",
                [
                    command("Zoom Out", .zoomOut, "-"), command("Actual Size", .actualSize, "0"),
                    command("Zoom In", .zoomIn, "+"),
                    command("Zoom to Fit", .zoomFit, "9"), .separator(),
                    command("Layers", .layers, "l", [.command, .option]),
                    command("Inspector", .inspector, "i", [.command, .option]), command("Snapping", .snap, ";"),
                ]))
        main.addItem(
            menu(
                "Object",
                [
                    command("Style", .style), command("Properties", .properties), command("Gradient…", .gradient),
                    .separator(),
                    command("Align Left", .alignLeft), command("Align Center", .alignCenter),
                    command("Align Right", .alignRight), command("Align Top", .alignTop),
                    command("Align Middle", .alignMiddle), command("Align Bottom", .alignBottom),
                    .separator(), command("Group", .group, "g"),
                    command("Ungroup", .ungroup, "g", [.command, .shift]),
                    command("Make Compound", .makeCompound), command("Release Compound", .releaseCompound),
                ]))
        main.addItem(
            menu(
                "Tools",
                [
                    command("Select", .selection, "v", []), command("Direct Select", .directSelection, "a", []),
                    command("Pen", .pen, "p", []), command("Rectangle", .rectangle, "r", []),
                    command("Ellipse", .ellipse, "e", []), command("Text", .text, "t", []),
                    command("Place Image", .image, "i", []),
                ]))
        NSApp.mainMenu = main
    }
    private func menu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let root = NSMenuItem()
        let submenu = NSMenu(title: title)
        items.forEach(submenu.addItem)
        root.submenu = submenu
        return root
    }
    private func command(
        _ title: String, _ identifier: NSToolbarItem.Identifier, _ key: String = "",
        _ modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(menuAction(_:)), keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        item.representedObject = identifier.rawValue
        return item
    }
    @objc private func menuAction(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        let proxy = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier(value))
        toolbarAction(proxy)
    }
}

extension AppDelegate: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .new, .open, .save, .export, .flexibleSpace, .zoomCluster, .zoomFit,
            .space, .layers, .inspector,
        ]
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.new, .open, .save, .export, .flexibleSpace, .zoomCluster, .zoomFit, .space, .layers, .inspector]
    }
    func toolbar(
        _ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar _: Bool
    ) -> NSToolbarItem? {
        if id == .zoomCluster {
            let item = NSToolbarItem(itemIdentifier: id)
            let view = ZoomToolbarView()
            view.onZoomOut = { [weak self] in self?.canvas?.zoomOut() }
            view.onZoomIn = { [weak self] in self?.canvas?.zoomIn() }
            view.onCommit = { [weak self] in self?.canvas?.setZoomPercentage($0) }
            canvas?.onZoomChange = { [weak view] in view?.update($0) }
            item.view = view
            item.label = "Zoom"
            zoomToolbarView = view
            return item
        }
        let item = NSToolbarItem(itemIdentifier: id)
        let metadata: (String, String) =
            switch id {
            case .new: ("New", "doc.badge.plus")
            case .open: ("Open", "folder")
            case .save: ("Save", "square.and.arrow.down")
            case .export: ("Export", "square.and.arrow.up")
            case .zoomFit: ("Zoom to Fit", "arrow.up.left.and.down.right.magnifyingglass")
            case .layers: ("Layers", "square.3.layers.3d")
            case .inspector: ("Inspector", "sidebar.trailing")
            default: (id.rawValue.capitalized, "questionmark")
            }
        item.label = metadata.0
        item.paletteLabel = metadata.0
        item.toolTip = metadata.0
        item.image = NSImage(systemSymbolName: metadata.1, accessibilityDescription: metadata.0)?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: Theme.Metric.toolbarIcon, weight: .medium))
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
        case .properties: shell?.inspector.isHidden = false
        case .alignLeft: canvas.alignSelectedLeft()
        case .alignCenter: canvas.alignSelected(.horizontalCenter)
        case .alignRight: canvas.alignSelected(.right)
        case .alignTop: canvas.alignSelected(.top)
        case .alignMiddle: canvas.alignSelected(.verticalCenter)
        case .alignBottom: canvas.alignSelected(.bottom)
        case .group: canvas.groupSelected()
        case .ungroup: canvas.ungroupSelected()
        case .makeCompound: canvas.makeCompoundSelected()
        case .releaseCompound: canvas.releaseCompoundSelected()
        case .layers: shell?.toggleLayers()
        case .inspector: shell?.toggleInspector()
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
        updateWindowDocumentState()
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        try? RecoveryStore.applicationSupport().discard(documentID: recoveryID)
    }
    private func newDocument() {
        guard let canvas else { return }
        do {
            _ = try unsavedCoordinator.resolve(
                isDirty: canvas.history.isDirty, decision: unsavedDecision, save: { try saveNative(canvas) },
                operation: {
                    guard let document = try promptForNewDocument() else { return }
                    try canvas.replaceDocument(document)
                    currentURL = nil
                    updateWindowDocumentState()
                })
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
                isDirty: canvas.history.isDirty, decision: unsavedDecision, save: { try saveNative(canvas) },
                operation: {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    let document =
                        url.pathExtension.lowercased() == "svg"
                        ? try SVGImporter().importFile(url).document : try NativeDocumentCodec().load(from: url)
                    try canvas.replaceDocument(document)
                    currentURL = url
                    updateWindowDocumentState()
                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
                })
        } catch { NSAlert(error: error).runModal() }
    }
}

extension AppDelegate: NSToolbarItemValidation {
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        guard let canvas else { return false }
        switch item.itemIdentifier {
        case .undo: return canvas.history.canUndo
        case .redo: return canvas.history.canRedo
        case .style, .gradient: return canvas.hasSelection
        case .alignLeft, .alignCenter, .alignRight, .alignTop, .alignMiddle, .alignBottom:
            return canvas.hasMultipleSelection
        case .group: return canvas.canGroupSelection
        case .makeCompound: return canvas.canMakeCompoundSelection
        case .ungroup: return canvas.canUngroupSelection
        case .releaseCompound: return canvas.canReleaseCompoundSelection
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
    static let alignLeft = Self("align-left"), alignCenter = Self("align-center"), alignRight = Self("align-right")
    static let alignTop = Self("align-top"), alignMiddle = Self("align-middle"), alignBottom = Self("align-bottom")
    static let group = Self("group")
    static let ungroup = Self("ungroup"), makeCompound = Self("make-compound"),
        releaseCompound = Self("release-compound")
    static let layers = Self("layers")
    static let inspector = Self("inspector")
    static let gradient = Self("gradient")
    static let snap = Self("snap")
    static let zoomIn = Self("zoom-in"), zoomOut = Self("zoom-out"), actualSize = Self("zoom-100"),
        zoomFit = Self("zoom-fit"), zoomCluster = Self("zoom-cluster")
}

if CommandLine.arguments.contains("--smoke") {
    do {
        let smokeStart = ProcessInfo.processInfo.systemUptime
        let codec = NativeDocumentCodec()
        var document = try EditorDocument.sample()
        for _ in 0..<100 { document = try codec.decode(codec.encode(document)) }
        guard
            let bitmap = CGContext(
                data: nil, width: 800, height: 500, bitsPerComponent: 8,
                bytesPerRow: 800 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw EditorError.invalidValue("Smoke tile bitmap allocation failed") }
        let renderer = TileCompositeRenderer()
        let cold = try renderer.composite(document, in: bitmap)
        let warm = try renderer.composite(document, in: bitmap)
        guard cold.renderedTiles.count == cold.visibleCoordinates.count,
            warm.renderedTiles.isEmpty,
            warm.hitTiles.count == warm.visibleCoordinates.count
        else { throw EditorError.invariantViolation("Smoke tile composite did not become fully warm") }
        let elapsed = (ProcessInfo.processInfo.systemUptime - smokeStart) * 1_000
        print(
            String(
                format:
                    "OpenDraw smoke: pid=%d duration_ms=%.3f 100 native round trips passed tile_cold=%d tile_warm_hits=%d",
                ProcessInfo.processInfo.processIdentifier, elapsed,
                cold.renderedTiles.count, warm.hitTiles.count))
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
