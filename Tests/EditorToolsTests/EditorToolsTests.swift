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

@Test func testVerify013PivotRotationAndHalfAwaySnapping() {
    let pivot = Point(x: 10, y: 20)
    let transform = TransformInteractions.rotation(about: pivot, radians: .pi / 2)
    #expect(transform.applying(to: pivot).distance(to: pivot) < 1e-9)
    #expect(transform.applying(to: Point(x: 15, y: 20)).distance(to: Point(x: 10, y: 25)) < 1e-9)
    #expect(abs(transform.a) < 1e-9 && abs(transform.b - 1) < 1e-9)
    #expect(abs(transform.c + 1) < 1e-9 && abs(transform.d) < 1e-9)
    #expect(abs(transform.tx - 30) < 1e-9 && abs(transform.ty - 10) < 1e-9)
    #expect(TransformInteractions.rotation(about: pivot, radians: 1.234).applying(to: pivot) == pivot)
    let point = Point(x: 4, y: -9)
    #expect(TransformInteractions.rotation(about: pivot, radians: 0).applying(to: point) == point)
    #expect(TransformInteractions.snappedRotation(radians: 0.27, constrain: false) == 0.27)
    #expect(abs(TransformInteractions.snappedRotation(radians: 0.27, constrain: true) - .pi / 12) < 1e-9)
    #expect(abs(TransformInteractions.snappedRotation(radians: -0.27, constrain: true) + .pi / 12) < 1e-9)
    #expect((Double.pi / 8) / (Double.pi / 12) == 1.5)
    #expect(TransformInteractions.snappedRotation(radians: .pi / 8, constrain: true) == .pi / 6)
    let nontrivial = TransformInteractions.rotation(about: Point(x: 3, y: -4), radians: 37 * .pi / 180)
        .applying(to: Point(x: 7.5, y: 2.25))
    #expect(abs(nontrivial.x - 2.8325159005) < 1e-9)
    #expect(abs(nontrivial.y - 3.6996395420) < 1e-9)
}

@Test func testVerify014ZoomAboutPointDomainAndInvariant() throws {
    let pan = try #require(
        TransformInteractions.zoomAbout(
            screenPoint: Point(x: 100, y: 80), oldZoom: 1, newZoom: 2, oldPan: Point(x: 10, y: 20)))
    #expect(pan == Point(x: -80, y: -40))
    let documentBefore = Point(x: (100 - 10) / 1, y: (80 - 20) / 1)
    let documentAfter = Point(x: (100 - pan.x) / 2, y: (80 - pan.y) / 2)
    #expect(documentBefore == documentAfter)
    #expect(
        TransformInteractions.zoomAbout(
            screenPoint: Point(x: 100, y: 80), oldZoom: 2, newZoom: 0.5,
            oldPan: Point(x: -80, y: -40)) == Point(x: 55, y: 50))
    #expect(
        TransformInteractions.zoomAbout(
            screenPoint: Point(x: 100, y: 80), oldZoom: 1, newZoom: 1,
            oldPan: Point(x: 10, y: 20)) == Point(x: 10, y: 20))
    #expect(
        TransformInteractions.zoomAbout(
            screenPoint: Point(x: 123.5, y: 67.25), oldZoom: 1.6, newZoom: 2.4,
            oldPan: Point(x: 12.75, y: -8.5)) == Point(x: -42.625, y: -46.375))
    for invalid in [0.0, -1.0, .infinity, .nan] {
        #expect(
            TransformInteractions.zoomAbout(
                screenPoint: Point(x: 1, y: 1), oldZoom: 1, newZoom: invalid,
                oldPan: Point(x: 2, y: 3)) == nil)
        #expect(
            TransformInteractions.zoomAbout(
                screenPoint: Point(x: 1, y: 1), oldZoom: invalid, newZoom: 1,
                oldPan: Point(x: 2, y: 3)) == nil)
    }
    #expect(TransformInteractions.minZoom == 0.05)
    #expect(TransformInteractions.maxZoom == 64)
    #expect(TransformInteractions.clampedZoom(0) == 0.05)
    #expect(TransformInteractions.clampedZoom(100) == 64)
}
