import AppKit
import CanvasRender
import DocumentFormats
import DocumentModel
import EditorCommands
import EditorCore
import EditorTools
import Geometry
import TextEngine

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
    private let renderer = CoreGraphicsRenderer()
    private var changeTask: Task<Void, Never>?
    init(frame: NSRect, document: EditorDocument) {
        history = CommandHistory(document: document)
        super.init(frame: frame)
        subscribeToChanges()
    }
    required init?(coder: NSCoder) { nil }
    deinit { changeTask?.cancel() }
    private func subscribeToChanges() {
        changeTask?.cancel()
        let stream = history.changes()
        changeTask = Task { @MainActor [weak self] in
            for await _ in stream { self?.needsDisplay = true }
        }
    }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: 24, y: 24)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: history.document.width, height: history.document.height))
        let documentClip = Rect(
            minX: max(0, dirtyRect.minX - 24), minY: max(0, dirtyRect.minY - 24),
            maxX: min(history.document.width, dirtyRect.maxX - 24),
            maxY: min(history.document.height, dirtyRect.maxY - 24))
        renderer.render(history.document, in: context, viewport: RenderViewport(clip: documentClip))
        context.restoreGState()
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let point = Point(x: location.x - 24, y: location.y - 24)
        if activeTool == .pen {
            pen.addAnchor(point)
            if event.clickCount == 2, let object = pen.finish(close: false) { add(object) }
        } else if activeTool == .selection || activeTool == .directSelection {
            selectedID = SelectionTool().hitTest(history.document, pointer: point, zoom: 1)
            dragLast = point
            dragHasMutation = false
            dragGestureID = GestureID()
            needsDisplay = true
        } else {
            dragStart = point
        }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let id = selectedID, let prior = dragLast else { return }
        let location = convert(event.locationInWindow, from: nil)
        let next = Point(x: location.x - 24, y: location.y - 24)
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
        if activeTool == .selection || activeTool == .directSelection {
            dragLast = nil
            dragHasMutation = false
            dragGestureID = nil
            return
        }
        guard let start = dragStart else { return }
        dragStart = nil
        let location = convert(event.locationInWindow, from: nil)
        let end = Point(x: location.x - 24, y: location.y - 24)
        let object =
            activeTool == .rectangle
            ? ShapeFactory.rectangle(from: start, to: end, constrained: event.modifierFlags.contains(.shift))
            : activeTool == .ellipse
                ? ShapeFactory.ellipse(in: Rect(minX: start.x, minY: start.y, maxX: end.x, maxY: end.y)) : nil
        if let object { add(object) }
    }
    private func add(_ object: PathObject) {
        do {
            try history.perform(DocumentCommand(name: "Create object") { $0.layers[0].nodes.append(.path(object)) })
        } catch { presentCommandError(error, command: "Create object") }
        needsDisplay = true
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
        [.new, .open, .save, .export, .undo, .redo, .selection, .pen, .rectangle, .ellipse, .style]
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
        case .pen: canvas.activeTool = .pen
        case .rectangle: canvas.activeTool = .rectangle
        case .ellipse: canvas.activeTool = .ellipse
        case .undo: canvas.undo()
        case .redo: canvas.redo()
        case .style: canvas.applyAccentStyle()
        case .save:
            do { try saveNative(canvas) } catch { NSAlert(error: error).runModal() }
        case .export: save(canvas, svg: true)
        default: break
        }
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
                canvas.replaceDocument(try EditorDocument.sample())
                currentURL = nil
            }
        } catch { NSAlert(error: error).runModal() }
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

extension NSToolbarItem.Identifier {
    static let new = Self("new"), open = Self("open"), save = Self("save"), export = Self("export"),
        undo = Self("undo"),
        redo = Self("redo"), selection = Self("select"), pen = Self("pen"), rectangle = Self("rectangle"),
        ellipse = Self("ellipse"), style = Self("style")
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
