import DocumentModel
import EditorCore
import Geometry
import Testing

private func nestedDocument(parent: Geometry.AffineTransform) throws -> (EditorDocument, ObjectID) {
    let child = PathObject(segments: [
        CubicBezier(
            start: Point(x: 0, y: 0), control1: Point(x: 0, y: 0), control2: Point(x: 1, y: 1), end: Point(x: 1, y: 1))
    ])
    return (
        try EditorDocument(
            width: 100, height: 100,
            layers: [Layer(name: "L", nodes: [.group(GroupNode(transform: parent, children: [.path(child)]))])]),
        child.id
    )
}

@Test func verify009NestedTranslationExamples() throws {
    var (identity, id1) = try nestedDocument(parent: .identity)
    let moved1 = identity.translateNode(id: id1, documentDX: 8, documentDY: -3)
    #expect(moved1)
    guard case .group(let g1) = identity.layers[0].nodes[0], case .path(let p1) = g1.children[0] else { return }
    #expect(p1.transform.tx == 8)
    #expect(p1.transform.ty == -3)
    var (scaled, id2) = try nestedDocument(parent: Geometry.AffineTransform(a: 2, d: 4, tx: 10, ty: 20))
    let moved2 = scaled.translateNode(id: id2, documentDX: 10, documentDY: 8)
    #expect(moved2)
    let child2 = try #require(scaled.layers[0].nodes.first)
    guard case .group(let g2) = child2, case .path(let p2) = g2.children[0] else { return }
    #expect(p2.transform.tx == 5)
    #expect(p2.transform.ty == 2)
    var (rotated, id3) = try nestedDocument(parent: Geometry.AffineTransform(a: 0, b: 1, c: -1, d: 0))
    let moved3 = rotated.translateNode(id: id3, documentDX: 10, documentDY: 0)
    #expect(moved3)
    guard case .group(let g3) = rotated.layers[0].nodes[0], case .path(let p3) = g3.children[0] else { return }
    #expect(abs(p3.transform.tx) < 1e-9)
    #expect(abs(p3.transform.ty + 10) < 1e-9)
    var (singular, id4) = try nestedDocument(parent: Geometry.AffineTransform(a: 0, b: 0, c: 0, d: 1))
    let original = singular
    let moved4 = singular.translateNode(id: id4, documentDX: 1, documentDY: 1)
    #expect(!moved4)
    #expect(singular == original)
}

@Test func verify009TwoLevelAccumulatedAncestorExample() throws {
    let path = PathObject(segments: [
        CubicBezier(
            start: Point(x: 0, y: 0), control1: Point(x: 0, y: 0), control2: Point(x: 1, y: 1), end: Point(x: 1, y: 1))
    ])
    let inner = GroupNode(name: "Inner", transform: Geometry.AffineTransform(a: 2, d: 4), children: [.path(path)])
    let outer = GroupNode(
        name: "Outer", transform: Geometry.AffineTransform(a: 0, b: 1, c: -1, d: 0), children: [.group(inner)])
    var document = try EditorDocument(width: 100, height: 100, layers: [Layer(name: "L", nodes: [.group(outer)])])
    let moved = document.translateNode(id: path.id, documentDX: 10, documentDY: 6)
    #expect(moved)
    guard case .group(let restoredOuter) = document.layers[0].nodes[0],
        case .group(let restoredInner) = restoredOuter.children[0],
        case .path(let restoredPath) = restoredInner.children[0]
    else {
        Issue.record("Nested path missing")
        return
    }
    #expect(abs(restoredPath.transform.tx - 3) < 1e-9)
    #expect(abs(restoredPath.transform.ty - (-2.5)) < 1e-9)
    let accumulated = inner.transform.concatenating(outer.transform)
    let roundTrip = Point(x: accumulated.a * 3 + accumulated.c * (-2.5), y: accumulated.b * 3 + accumulated.d * (-2.5))
    #expect(abs(roundTrip.x - 10) < 1e-9)
    #expect(abs(roundTrip.y - 6) < 1e-9)
}
