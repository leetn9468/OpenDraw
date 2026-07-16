import DocumentModel
import EditorCommands
import EditorTools
import Geometry
import Testing

@Test func accessibilityTreeExposesDocumentLayersSelectionAndFrames() throws {
    let path = ShapeFactory.rectangle(from: Point(x: 0, y: 0), to: Point(x: 20, y: 20))!
    let second = ShapeFactory.rectangle(from: Point(x: 40, y: 0), to: Point(x: 60, y: 20))!
    var history = try DeltaCommandHistory(
        document: EditorDocument(
            width: 100, height: 100, layers: [Layer(name: "Artwork")]))
    let layerID = history.document.layers[0].id
    try history.commit(
        StructuralCommands.paste(
            [.path(path), .path(second)], in: history.document,
            parent: .layer(layerID), at: 0))
    var style = path.style
    style.strokeWidth = 3
    try history.commit(
        ValueSwapCommands.pathStyle(
            in: history.document, nodeID: path.id, newValue: style))
    try history.commit(
        CompositeSceneCommands.documentTransform(
            in: history.document, nodeIDs: [path.id],
            transform: Geometry.AffineTransform(tx: 5, ty: 7)))
    let location = PathAnchorLocation(pathID: path.id, anchorIndex: 0)
    let slice = try AnchorGeometryCommands.slice(
        in: history.document, at: location)
    try history.commit(
        AnchorGeometryCommands.setSlice(
            in: history.document, at: location,
            newValue: slice.translated(dx: 1, dy: 2)))
    try history.commit(
        CompositeSceneCommands.group(
            in: history.document, nodeIDs: [path.id, second.id]))
    let groupID = try #require(history.document.layers[0].nodes.first?.id)
    try history.commit(
        CompositeSceneCommands.ungroup(
            in: history.document, groupID: groupID))
    for value in 101...135 {
        try history.commit(
            ValueSwapCommands.artboardProperties(
                in: history.document,
                newValue: ArtboardProperties(
                    width: Double(value), height: 100, unit: .points)))
    }
    #expect(history.undoDepth > 30)
    for _ in 0..<31 { try history.undo() }
    #expect(history.redoDepth == 31)
    for _ in 0..<31 { try history.redo() }
    let tree = AccessibilityTree.build(
        document: history.document, selectedIDs: [path.id])
    #expect(tree.role == .document)
    #expect(tree.children[0].label == "Artwork")
    #expect(tree.children[0].children[0].label == "Path, selected")
    #expect(tree.children[0].children[0].frame != nil)
}
