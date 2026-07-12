import DocumentModel
import EditorTools
import Geometry
import Testing

@Test func accessibilityTreeExposesDocumentLayersSelectionAndFrames() throws {
    let path = ShapeFactory.rectangle(from: Point(x: 0, y: 0), to: Point(x: 20, y: 20))!
    let document = try EditorDocument(width: 100, height: 100, layers: [Layer(name: "Artwork", nodes: [.path(path)])])
    let tree = AccessibilityTree.build(document: document, selectedIDs: [path.id])
    #expect(tree.role == .document)
    #expect(tree.children[0].label == "Artwork")
    #expect(tree.children[0].children[0].label == "Path, selected")
    #expect(tree.children[0].children[0].frame != nil)
}
