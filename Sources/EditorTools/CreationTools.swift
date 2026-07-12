import DocumentModel
import EditorCore
import Foundation
import Geometry

public enum ToolModifier: Hashable, Sendable { case constrain, fromCenter, option }
public enum ActiveTool: String, Sendable { case selection, directSelection, pen, rectangle, ellipse, text }

public struct SnapPolicy: Sendable {
    public var gridSpacing: Double?
    public var toleranceInScreenPoints: Double
    public init(gridSpacing: Double? = nil, toleranceInScreenPoints: Double = 6) {
        self.gridSpacing = gridSpacing
        self.toleranceInScreenPoints = toleranceInScreenPoints
    }
    public func snap(_ point: Point, zoom: Double) -> Point {
        guard let gridSpacing, gridSpacing > 0, zoom > 0 else { return point }
        let candidate = Point(
            x: (point.x / gridSpacing).rounded() * gridSpacing, y: (point.y / gridSpacing).rounded() * gridSpacing)
        return candidate.distance(to: point) <= toleranceInScreenPoints / zoom ? candidate : point
    }
    public func shouldSnap(distance: Double, zoom: Double) -> Bool {
        zoom.isFinite && zoom > 0 && distance.isFinite && distance >= 0
            && distance <= toleranceInScreenPoints / zoom
    }
    public func snap(_ point: Point, xCandidates: [Double], yCandidates: [Double], zoom: Double) -> Point {
        guard zoom.isFinite, zoom > 0 else { return point }
        let limit = toleranceInScreenPoints / zoom
        func nearest(_ value: Double, _ candidates: [Double]) -> Double {
            var result = value
            var best = Double.infinity
            for candidate in candidates {
                let distance = abs(candidate - value)
                if distance <= limit, distance < best {
                    best = distance
                    result = candidate
                }
            }
            return result
        }
        return Point(x: nearest(point.x, xCandidates), y: nearest(point.y, yCandidates))
    }
}

public struct PenToolState: Sendable {
    public private(set) var anchors: [Point] = []
    public init() {}
    public mutating func addAnchor(_ point: Point) { anchors.append(point) }
    public mutating func cancelLast() { if !anchors.isEmpty { anchors.removeLast() } }
    public mutating func finish(close: Bool, style: PathStyle = PathStyle()) -> PathObject? {
        guard anchors.count >= 2 else {
            anchors.removeAll()
            return nil
        }
        let segments = zip(anchors, anchors.dropFirst()).map {
            CubicBezier(start: $0, control1: $0, control2: $1, end: $1)
        }
        let object = PathObject(segments: segments, isClosed: close, style: style)
        anchors.removeAll()
        return object
    }
}

public struct PenAnchor: Equatable, Sendable {
    public var point: Point
    public var incoming: Point
    public var outgoing: Point
    public init(point: Point, incoming: Point? = nil, outgoing: Point? = nil) {
        self.point = point
        self.incoming = incoming ?? point
        self.outgoing = outgoing ?? point
    }
}

public struct SmoothPenToolState: Sendable {
    public private(set) var anchors: [PenAnchor] = []
    public init() {}
    public mutating func addCorner(_ point: Point) { anchors.append(PenAnchor(point: point)) }
    public mutating func reset() { anchors.removeAll() }
    public mutating func addSmooth(_ point: Point, outgoing: Point) {
        anchors.append(
            PenAnchor(
                point: point,
                incoming: TransformInteractions.mirroredHandle(anchor: point, outgoing: outgoing), outgoing: outgoing))
    }
    public func preview(to point: Point) -> CubicBezier? {
        guard let last = anchors.last else { return nil }
        return CubicBezier(start: last.point, control1: last.outgoing, control2: point, end: point)
    }
    public mutating func finish(close: Bool, style: PathStyle = PathStyle()) -> PathObject? {
        guard anchors.count >= 2 else {
            anchors.removeAll()
            return nil
        }
        var segments = zip(anchors, anchors.dropFirst()).map {
            CubicBezier(start: $0.point, control1: $0.outgoing, control2: $1.incoming, end: $1.point)
        }
        if close, let first = anchors.first, let last = anchors.last {
            segments.append(
                CubicBezier(start: last.point, control1: last.outgoing, control2: first.incoming, end: first.point))
        }
        anchors.removeAll()
        return PathObject(segments: segments, isClosed: close, style: style)
    }
}

public enum ShapeFactory {
    public static func rectangle(
        from start: Point, to end: Point, constrained: Bool = false, style: PathStyle = PathStyle(fill: .white)
    ) -> PathObject? {
        var end = end
        if constrained {
            let side = max(abs(end.x - start.x), abs(end.y - start.y))
            end = Point(x: start.x + copysign(side, end.x - start.x), y: start.y + copysign(side, end.y - start.y))
        }
        guard start.x != end.x, start.y != end.y else { return nil }
        let r = Rect(minX: start.x, minY: start.y, maxX: end.x, maxY: end.y)
        let p = [
            Point(x: r.minX, y: r.minY), Point(x: r.maxX, y: r.minY), Point(x: r.maxX, y: r.maxY),
            Point(x: r.minX, y: r.maxY), Point(x: r.minX, y: r.minY),
        ]
        return PathObject(
            segments: zip(p, p.dropFirst()).map { CubicBezier(start: $0, control1: $0, control2: $1, end: $1) },
            isClosed: true, style: style)
    }
    public static func ellipse(in rect: Rect, style: PathStyle = PathStyle(fill: .white)) -> PathObject? {
        guard rect.width > 0, rect.height > 0 else { return nil }
        let k = 0.5522847498307936
        let cx = rect.center.x
        let cy = rect.center.y
        let rx = rect.width / 2
        let ry = rect.height / 2
        let top = Point(x: cx, y: cy - ry)
        let right = Point(x: cx + rx, y: cy)
        let bottom = Point(x: cx, y: cy + ry)
        let left = Point(x: cx - rx, y: cy)
        return PathObject(
            segments: [
                CubicBezier(
                    start: top, control1: Point(x: cx + k * rx, y: cy - ry),
                    control2: Point(x: cx + rx, y: cy - k * ry), end: right),
                CubicBezier(
                    start: right, control1: Point(x: cx + rx, y: cy + k * ry),
                    control2: Point(x: cx + k * rx, y: cy + ry), end: bottom),
                CubicBezier(
                    start: bottom, control1: Point(x: cx - k * rx, y: cy + ry),
                    control2: Point(x: cx - rx, y: cy + k * ry), end: left),
                CubicBezier(
                    start: left, control1: Point(x: cx - rx, y: cy - k * ry),
                    control2: Point(x: cx - k * rx, y: cy - ry), end: top),
            ], isClosed: true, style: style)
    }
}
