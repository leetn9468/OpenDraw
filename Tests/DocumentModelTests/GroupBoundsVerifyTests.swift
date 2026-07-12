import DocumentModel
import Foundation
import Geometry
import Testing

@Test func verify005GroupBoundsFrozenExamples() {
    let childBounds = Rect(minX: -40.355339, minY: -5, maxX: 75.710678, maxY: 111.066017)
    let child = SceneNode.text(TextObject(text: "", origin: .init(x: 0, y: 0), layoutBounds: childBounds))
    let inside = SceneNode.text(
        TextObject(text: "", origin: .init(x: 0, y: 0), layoutBounds: Rect(minX: 0, minY: 0, maxX: 20, maxY: 20)))
    #expect(GroupNode(children: []).children.isEmpty)
    #expect(SceneNode.group(GroupNode(children: [])).visualBounds == nil)
    #expect(SceneNode.group(GroupNode(children: [child])).visualBounds == childBounds)
    let angle = -30 * Double.pi / 180
    let transform = Geometry.AffineTransform(
        a: cos(angle), b: sin(angle), c: -sin(angle), d: cos(angle), tx: 100, ty: 50)
    let group = SceneNode.group(GroupNode(transform: transform, children: [child, inside]))
    let expected = Rect(minX: 62.55125125, minY: 7.81453398, maxX: 221.10037899, maxY: 166.36366172)
    let actual = group.visualBounds
    #expect(abs((actual?.minX ?? 0) - expected.minX) < 1e-6)
    #expect(abs((actual?.minY ?? 0) - expected.minY) < 1e-6)
    #expect(abs((actual?.maxX ?? 0) - expected.maxX) < 1e-6)
    #expect(abs((actual?.maxY ?? 0) - expected.maxY) < 1e-6)
}
