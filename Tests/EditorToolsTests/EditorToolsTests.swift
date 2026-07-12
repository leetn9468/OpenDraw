import DocumentModel
import EditorTools
import Geometry
import Testing

@Test func penStateCreatesOpenAndClosedPaths() {
    var pen = PenToolState()
    pen.addAnchor(Point(x: 0, y: 0))
    #expect(pen.finish(close: false) == nil)
    pen.addAnchor(Point(x: 0, y: 0))
    pen.addAnchor(Point(x: 10, y: 10))
    pen.addAnchor(Point(x: 20, y: 0))
    let path = pen.finish(close: true)
    #expect(path?.segments.count == 2)
    #expect(path?.path.subpaths.first?.isClosed == true)
}

@Test func primitiveAndSnapPolicies() {
    #expect(ShapeFactory.rectangle(from: Point(x: 0, y: 0), to: Point(x: 0, y: 10)) == nil)
    let square = ShapeFactory.rectangle(from: Point(x: 0, y: 0), to: Point(x: 20, y: 10), constrained: true)
    #expect(square?.localBounds?.width == square?.localBounds?.height)
    #expect(ShapeFactory.ellipse(in: Rect(minX: 0, minY: 0, maxX: 100, maxY: 50))?.segments.count == 4)
    #expect(SnapPolicy(gridSpacing: 10).snap(Point(x: 9, y: 11), zoom: 1) == Point(x: 10, y: 10))
}

@Test func spatialIndexReturnsNearbyCandidates() {
    let first = ShapeFactory.rectangle(from: Point(x: 0, y: 0), to: Point(x: 20, y: 20))!
    let second = ShapeFactory.rectangle(from: Point(x: 500, y: 500), to: Point(x: 520, y: 520))!
    let index = SpatialIndex(paths: [first, second], cellSize: 100)
    #expect(index.candidates(at: Point(x: 10, y: 10)) == [first.id])
    #expect(index.candidates(at: Point(x: 510, y: 510)) == [second.id])
    #expect(index.candidates(at: Point(x: 250, y: 250)).isEmpty)
}

@Test func preciseSelectionRejectsBoundsFalsePositiveAndRespectsLockedLayers() throws {
    let triangle = PathObject(
        segments: [
            CubicBezier(
                start: Point(x: 0, y: 0), control1: Point(x: 0, y: 0), control2: Point(x: 100, y: 0),
                end: Point(x: 100, y: 0)),
            CubicBezier(
                start: Point(x: 100, y: 0), control1: Point(x: 100, y: 0), control2: Point(x: 0, y: 100),
                end: Point(x: 0, y: 100)),
        ], isClosed: true, style: PathStyle(fill: .black, stroke: nil, strokeWidth: 0))
    let tool = SelectionTool()
    let document = try EditorDocument(
        width: 200, height: 200, layers: [Layer(name: "L", nodes: [.path(triangle)])])
    #expect(tool.hitTest(document, pointer: Point(x: 10, y: 10), zoom: 1) == triangle.id)
    #expect(tool.hitTest(document, pointer: Point(x: 90, y: 90), zoom: 1) == nil)
    var locked = document
    locked.layers[0].isLocked = true
    #expect(tool.hitTest(locked, pointer: Point(x: 10, y: 10), zoom: 1) == nil)
    var hidden = document
    hidden.layers[0].isVisible = false
    #expect(tool.hitTest(hidden, pointer: Point(x: 10, y: 10), zoom: 1) == nil)
}
