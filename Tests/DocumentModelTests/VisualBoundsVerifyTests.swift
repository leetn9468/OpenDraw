import DocumentModel
import Foundation
import Geometry
import Testing

private func rectPath(_ rect: Rect, style: PathStyle, transform: Geometry.AffineTransform) -> PathObject {
    let points = [
        Point(x: rect.minX, y: rect.minY), Point(x: rect.maxX, y: rect.minY), Point(x: rect.maxX, y: rect.maxY),
        Point(x: rect.minX, y: rect.maxY), Point(x: rect.minX, y: rect.minY),
    ]
    return PathObject(
        segments: zip(points, points.dropFirst()).map { CubicBezier(start: $0, control1: $0, control2: $1, end: $1) },
        isClosed: true, style: style, transform: transform)
}
private func expectRect(_ actual: Rect?, _ expected: Rect, tolerance: Double = 1e-6) {
    #expect(abs((actual?.minX ?? .infinity) - expected.minX) < tolerance)
    #expect(abs((actual?.minY ?? .infinity) - expected.minY) < tolerance)
    #expect(abs((actual?.maxX ?? .infinity) - expected.maxX) < tolerance)
    #expect(abs((actual?.maxY ?? .infinity) - expected.maxY) < tolerance)
}

@Test func verify004VisualBoundsFrozenExamples() {
    let r45 = Double.pi / 4
    let t45 = Geometry.AffineTransform(a: cos(r45), b: sin(r45), c: -sin(r45), d: cos(r45))
    let round = PathStyle(stroke: .black, strokeWidth: 10, lineCap: .round, lineJoin: .round)
    expectRect(
        rectPath(Rect(minX: 0, minY: 0, maxX: 100, maxY: 50), style: round, transform: t45).visualBounds,
        Rect(minX: -40.3553390593, minY: -5, maxX: 75.7106781187, maxY: 111.0660171780))
    let r37 = 37 * Double.pi / 180
    let t37 = Geometry.AffineTransform(a: cos(r37), b: sin(r37), c: -sin(r37), d: cos(r37), tx: 12, ty: -8)
    let miter = PathStyle(stroke: .black, strokeWidth: 6, lineCap: .butt, lineJoin: .miter, miterLimit: 4)
    expectRect(
        rectPath(Rect(minX: 10, minY: 20, maxX: 60, maxY: 45), style: miter, transform: t37).visualBounds,
        Rect(minX: -19.0953209414, minY: 1.9908604325, maxX: 59.8818301398, maxY: 76.0474993413))
    let point = Point(x: 5, y: 5)
    let single = PathObject(
        segments: [CubicBezier(start: point, control1: point, control2: point, end: point)],
        style: PathStyle(stroke: .black, strokeWidth: 6, lineCap: .square, lineJoin: .round))
    expectRect(
        single.visualBounds, Rect(minX: 0.7573593129, minY: 0.7573593129, maxX: 9.2426406871, maxY: 9.2426406871))
    #expect((PathStyle(stroke: .black, strokeWidth: 4, lineJoin: .miter, miterLimit: 10).strokeWidth / 2) * 10 == 20)
}
