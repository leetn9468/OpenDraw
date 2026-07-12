import DocumentModel
import EditorCommands
import EditorCore
import Foundation
import Geometry
import Testing

@Test func documentInvariants() {
    #expect(throws: (any Error).self) { try EditorDocument(width: 0, height: 10) }
    #expect(throws: (any Error).self) { try EditorDocument(width: 10, height: 10, layers: []) }
}

@Test func commandUndoRedoAndBranch() throws {
    var history = CommandHistory(document: try EditorDocument(width: 100, height: 100))
    try history.perform(DocumentCommand(name: "Resize") { $0.width = 200 })
    #expect(history.document.width == 200)
    history.undo()
    #expect(history.document.width == 100)
    history.redo()
    #expect(history.document.width == 200)
    history.undo()
    try history.perform(DocumentCommand(name: "Other resize") { $0.width = 300 })
    #expect(!history.canRedo)
    #expect(history.document.width == 300)
}

@Test func historyDirtyCoalescingRollbackAndLimit() throws {
    var history = CommandHistory(document: try EditorDocument(width: 100, height: 100), maximumEntries: 2)
    #expect(!history.isDirty)
    let gesture = GestureID()
    try history.perform(DocumentCommand(name: "Move") { $0.width = 110 }, gestureID: gesture)
    try history.coalesce(DocumentCommand(name: "Move") { $0.width = 120 }, gestureID: gesture)
    #expect(history.isDirty)
    history.undo()
    #expect(history.document.width == 100)
    history.redo()
    history.markSaved()
    #expect(!history.isDirty)
    #expect(throws: (any Error).self) { try history.perform(DocumentCommand(name: "Invalid") { $0.width = .nan }) }
    #expect(history.document.width == 120)
}

@Test func revisionGestureAndChangeStreamSemantics() async throws {
    var history = CommandHistory(document: try EditorDocument(width: 100, height: 100))
    let stream = history.changes()
    let gestureA = GestureID()
    let gestureB = GestureID()
    try history.perform(DocumentCommand(name: "Move") { $0.width = 110 }, gestureID: gestureA)
    try history.coalesce(DocumentCommand(name: "Move") { $0.width = 120 }, gestureID: gestureA)
    try history.coalesce(DocumentCommand(name: "Move") { $0.width = 130 }, gestureID: gestureB)
    #expect(history.currentRevision == 3)
    history.undo()
    #expect(history.document.width == 120)
    history.undo()
    #expect(history.document.width == 100)
    #expect(history.currentRevision == 5)
    var iterator = stream.makeAsyncIterator()
    #expect(await iterator.next() == DocumentChange(revision: 1, kind: .command("Move")))
}

@Test func failedFirstGestureDoesNotCorruptLaterCoalescing() throws {
    var history = CommandHistory(document: try EditorDocument(width: 100, height: 100))
    let gesture = GestureID()
    #expect(throws: (any Error).self) {
        try history.perform(DocumentCommand(name: "Move") { $0.width = .nan }, gestureID: gesture)
    }
    try history.coalesce(DocumentCommand(name: "Move") { $0.width = 110 }, gestureID: gesture)
    #expect(history.canUndo)
    history.undo()
    #expect(history.document.width == 100)
}

@Test func unsavedCoordinatorsAreIndependentAndCancelPreventsReplacement() async throws {
    let first = UnsavedChangesCoordinator()
    let second = UnsavedChangesCoordinator()
    final class State: @unchecked Sendable {
        var operations = 0
        let lock = NSLock()
    }
    let state = State()
    let cancelled = try await first.resolve(
        isDirty: true, decision: { .cancel }, save: {},
        operation: {
            state.lock.withLock { state.operations += 1 }
        })
    let completed = try await second.resolve(
        isDirty: false, decision: { .cancel }, save: {},
        operation: {
            state.lock.withLock { state.operations += 1 }
        })
    #expect(!cancelled)
    #expect(completed)
    #expect(state.operations == 1)
}

@Test func historyLimitIsImmutableAndCappedAtThirty() throws {
    var history = CommandHistory(document: try EditorDocument(width: 100, height: 100), maximumEntries: 100)
    #expect(history.maximumEntries == 30)
    for value in 101...131 { try history.perform(DocumentCommand(name: "Resize") { $0.width = Double(value) }) }
    for _ in 0..<30 { history.undo() }
    #expect(history.document.width == 101)
    history.undo()
    #expect(history.document.width == 101)
}

@Test func snapshotHistorySharesEmbeddedAssetsAndHonorsMemorySafetyNet() throws {
    var bytes = Data(repeating: 0, count: 50 * 1_024 * 1_024)
    bytes.replaceSubrange(0..<8, with: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
    let image = ImageObject(
        frame: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1), storage: .embedded(bytes), pixelWidth: 1,
        pixelHeight: 1)
    let document = try EditorDocument(
        width: 100, height: 100, layers: [Layer(name: "L", nodes: [.image(image)])])
    let originalAddress = bytes.withUnsafeBytes { Int(bitPattern: $0.baseAddress) }
    var history = CommandHistory(document: document, maximumEstimatedBytes: 60 * 1_024 * 1_024)
    for value in 101...130 { try history.perform(DocumentCommand(name: "Resize") { $0.width = Double(value) }) }
    guard case .image(let stored) = history.document.layers[0].nodes[0], case .embedded(let storedData) = stored.storage
    else {
        Issue.record("Missing embedded image")
        return
    }
    #expect(storedData.withUnsafeBytes { Int(bitPattern: $0.baseAddress) } == originalAddress)
    #expect(history.estimatedMemoryBytes < 60 * 1_024 * 1_024)
    #expect(history.undoDepth == 30)
}

@Test func alignmentIsUndoable() throws {
    let a = PathObject(segments: [
        CubicBezier(
            start: Point(x: 0, y: 0), control1: Point(x: 0, y: 0), control2: Point(x: 10, y: 10),
            end: Point(x: 10, y: 10))
    ])
    let b = PathObject(segments: [
        CubicBezier(
            start: Point(x: 50, y: 20), control1: Point(x: 50, y: 20), control2: Point(x: 70, y: 40),
            end: Point(x: 70, y: 40))
    ])
    var history = CommandHistory(
        document: try EditorDocument(width: 100, height: 100, layers: [Layer(name: "L", nodes: [.path(a), .path(b)])]))
    try history.perform(AlignmentCommands.align(pathIDs: [a.id, b.id], axis: .left))
    #expect(history.document.visualBounds(for: b.id)?.minX == history.document.visualBounds(for: a.id)?.minX)
    history.undo()
    #expect(history.document.visualBounds(for: b.id)?.minX != history.document.visualBounds(for: a.id)?.minX)
}

@Test func advancedResourceInvariants() throws {
    let swatch = Swatch(name: "Blue", color: SRGBColor(red: 0, green: 0, blue: 1))
    let gradient = GradientResource(
        name: "Fade", kind: .linear, start: Point(x: 0, y: 0), end: Point(x: 10, y: 0),
        stops: [ColorStop(offset: 0, color: .black), ColorStop(offset: 1, color: .white)])
    let document = try EditorDocument(width: 100, height: 100, swatches: [swatch], gradients: [gradient])
    try document.validate()
    #expect(document.gradients[0].stops[0].offset == 0)
}
