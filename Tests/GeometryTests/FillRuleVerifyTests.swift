import Geometry
import Testing

private func square(_ min: Double, _ max: Double, clockwise: Bool = false) -> BezierPath {
    var points = [
        Point(x: min, y: min), Point(x: max, y: min), Point(x: max, y: max), Point(x: min, y: max),
        Point(x: min, y: min),
    ]
    if clockwise { points.reverse() }
    return BezierPath(
        segments: zip(points, points.dropFirst()).map { CubicBezier(start: $0, control1: $0, control2: $1, end: $1) },
        isClosed: true)
}

@Test func verify006FillRuleFrozenExamples() {
    let outer = square(0, 10)
    let innerCCW = square(3, 7)
    let innerCW = square(3, 7, clockwise: true)
    let sameNonZero = CompoundPath(subpaths: [outer, innerCCW], fillRule: .nonZero)
    let sameEvenOdd = CompoundPath(subpaths: [outer, innerCCW], fillRule: .evenOdd)
    let oppositeNonZero = CompoundPath(subpaths: [outer, innerCW], fillRule: .nonZero)
    let oppositeEvenOdd = CompoundPath(subpaths: [outer, innerCW], fillRule: .evenOdd)
    #expect(sameNonZero.containmentMetrics(at: Point(x: 5, y: 5)) == ContainmentMetrics(winding: 2, crossings: 2))
    #expect(sameNonZero.contains(Point(x: 5, y: 5)))
    #expect(!sameEvenOdd.contains(Point(x: 5, y: 5)))
    #expect(oppositeNonZero.containmentMetrics(at: Point(x: 5, y: 5)).winding == 0)
    #expect(!oppositeNonZero.contains(Point(x: 5, y: 5)))
    #expect(!oppositeEvenOdd.contains(Point(x: 5, y: 5)))
    #expect(sameNonZero.containmentMetrics(at: Point(x: 1, y: 5)) == ContainmentMetrics(winding: 1, crossings: 3))
    #expect(sameEvenOdd.contains(Point(x: 1, y: 5)))
    for path in [sameNonZero, sameEvenOdd, oppositeNonZero, oppositeEvenOdd] {
        #expect(path.containmentMetrics(at: Point(x: 10, y: 5)) == ContainmentMetrics(winding: 0, crossings: 0))
        #expect(!path.contains(Point(x: 10, y: 5)))
        #expect(!path.contains(Point(x: 12, y: 5)))
    }
}
