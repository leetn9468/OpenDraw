import Geometry
import Testing

@Test func verify002BezierEvaluationFrozenExamples() {
    let curve = CubicBezier(
        start: Point(x: 0, y: 0), control1: Point(x: 0, y: 100), control2: Point(x: 100, y: 100),
        end: Point(x: 100, y: 0))
    #expect(abs(curve.point(at: 0.5).x - 50) < 1e-9)
    #expect(abs(curve.point(at: 0.5).y - 75) < 1e-9)
    #expect(abs(curve.point(at: 0.25).x - 15.625) < 1e-9)
    #expect(abs(curve.point(at: 0.25).y - 56.25) < 1e-9)
    let p = Point(x: 5, y: 5)
    let constant = CubicBezier(start: p, control1: p, control2: p, end: p)
    #expect(constant.point(at: 0.7) == p)
}
