import Testing

@testable import Geometry

private let curve = CubicBezier(
    start: Point(x: 0, y: 0), control1: Point(x: 0, y: 100), control2: Point(x: 100, y: 100), end: Point(x: 100, y: 0))

@Test func bezierEndpointsAndMidpoint() {
    #expect(curve.point(at: 0) == Point(x: 0, y: 0))
    #expect(curve.point(at: 1) == Point(x: 100, y: 0))
    #expect(abs(curve.point(at: 0.5).x - 50) < 1e-12)
    #expect(abs(curve.point(at: 0.5).y - 75) < 1e-12)
}

@Test func curveAndZoomInvariantAnchorHitTesting() {
    #expect(curve.hitTest(Point(x: 50, y: 74), tolerance: 2))
    #expect(!curve.hitTest(Point(x: 50, y: 60), tolerance: 2))
    #expect(HitTesting.anchor(at: Point(x: 10, y: 10), query: Point(x: 12, y: 10), screenTolerance: 4, zoom: 2))
    #expect(!HitTesting.anchor(at: Point(x: 10, y: 10), query: Point(x: 12.1, y: 10), screenTolerance: 4, zoom: 2))
}

@Test func identityTransformPropertySamples() {
    for value in stride(from: -1000.0, through: 1000, by: 31.25) {
        let point = Point(x: value, y: -value / 3)
        #expect(AffineTransform.identity.applying(to: point) == point)
    }
}

@Test func swiftGeometryBenchmark() {
    let start = ContinuousClock.now
    var hits = 0
    for index in 0..<20_000 {
        if curve.hitTest(Point(x: Double(index % 100), y: 75), tolerance: 2, subdivisions: 32) { hits += 1 }
    }
    #expect(hits > 0)
    #expect(start.duration(to: .now) < .seconds(5))
}

@Test func subdivisionFlatteningAndBounds() {
    let halves = curve.split()
    #expect(halves.0.end == halves.1.start)
    #expect(halves.0.end == curve.point(at: 0.5))
    let points = curve.flattened(tolerance: 0.25)
    #expect(points.first == curve.start)
    #expect(points.last == curve.end)
    #expect(points.count > 2)
    let tight = curve.tightBounds
    let conservative = curve.conservativeBounds
    #expect(conservative.contains(Point(x: tight.minX, y: tight.minY)))
    #expect(conservative.contains(Point(x: tight.maxX, y: tight.maxY)))
}

@Test func degenerateCurveIsStable() {
    let point = Point(x: 4, y: 9)
    let degenerate = CubicBezier(start: point, control1: point, control2: point, end: point)
    #expect(degenerate.flattened(tolerance: 0.1) == [point, point])
    #expect(degenerate.hitTest(Point(x: 4.05, y: 9), tolerance: 0.1))
}

@Test func collinearBacktrackingAndSubdivisionCountAreHonored() {
    let backtracking = CubicBezier(
        start: Point(x: 0, y: 0), control1: Point(x: 100, y: 0), control2: Point(x: -100, y: 0),
        end: Point(x: 10, y: 0))
    #expect(backtracking.flattened(tolerance: 0.1).count > 2)
    #expect(backtracking.hitTest(Point(x: 25, y: 0), tolerance: 0.5, subdivisions: 64))
    #expect(!backtracking.hitTest(Point(x: 25, y: 0), tolerance: 0.5, subdivisions: 1))
}

@Test func testVerify015DamageRectangleUnionAndIntersection() {
    let a = Rect(minX: 0, minY: 0, maxX: 10, maxY: 10)
    let b = Rect(minX: 5, minY: -2, maxX: 12, maxY: 8)
    #expect(a.union(b) == Rect(minX: 0, minY: -2, maxX: 12, maxY: 10))
    #expect(a.intersection(b) == Rect(minX: 5, minY: 0, maxX: 10, maxY: 8))
    #expect(a.intersection(Rect(minX: 20, minY: 20, maxX: 30, maxY: 30)) == nil)
}
