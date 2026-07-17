import DocumentModel
import EditorCommands
import Geometry
import Testing

@Test func textTransformDamageUnionsOldAndNewConservativeInkBounds() throws {
    let text = TextObject(
        text: "Damage", origin: Point(x: 20, y: 50), fontName: "Helvetica", fontSize: 24)
    let node = SceneNode.text(text)
    let document = try EditorDocument(
        width: 300, height: 120, layers: [Layer(name: "Text", nodes: [node])])
    let before = try #require(node.visualBounds)
    let translation = Geometry.AffineTransform(tx: 80)
    let command = try ValueSwapCommands.transform(
        in: document, nodeID: text.id, newValue: translation)
    guard case .rect(let damage) = command.damageBounds else {
        Issue.record("Text transform did not produce rectangular damage")
        return
    }
    #expect(damage == before.union(before.transformed(by: translation)))
}
