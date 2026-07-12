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
    var history: CommandHistory
    var activeTool: ActiveTool = .pen
    private var pen = PenToolState()
    private var dragStart: Point?
    private var dragLast: Point?
    private var selectedID: ObjectID?
    private var dragHasMutation = false
    private var dragGestureID: GestureID?
    private(set) var zoom = 1.0
    private(set) var pan = Point(x: 0, y: 0)
    private var spaceDown = false
    private var panDragLocation: NSPoint?
    private let renderer = CoreGraphicsRenderer()
    private var changeTask: Task<Void, Never>?
    init(frame: NSRect, document: EditorDocument) {
        history = CommandHistory(document: document)
        super.init(frame: frame)
        subscribeToChanges()
    }
    required init?(coder: NSCoder) { nil }
    var hasSelection: Bool { selectedID != nil }
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
        context.restoreGState()
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if spaceDown {
            panDragLocation = location
            return
        }
        let point = documentPoint(location)
        if activeTool == .text {
            createText(at: point)
        } else if activeTool == .pen {
            pen.addAnchor(point)
            if event.clickCount == 2, let object = pen.finish(close: false) { add(object) }
        } else if activeTool == .selection || activeTool == .directSelection {
            selectedID = SelectionTool().hitTest(history.document, pointer: point, zoom: zoom)
            dragLast = point
            dragHasMutation = false
            dragGestureID = GestureID()
            needsDisplay = true
        } else {
            dragStart = point
        }
    }
    override func mouseDragged(with event: NSEvent) {
        if let prior = panDragLocation {
            let location = convert(event.locationInWindow, from: nil)
            pan = Point(x: pan.x + location.x - prior.x, y: pan.y + location.y - prior.y)
            panDragLocation = location
            needsDisplay = true
            return
        }
        guard let id = selectedID, let prior = dragLast else { return }
        let location = convert(event.locationInWindow, from: nil)
        let next = documentPoint(location)
        let dx = next.x - prior.x
        let dy = next.y - prior.y
        guard dx != 0 || dy != 0 else { return }
        let command = DocumentCommand(name: "Move path") { document in
            _ = document.translateNode(id: id, documentDX: dx, documentDY: dy)
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
            dragLast = nil
            dragHasMutation = false
            dragGestureID = nil
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
    private func add(_ object: PathObject) {
        do {
            try history.perform(DocumentCommand(name: "Create object") { $0.layers[0].nodes.append(.path(object)) })
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
        do {
            try history.perform(DocumentCommand(name: "Create text") { $0.layers[0].nodes.append(.text(text)) })
        } catch { presentCommandError(error, command: "Create text") }
    }
    func placeEmbeddedImage(data: Data) throws {
        let image = try RasterResourceLoader().embedded(
            data: data,
            frame: Rect(minX: 40, minY: 40, maxX: 240, maxY: 240))
        try history.perform(DocumentCommand(name: "Place image") { $0.layers[0].nodes.append(.image(image)) })
    }
    func editSelectedProperties() {
        guard let id = selectedID else { return }
        let alert = NSAlert()
        alert.messageText = "Path Properties"
        alert.addButton(withTitle: "Apply")
        alert.addButton(withTitle: "Cancel")
        let width = NSTextField(string: "1")
        let opacity = NSTextField(string: "1")
        let dash = NSTextField(string: "")
        let stack = NSStackView(views: [
            NSTextField(labelWithString: "Stroke width"), width,
            NSTextField(labelWithString: "Opacity (0–1)"), opacity, NSTextField(labelWithString: "Dash values"), dash,
        ])
        stack.orientation = .vertical
        stack.spacing = 5
        stack.frame = NSRect(x: 0, y: 0, width: 240, height: 140)
        alert.accessoryView = stack
        guard alert.runModal() == .alertFirstButtonReturn, let strokeWidth = Double(width.stringValue),
            let alpha = Double(opacity.stringValue)
        else { return }
        let dashes = dash.stringValue.split(separator: ",").compactMap {
            Double($0.trimmingCharacters(in: .whitespaces))
        }
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
                            })
                    else { throw SceneCommandError.selectionNotFound }
                })
        } catch { presentCommandError(error, command: "Edit properties") }
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
        guard let id = selectedID ?? history.document.layers.first?.nodes.last?.id else { return }
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
        selectedID = nil
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
            try canvas.placeEmbeddedImage(data: data)
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
        case .style, .properties: return canvas.hasSelection
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
    static let zoomIn = Self("zoom-in"), zoomOut = Self("zoom-out"), actualSize = Self("zoom-100"),
        zoomFit = Self("zoom-fit")
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
