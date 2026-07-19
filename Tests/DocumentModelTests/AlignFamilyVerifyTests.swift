import DocumentModel
import EditorCommands
import EditorCore
import Foundation
import Geometry
import Testing

@Test
func verify034FrozenAlignmentWorkedExamples() throws {
    let original = try verify034Document()
    let ids = Set([verify034ID(1), verify034ID(2), verify034ID(3)])
    let examples: [(AlignmentAxis, [Point])] = [
        (.left, [Point(x: -15, y: 0), Point(x: -55, y: 0), Point(x: 0, y: 0)]),
        (.right, [Point(x: 60, y: 0), Point(x: 0, y: 0), Point(x: 75, y: 0)]),
        (.horizontalCenter, [Point(x: 22.5, y: 0), Point(x: -27.5, y: 0), Point(x: 37.5, y: 0)]),
        (.verticalCenter, [Point(x: 0, y: 5), Point(x: 0, y: 19), Point(x: 0, y: -12.5)]),
    ]

    #expect(verify034CombinedBounds(in: original, ids: ids) == Rect(minX: -5, minY: 10, maxX: 90, maxY: 60))
    for (axis, expectedDeltas) in examples {
        var history = try DeltaCommandHistory(document: original)
        let before = ids.sorted(by: verify034IDOrder).map { original.visualBounds(for: $0)! }
        #expect(
            try history.commit(
                CompositeSceneCommands.align(in: history.document, nodeIDs: ids, axis: axis)) == .committed)
        #expect(history.undoDepth == 1)
        let after = ids.sorted(by: verify034IDOrder).map { history.document.visualBounds(for: $0)! }
        let actualDeltas = zip(before, after).map {
            Point(x: $1.minX - $0.minX, y: $1.minY - $0.minY)
        }
        #expect(actualDeltas == expectedDeltas)
        try history.undo()
        #expect(try CanonicalDocumentEquality.equals(history.document, original))
    }
}

@Test
func verify034DegenerateSelectionsElideWithoutHistoryMutation() throws {
    let original = try verify034Document()
    var single = try DeltaCommandHistory(document: original)
    try single.commit(
        ValueSwapCommands.artboardProperties(
            in: single.document,
            newValue: ArtboardProperties(width: 201, height: 200, unit: single.document.unit)))
    try single.undo()
    let singleUndoDepth = single.undoDepth
    let singleRedoDepth = single.redoDepth
    let singleCounter = single.globalCommandCounter
    #expect(
        try single.commit(
            CompositeSceneCommands.align(
                in: single.document, nodeIDs: [verify034ID(1)], axis: .left)) == .identityElided)
    #expect(single.undoDepth == singleUndoDepth)
    #expect(single.redoDepth == singleRedoDepth)
    #expect(single.globalCommandCounter == singleCounter)
    #expect(try CanonicalDocumentEquality.equals(single.document, original))

    let alignedDocument = try EditorDocument(
        width: 200, height: 200,
        layers: [
            Layer(
                id: verify034ID(20), name: "Aligned",
                nodes: [
                    verify034Image(id: verify034ID(21), bounds: Rect(minX: 10, minY: 10, maxX: 20, maxY: 20)),
                    verify034Image(id: verify034ID(22), bounds: Rect(minX: 10, minY: 40, maxX: 30, maxY: 50)),
                ])
        ])
    var aligned = try DeltaCommandHistory(document: alignedDocument)
    #expect(
        try aligned.commit(
            CompositeSceneCommands.align(
                in: aligned.document, nodeIDs: [verify034ID(21), verify034ID(22)], axis: .left))
            == .identityElided)
    #expect(aligned.undoDepth == 0)
    #expect(aligned.redoDepth == 0)
    #expect(aligned.globalCommandCounter == 0)
    #expect(try CanonicalDocumentEquality.equals(aligned.document, alignedDocument))
}

private func verify034Document() throws -> EditorDocument {
    try EditorDocument(
        width: 200, height: 200,
        layers: [
            Layer(
                id: verify034ID(10), name: "VERIFY-034",
                nodes: [
                    verify034Image(id: verify034ID(1), bounds: Rect(minX: 10, minY: 20, maxX: 30, maxY: 40)),
                    verify034Image(id: verify034ID(2), bounds: Rect(minX: 50, minY: 10, maxX: 90, maxY: 22)),
                    verify034Image(id: verify034ID(3), bounds: Rect(minX: -5, minY: 35, maxX: 15, maxY: 60)),
                ])
        ])
}

private func verify034Image(id: ObjectID, bounds: Rect) -> SceneNode {
    .image(
        ImageObject(
            id: id, frame: bounds, storage: .linked(relativePath: "verify-034.png"),
            pixelWidth: 1, pixelHeight: 1))
}

private func verify034CombinedBounds(in document: EditorDocument, ids: Set<ObjectID>) -> Rect? {
    ids.compactMap { document.visualBounds(for: $0) }.reduce(nil) { result, bounds in
        result.map { $0.union(bounds) } ?? bounds
    }
}

private func verify034IDOrder(_ lhs: ObjectID, _ rhs: ObjectID) -> Bool {
    lhs.rawValue.uuidString < rhs.rawValue.uuidString
}

private func verify034ID(_ value: Int) -> ObjectID {
    ObjectID(
        rawValue: UUID(uuidString: String(format: "00000000-0000-0000-0034-%012X", value))!)
}
