import Geometry
import Testing

@Test func verify003BezierBoundsFrozenExamples() {
    let arch = CubicBezier(
        start: Point(x: 0, y: 0), control1: Point(x: 0, y: 100), control2: Point(x: 100, y: 100),
        end: Point(x: 100, y: 0))
    #expect(arch.tightBounds == Rect(minX: 0, minY: 0, maxX: 100, maxY: 75))
    let backtrack = CubicBezier(
        start: Point(x: 0, y: 0), control1: Point(x: -200, y: 0), control2: Point(x: 300, y: 0),
        end: Point(x: 100, y: 0))
    let bounds = backtrack.tightBounds
    #expect(abs(bounds.minX - -48.1980506062) < 1e-6)
    #expect(abs(bounds.maxX - 148.1980506062) < 1e-6)
    #expect(bounds.minY == 0)
    #expect(bounds.maxY == 0)
}
