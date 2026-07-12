import DocumentModel
import EditorCommands
import EditorCore
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
    try history.perform(DocumentCommand(name: "Move") { $0.width = 110 })
    try history.coalesce(DocumentCommand(name: "Move") { $0.width = 120 })
    #expect(history.isDirty)
    history.undo()
    #expect(history.document.width == 100)
    history.redo()
    history.markSaved()
    #expect(!history.isDirty)
    #expect(throws: (any Error).self) { try history.perform(DocumentCommand(name: "Invalid") { $0.width = .nan }) }
    #expect(history.document.width == 120)
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
