import DocumentModel
import EditorCore
import Geometry
import Testing

private func transformFixture(parent: AffineTransform) throws -> (EditorDocument, ObjectID) {
    let path = PathObject(segments: [
        CubicBezier(
            start: Point(x: 0, y: 0), control1: Point(x: 0, y: 0), control2: Point(x: 10, y: 0), end: Point(x: 10, y: 0)
        )
    ])
    return (
        try EditorDocument(
            width: 200, height: 200,
            layers: [Layer(name: "L", nodes: [.group(GroupNode(transform: parent, children: [.path(path)]))])]), path.id
    )
}

@Test func verify020NestedDocumentTransformComposition() throws {
    var identity = try transformFixture(parent: .identity)
    let identityApplied = identity.0.applyDocumentTransform(id: identity.1, transform: AffineTransform(tx: 10, ty: 8))
    #expect(identityApplied)
    guard case .group(let identityGroup) = identity.0.layers[0].nodes[0],
        case .path(let identityPath) = identityGroup.children[0]
    else { return }
    #expect(identityPath.transform.tx == 10)
    #expect(identityPath.transform.ty == 8)

    var scaled = try transformFixture(parent: AffineTransform(a: 2, b: 0, c: 0, d: 4))
    let scaledApplied = scaled.0.applyDocumentTransform(id: scaled.1, transform: AffineTransform(tx: 10, ty: 8))
    #expect(scaledApplied)
    guard case .group(let group) = scaled.0.layers[0].nodes[0], case .path(let path) = group.children[0] else { return }
    #expect(abs(path.transform.tx - 5) < 1e-9)
    #expect(abs(path.transform.ty - 2) < 1e-9)

    var singular = try transformFixture(parent: AffineTransform(a: 0, b: 0, c: 0, d: 1))
    let before = singular.0
    let singularApplied = singular.0.applyDocumentTransform(id: singular.1, transform: AffineTransform(tx: 1, ty: 1))
    #expect(!singularApplied)
    #expect(singular.0 == before)
}
