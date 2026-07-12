import DocumentFormats
import DocumentModel
import Foundation
import Geometry
import Testing

@Test func v4RoundTripPreservesMixedOrderGroupsAndCompoundPaths() throws {
    let a = BezierPath(
        segments: [
            CubicBezier(
                start: Point(x: 0, y: 0), control1: Point(x: 0, y: 0), control2: Point(x: 10, y: 0),
                end: Point(x: 10, y: 0))
        ], isClosed: true)
    let b = BezierPath(
        segments: [
            CubicBezier(
                start: Point(x: 3, y: 3), control1: Point(x: 3, y: 3), control2: Point(x: 7, y: 3),
                end: Point(x: 7, y: 3))
        ], isClosed: true)
    let compound = PathObject(path: CompoundPath(subpaths: [a, b], fillRule: .evenOdd))
    let text = TextObject(text: "middle", origin: Point(x: 1, y: 1))
    let image = ImageObject(
        frame: Rect(minX: 0, minY: 0, maxX: 2, maxY: 2), storage: .linked(relativePath: "asset.png"), pixelWidth: 2,
        pixelHeight: 2)
    let group = GroupNode(name: "Nested", children: [.text(text), .path(compound)])
    let document = try EditorDocument(
        width: 100, height: 100,
        layers: [Layer(name: "Mixed", nodes: [.image(image), .group(group), .path(PathObject(path: compound.path))])])
    let codec = NativeDocumentCodec()
    let reopened = try codec.decode(codec.encode(document))
    #expect(reopened == document)
    guard case .image = reopened.layers[0].nodes[0], case .group(let restoredGroup) = reopened.layers[0].nodes[1],
        case .path(let restoredPath) = restoredGroup.children[1]
    else {
        Issue.record("Node order changed")
        return
    }
    #expect(restoredPath.path.subpaths.count == 2)
    #expect(restoredPath.path.fillRule == .evenOdd)
}
