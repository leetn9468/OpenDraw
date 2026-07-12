import Foundation

public struct Point: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    public func distance(to other: Point) -> Double { hypot(x - other.x, y - other.y) }
}

public struct Vector: Hashable, Codable, Sendable {
    public var dx: Double
    public var dy: Double
    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }
    public var length: Double { hypot(dx, dy) }
}

public struct Rect: Hashable, Codable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double
    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = Swift.min(minX, maxX)
        self.minY = Swift.min(minY, maxY)
        self.maxX = Swift.max(minX, maxX)
        self.maxY = Swift.max(minY, maxY)
    }
    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
    public var center: Point { Point(x: (minX + maxX) / 2, y: (minY + maxY) / 2) }
    public func contains(_ point: Point, tolerance: Double = 0) -> Bool {
        point.x >= minX - tolerance && point.x <= maxX + tolerance && point.y >= minY - tolerance
            && point.y <= maxY + tolerance
    }
    public func union(_ other: Rect) -> Rect {
        Rect(
            minX: min(minX, other.minX), minY: min(minY, other.minY), maxX: max(maxX, other.maxX),
            maxY: max(maxY, other.maxY))
    }
}

public struct AffineTransform: Hashable, Codable, Sendable {
    public var a: Double
    public var b: Double
    public var c: Double
    public var d: Double
    public var tx: Double
    public var ty: Double
    public init(a: Double = 1, b: Double = 0, c: Double = 0, d: Double = 1, tx: Double = 0, ty: Double = 0) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }
    public static let identity = Self()
    public func applying(to p: Point) -> Point { Point(x: a * p.x + c * p.y + tx, y: b * p.x + d * p.y + ty) }
}

public struct CubicBezier: Hashable, Codable, Sendable {
    public var start: Point
    public var control1: Point
    public var control2: Point
    public var end: Point
    public init(start: Point, control1: Point, control2: Point, end: Point) {
        self.start = start
        self.control1 = control1
        self.control2 = control2
        self.end = end
    }

    public func point(at value: Double) -> Point {
        let t = min(max(value, 0), 1)
        let u = 1 - t
        return Point(
            x: u * u * u * start.x + 3 * u * u * t * control1.x + 3 * u * t * t * control2.x + t * t * t * end.x,
            y: u * u * u * start.y + 3 * u * u * t * control1.y + 3 * u * t * t * control2.y + t * t * t * end.y)
    }
    public func split(at value: Double = 0.5) -> (CubicBezier, CubicBezier) {
        let t = min(max(value, 0), 1)
        func lerp(_ a: Point, _ b: Point) -> Point { Point(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t) }
        let a = lerp(start, control1)
        let b = lerp(control1, control2)
        let c = lerp(control2, end)
        let d = lerp(a, b)
        let e = lerp(b, c)
        let m = lerp(d, e)
        return (
            Self(start: start, control1: a, control2: d, end: m), Self(start: m, control1: e, control2: c, end: end)
        )
    }
    public var conservativeBounds: Rect {
        Rect(
            minX: min(start.x, control1.x, control2.x, end.x), minY: min(start.y, control1.y, control2.y, end.y),
            maxX: max(start.x, control1.x, control2.x, end.x), maxY: max(start.y, control1.y, control2.y, end.y))
    }
    public var tightBounds: Rect {
        var xs = [start.x, end.x]
        var ys = [start.y, end.y]
        for t in Self.extrema(start.x, control1.x, control2.x, end.x) { xs.append(point(at: t).x) }
        for t in Self.extrema(start.y, control1.y, control2.y, end.y) { ys.append(point(at: t).y) }
        return Rect(minX: xs.min()!, minY: ys.min()!, maxX: xs.max()!, maxY: ys.max()!)
    }
    public func flattened(tolerance: Double) -> [Point] {
        guard tolerance.isFinite, tolerance > 0 else { return [start, end] }
        var result = [start]
        flatten(into: &result, tolerance: tolerance, depth: 0)
        return result
    }
    public func hitTest(_ query: Point, tolerance: Double, subdivisions: Int = 64) -> Bool {
        guard tolerance >= 0, subdivisions > 0 else { return false }
        let points = flattened(tolerance: max(tolerance / 2, 0.001))
        return zip(points, points.dropFirst()).contains { Self.segmentDistance(query, $0, $1) <= tolerance }
    }
    private func flatten(into result: inout [Point], tolerance: Double, depth: Int) {
        if max(Self.segmentDistance(control1, start, end), Self.segmentDistance(control2, start, end)) <= tolerance
            || depth >= 20
        {
            result.append(end)
            return
        }
        let halves = split()
        halves.0.flatten(into: &result, tolerance: tolerance, depth: depth + 1)
        halves.1.flatten(into: &result, tolerance: tolerance, depth: depth + 1)
    }
    private static func segmentDistance(_ p: Point, _ a: Point, _ b: Point) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let squared = dx * dx + dy * dy
        guard squared > 1e-24 else { return p.distance(to: a) }
        let t = min(max(((p.x - a.x) * dx + (p.y - a.y) * dy) / squared, 0), 1)
        return p.distance(to: Point(x: a.x + t * dx, y: a.y + t * dy))
    }
    private static func extrema(_ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double) -> [Double] {
        let a = -p0 + 3 * p1 - 3 * p2 + p3
        let b = 2 * (p0 - 2 * p1 + p2)
        let c = p1 - p0
        if abs(a) < 1e-12 { return abs(b) < 1e-12 ? [] : [-c / b].filter { $0 > 0 && $0 < 1 } }
        let disc = b * b - 4 * a * c
        guard disc >= 0 else { return [] }
        let root = sqrt(disc)
        return [(-b + root) / (2 * a), (-b - root) / (2 * a)].filter { $0 > 0 && $0 < 1 }
    }
}

public enum FillRule: String, Codable, Sendable { case nonZero, evenOdd }

public struct BezierPath: Hashable, Codable, Sendable {
    public var segments: [CubicBezier]
    public var isClosed: Bool
    public var fillRule: FillRule
    public init(segments: [CubicBezier], isClosed: Bool = false, fillRule: FillRule = .nonZero) {
        self.segments = segments
        self.isClosed = isClosed
        self.fillRule = fillRule
    }
    public var bounds: Rect? {
        guard let first = segments.first?.tightBounds else { return nil }
        return segments.dropFirst().reduce(first) { $0.union($1.tightBounds) }
    }
}

public enum HitTesting {
    public static func anchor(at anchor: Point, query: Point, screenTolerance: Double, zoom: Double) -> Bool {
        guard zoom.isFinite, zoom > 0 else { return false }
        return anchor.distance(to: query) <= screenTolerance / zoom
    }
}
