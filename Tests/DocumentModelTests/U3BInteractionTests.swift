import DocumentModel
import EditorCommands
import EditorCore
import Foundation
import Geometry
import Testing

@Test
func u3bOptionHandleBreakCoalescesAndUndoRestoresSmoothness() throws {
    let pathID = u3bID(1)
    let original = try u3bSmoothDocument(pathID: pathID)
    let location = PathAnchorLocation(pathID: pathID, anchorIndex: 1)
    let before = try AnchorGeometryCommands.slice(in: original, at: location)
    #expect(AnchorGeometryCommands.isSmooth(before))

    var cancelledHistory = try DeltaCommandHistory(document: original)
    try cancelledHistory.commit(
        ValueSwapCommands.transform(
            in: cancelledHistory.document, nodeID: pathID,
            newValue: Geometry.AffineTransform(tx: 1)))
    try cancelledHistory.undo()
    let redoDepth = cancelledHistory.redoDepth
    let cancelled = try cancelledHistory.beginAnchorGesture(at: location)
    let cancelledCorner = try AnchorGeometryCommands.handleDragSlice(
        from: before, side: .outgoing, to: Point(x: 120, y: 110), breakSmooth: true)
    try cancelledHistory.updateAnchorGesture(cancelled, newValue: cancelledCorner)
    try cancelledHistory.cancelDeltaGesture(cancelled)
    #expect(cancelledHistory.redoDepth == redoDepth)
    #expect(try AnchorGeometryCommands.slice(in: cancelledHistory.document, at: location) == before)

    var history = try DeltaCommandHistory(document: original)
    let gesture = try history.beginAnchorGesture(at: location)
    let first = try AnchorGeometryCommands.handleDragSlice(
        from: before, side: .outgoing, to: Point(x: 125, y: 112), breakSmooth: true)
    try history.updateAnchorGesture(gesture, newValue: first)
    let second = try AnchorGeometryCommands.handleDragSlice(
        from: try AnchorGeometryCommands.slice(in: history.document, at: location),
        side: .outgoing, to: Point(x: 130, y: 118), breakSmooth: true)
    try history.updateAnchorGesture(gesture, newValue: second)
    #expect(try history.endGesture(gesture) == .committed)
    #expect(history.undoDepth == 1)
    let corner = try AnchorGeometryCommands.slice(in: history.document, at: location)
    #expect(!AnchorGeometryCommands.isSmooth(corner))
    #expect(corner.incoming == before.incoming)
    #expect(corner.outgoing == Point(x: 130, y: 118))
    try history.undo()
    #expect(try AnchorGeometryCommands.slice(in: history.document, at: location) == before)
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
}

@Test
func u3bModifierGestureCommitAndCancelPreserveDeltaHistorySemantics() throws {
    let pathID = u3bID(2)
    let original = try u3bSmoothDocument(pathID: pathID)
    var history = try DeltaCommandHistory(document: original)
    try history.commit(
        ValueSwapCommands.transform(
            in: history.document, nodeID: pathID,
            newValue: AffineTransform(tx: 4)))
    try history.undo()
    let redoDepth = history.redoDepth
    let cancelled = try history.beginTransformGesture(nodeID: pathID)
    try history.updateDocumentTransformGesture(
        cancelled,
        documentTransform: AffineTransform(a: 2, d: 2, tx: -100, ty: -100))
    try history.cancelDeltaGesture(cancelled)
    #expect(history.undoDepth == 0)
    #expect(history.redoDepth == redoDepth)
    #expect(try CanonicalDocumentEquality.equals(history.document, original))

    let committed = try history.beginTransformGesture(nodeID: pathID)
    try history.updateDocumentTransformGesture(
        committed,
        documentTransform: u3bRotation(
            about: Point(x: 100, y: 100), radians: .pi / 12))
    #expect(try history.endGesture(committed) == .committed)
    #expect(history.undoDepth == 1)
    try history.undo()
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
}

@Test
func u3bInPlaceTextNewEmptyCancelAndExistingValueSwapRoundTrip() throws {
    let layerID = u3bID(10)
    let textID = u3bID(11)
    let text = TextObject(
        id: textID, text: "Before", origin: Point(x: 20, y: 30),
        fontName: "Helvetica", fontSize: 24)
    let original = try EditorDocument(
        width: 200, height: 200,
        layers: [Layer(id: layerID, name: "Text", nodes: [.text(text)])])
    var history = try DeltaCommandHistory(document: original)
    try history.commit(
        ValueSwapCommands.artboardProperties(
            in: history.document,
            newValue: ArtboardProperties(width: 201, height: 200, unit: history.document.unit)))
    try history.undo()
    let redoDepth = history.redoDepth
    let empty = TextObject(
        id: u3bID(12), text: "", origin: Point(x: 40, y: 50),
        fontName: "Helvetica", fontSize: 24)
    #expect(
        try InPlaceTextEditing.createCommand(
            text: empty, in: history.document, parent: .layer(layerID), at: 1) == nil)
    #expect(history.undoDepth == 0)
    #expect(history.redoDepth == redoDepth)

    let created = TextObject(
        id: u3bID(13), text: "Created in place", origin: Point(x: 40, y: 50),
        fontName: "Helvetica", fontSize: 24)
    let optionalCreate = try InPlaceTextEditing.createCommand(
        text: created, in: history.document, parent: .layer(layerID), at: 1)
    let create = try #require(optionalCreate)
    try history.commit(create)
    #expect(try u3bText(in: history.document, id: created.id) == "Created in place")
    try history.undo()
    #expect(throws: StructuralCommandError.self) {
        try StructuralCommands.slot(for: created.id, in: history.document)
    }

    try history.commit(
        InPlaceTextEditing.editCommand(
            nodeID: textID, text: "After", in: history.document))
    #expect(try u3bText(in: history.document, id: textID) == "After")
    #expect(history.undoDepth == 1)
    #expect(history.redoDepth == 0)
    try history.undo()
    #expect(try u3bText(in: history.document, id: textID) == "Before")
}

private func u3bSmoothDocument(pathID: ObjectID) throws -> EditorDocument {
    let path = PathObject(
        id: pathID,
        segments: [
            CubicBezier(
                start: Point(x: 0, y: 0), control1: Point(x: 10, y: 10),
                control2: Point(x: 90, y: 95), end: Point(x: 100, y: 100)),
            CubicBezier(
                start: Point(x: 100, y: 100), control1: Point(x: 110, y: 105),
                control2: Point(x: 140, y: 140), end: Point(x: 150, y: 150)),
        ])
    return try EditorDocument(
        width: 300, height: 300,
        layers: [Layer(id: u3bID(20), name: "Path", nodes: [.path(path)])])
}

private func u3bID(_ value: Int) -> ObjectID {
    ObjectID(
        rawValue: UUID(uuidString: String(format: "00000000-0000-0000-00B3-%012X", value))!)
}

private func u3bRotation(about pivot: Point, radians: Double) -> Geometry.AffineTransform {
    let cosine = cos(radians)
    let sine = sin(radians)
    return Geometry.AffineTransform(
        a: cosine, b: sine, c: -sine, d: cosine,
        tx: pivot.x - cosine * pivot.x + sine * pivot.y,
        ty: pivot.y - sine * pivot.x - cosine * pivot.y)
}

private func u3bText(in document: EditorDocument, id: ObjectID) throws -> String {
    guard case .text(let text) = try StructuralCommands.slot(for: id, in: document).node else {
        throw ValueSwapCommandError.wrongNodeKind
    }
    return text.text
}
