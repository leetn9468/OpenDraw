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
    var history = CommandHistory(document: EditorDocument.sample())
    var activeTool: ActiveTool = .pen
    private var pen = PenToolState()
    private var dragStart: Point?
    private var dragLast: Point?
    private var selectedID: ObjectID?
    private var dragHasMutation = false
    private let renderer = CoreGraphicsRenderer()
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: 24, y: 24)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: history.document.width, height: history.document.height))
        renderer.render(history.document, in: context)
        context.restoreGState()
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let point = Point(x: location.x - 24, y: location.y - 24)
        if activeTool == .pen {
            pen.addAnchor(point)
            if event.clickCount == 2, let object = pen.finish(close: false) { add(object) }
        } else if activeTool == .selection || activeTool == .directSelection {
            selectedID =
                history.document.layers.reversed().flatMap { $0.paths.reversed() }.first { object in
                    object.bounds?.contains(
                        Point(x: point.x - object.transform.tx, y: point.y - object.transform.ty), tolerance: 6) == true
                }?.id
            dragLast = point
            dragHasMutation = false
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
            for layer in document.layers.indices {
                if let index = document.layers[layer].paths.firstIndex(where: { $0.id == id }) {
                    document.layers[layer].paths[index].transform.tx += dx
                    document.layers[layer].paths[index].transform.ty += dy
                }
            }
        }
        if dragHasMutation {
            try? history.coalesce(command)
        } else {
            try? history.perform(command)
            dragHasMutation = true
        }
        dragLast = next
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if activeTool == .selection || activeTool == .directSelection {
            dragLast = nil
            dragHasMutation = false
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
        try? history.perform(DocumentCommand(name: "Create object") { $0.layers[0].paths.append(object) })
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
        guard let id = selectedID ?? history.document.layers.first?.paths.last?.id else { return }
        try? history.perform(
            DocumentCommand(name: "Apply style") { document in
                for layer in document.layers.indices {
                    if let index = document.layers[layer].paths.firstIndex(where: { $0.id == id }) {
                        document.layers[layer].paths[index].style.stroke = SRGBColor(red: 0.85, green: 0.18, blue: 0.35)
                        document.layers[layer].paths[index].style.strokeWidth = 6
                    }
                }
            })
        needsDisplay = true
    }
    func replaceDocument(_ document: EditorDocument) {
        history = CommandHistory(document: document)
        selectedID = nil
        needsDisplay = true
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var canvas: CanvasView?
    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.installCrashContext()
        let frame = NSRect(x: 0, y: 0, width: 800, height: 620)
        let window = NSWindow(
            contentRect: frame, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered,
            defer: false)
        window.title = "Vector Foundry — Foundation"
        let canvas = CanvasView(frame: frame)
        window.contentView = canvas
        self.canvas = canvas
        let toolbar = NSToolbar(identifier: "tools")
        toolbar.delegate = self
        window.toolbar = toolbar
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard canvas?.history.isDirty == true else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Discard unsaved changes?"
        alert.informativeText = "Your current drawing has changes that have not been saved."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Discard")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }
}

extension AppDelegate: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.open, .save, .export, .undo, .redo, .selection, .pen, .rectangle, .ellipse, .style]
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
        case .open: openDocument()
        case .selection: canvas.activeTool = .selection
        case .pen: canvas.activeTool = .pen
        case .rectangle: canvas.activeTool = .rectangle
        case .ellipse: canvas.activeTool = .ellipse
        case .undo: canvas.undo()
        case .redo: canvas.redo()
        case .style: canvas.applyAccentStyle()
        case .save: save(canvas, svg: false)
        case .export: save(canvas, svg: true)
        default: break
        }
    }
    private func save(_ canvas: CanvasView, svg: Bool) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = svg ? "Drawing.svg" : "Drawing.vfd"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            if svg {
                let result = try SVGExporter().export(canvas.history.document)
                try result.data.write(to: url, options: .atomic)
                if !result.warnings.isEmpty {
                    let alert = NSAlert()
                    alert.messageText = "Export completed with limitations"
                    alert.informativeText = result.warnings.map(\.message).joined(separator: "\n")
                    alert.runModal()
                }
            } else {
                try NativeDocumentCodec().saveAtomically(canvas.history.document, to: url)
                canvas.history.markSaved()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
    private func openDocument() {
        guard let canvas else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let document = try NativeDocumentCodec().load(from: url)
            canvas.replaceDocument(document)
        } catch { NSAlert(error: error).runModal() }
    }
}

extension NSToolbarItem.Identifier {
    static let open = Self("open"), save = Self("save"), export = Self("export"), undo = Self("undo"),
        redo = Self("redo"), selection = Self("select"), pen = Self("pen"), rectangle = Self("rectangle"),
        ellipse = Self("ellipse"), style = Self("style")
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
