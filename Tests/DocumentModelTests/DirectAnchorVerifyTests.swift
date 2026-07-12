import DocumentModel
import EditorCommands
import Geometry
import Testing

private func line(_ x: Double) -> PathObject {
    PathObject(
        segments: [
            CubicBezier(
                start: Point(x: x, y: 0), control1: Point(x: x, y: 0), control2: Point(x: x + 10, y: 0),
                end: Point(x: x + 10, y: 0))
        ],
        style: PathStyle(stroke: .black, strokeWidth: 2))
}

@Test func verify019DocumentDeltaIncludesOwnAndAncestorTransforms() throws {
    var identity = try EditorDocument(width: 200, height: 200, layers: [Layer(name: "L", nodes: [.path(line(0))])])
    let identityID = identity.layers[0].nodes[0].id
    let identityMoved = identity.movePathAnchor(
        id: identityID, subpath: 0, segment: 0, documentDelta: Point(x: 8, y: -3))
    #expect(identityMoved)
    guard case .path(let identityPath) = identity.layers[0].nodes[0] else { return }
    #expect(identityPath.segments[0].start == Point(x: 8, y: -3))

    var path = line(0)
    path.transform = AffineTransform(a: 0, b: 1, c: -1, d: 0)
    let group = GroupNode(transform: AffineTransform(a: 2, b: 0, c: 0, d: 4), children: [.path(path)])
    var nested = try EditorDocument(width: 200, height: 200, layers: [Layer(name: "L", nodes: [.group(group)])])
    var translated = nested
    let nodeTranslated = translated.translateNode(id: path.id, documentDX: 10, documentDY: 8)
    #expect(nodeTranslated)
    guard case .group(let translatedGroup) = translated.layers[0].nodes[0],
        case .path(let translatedPath) = translatedGroup.children[0]
    else { return }
    #expect(translatedPath.transform.tx == 5)
    #expect(translatedPath.transform.ty == 2)
    let nestedMoved = nested.movePathAnchor(id: path.id, subpath: 0, segment: 0, documentDelta: Point(x: 10, y: 8))
    #expect(nestedMoved)
    guard case .group(let movedGroup) = nested.layers[0].nodes[0], case .path(let moved) = movedGroup.children[0] else {
        return
    }
    #expect(moved.segments[0].start.distance(to: Point(x: 2, y: -5)) < 1e-9)

    var singular = line(0)
    singular.transform = AffineTransform(a: 0, b: 0, c: 0, d: 1)
    var singularDoc = try EditorDocument(width: 200, height: 200, layers: [Layer(name: "L", nodes: [.path(singular)])])
    let singularMoved = singularDoc.movePathAnchor(
        id: singular.id, subpath: 0, segment: 0, documentDelta: Point(x: 1, y: 1))
    #expect(!singularMoved)
    guard case .path(let unchanged) = singularDoc.layers[0].nodes[0] else { return }
    #expect(unchanged.segments[0].start == singular.segments[0].start)
}

@Test func groupUngroupAndCompoundReleasePreserveVisualBounds() throws {
    let a = line(0)
    let b = line(30)
    let rotated = GroupNode(
        transform: AffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 100, ty: 20), children: [.path(a), .path(b)])
    let groupDoc = try EditorDocument(width: 200, height: 200, layers: [Layer(name: "L", nodes: [.group(rotated)])])
    let before = [try #require(groupDoc.visualBounds(for: a.id)), try #require(groupDoc.visualBounds(for: b.id))]
    var history = CommandHistory(document: groupDoc)
    try history.perform(SceneCommands.ungroup(layerID: groupDoc.layers[0].id, groupID: rotated.id))
    let after = [
        try #require(history.document.visualBounds(for: a.id)), try #require(history.document.visualBounds(for: b.id)),
    ]
    #expect(after == before)

    let layer = Layer(name: "L", nodes: [.path(a), .path(b)])
    var compoundHistory = CommandHistory(document: try EditorDocument(width: 200, height: 200, layers: [layer]))
    let original = compoundHistory.document.layers[0].nodes.compactMap(\.visualBounds)
    try compoundHistory.perform(SceneCommands.makeCompound(layerID: layer.id, pathIDs: [a.id, b.id]))
    try compoundHistory.perform(SceneCommands.releaseCompound(layerID: layer.id, pathID: a.id))
    #expect(compoundHistory.document.layers[0].nodes.compactMap(\.visualBounds) == original)
}

@Test func directAnchorDeletionIsUndoable() throws {
    let path = PathObject(segments: [
        CubicBezier(
            start: Point(x: 0, y: 0), control1: Point(x: 0, y: 0), control2: Point(x: 10, y: 0), end: Point(x: 10, y: 0)
        ),
        CubicBezier(
            start: Point(x: 10, y: 0), control1: Point(x: 10, y: 0), control2: Point(x: 20, y: 0),
            end: Point(x: 20, y: 0)),
    ])
    var history = CommandHistory(
        document: try EditorDocument(width: 100, height: 100, layers: [Layer(name: "L", nodes: [.path(path)])]))
    try history.perform(SceneCommands.deleteAnchor(pathID: path.id, subpath: 0, segment: 1))
    #expect(history.document.path(id: path.id)?.segments.count == 1)
    history.undo()
    #expect(history.document.path(id: path.id)?.segments.count == 2)
}

@Test func directionHandleMovementUsesDocumentDeltaAndIsUndoable() throws {
    var path = line(0)
    path.transform = AffineTransform(a: 0, b: 1, c: -1, d: 0)
    let group = GroupNode(transform: AffineTransform(a: 2, b: 0, c: 0, d: 4), children: [.path(path)])
    var history = CommandHistory(
        document: try EditorDocument(width: 200, height: 200, layers: [Layer(name: "L", nodes: [.group(group)])]))
    let before = try #require(history.document.path(id: path.id)?.segments[0].control1)
    try history.perform(
        SceneCommands.moveControl(pathID: path.id, subpath: 0, segment: 0, control: 1, delta: Point(x: 10, y: 8)))
    let after = try #require(history.document.path(id: path.id)?.segments[0].control1)
    #expect(after.distance(to: Point(x: before.x + 2, y: before.y - 5)) < 1e-9)
    history.undo()
    #expect(history.document.path(id: path.id)?.segments[0].control1 == before)
}
