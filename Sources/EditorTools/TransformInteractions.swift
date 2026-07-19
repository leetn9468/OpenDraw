import Darwin
import Geometry

public enum TransformHandle: Sendable, CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
}

public enum TransformInteractions {
    public static let minZoom = 0.05
    public static let maxZoom = 64.0
    public static func clampedZoom(_ requested: Double) -> Double { min(max(requested, minZoom), maxZoom) }
    public static func mirroredHandle(anchor: Point, outgoing: Point) -> Point {
        Point(x: 2 * anchor.x - outgoing.x, y: 2 * anchor.y - outgoing.y)
    }
    public static func scale(
        bounds: Rect, handle: TransformHandle, displacement: Point, uniform: Bool, fromCenter: Bool
    ) -> Point? {
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let multiplier = fromCenter ? 2.0 : 1.0
        var sx = 1.0
        var sy = 1.0
        if [.topLeft, .bottomLeft, .left].contains(handle) { sx -= multiplier * displacement.x / bounds.width }
        if [.topRight, .bottomRight, .right].contains(handle) { sx += multiplier * displacement.x / bounds.width }
        if [.topLeft, .top, .topRight].contains(handle) { sy -= multiplier * displacement.y / bounds.height }
        if [.bottomLeft, .bottom, .bottomRight].contains(handle) { sy += multiplier * displacement.y / bounds.height }
        if uniform, ![.top, .bottom, .left, .right].contains(handle) {
            let magnitude = min(abs(sx), abs(sy))
            sx = copysign(magnitude, sx)
            sy = copysign(magnitude, sy)
        }
        return Point(x: sx, y: sy)
    }
    public static func snappedRotation(radians: Double, constrain: Bool) -> Double {
        guard constrain else { return radians }
        let step = Double.pi / 12
        return (radians / step).rounded() * step
    }
    public static func shouldSnapRotation(globalSnapEnabled: Bool, shiftHeld: Bool) -> Bool {
        globalSnapEnabled || shiftHeld
    }
    public static func rotation(about pivot: Point, radians: Double) -> AffineTransform {
        let c = cos(radians)
        let s = sin(radians)
        return AffineTransform(
            a: c, b: s, c: -s, d: c,
            tx: pivot.x - c * pivot.x + s * pivot.y,
            ty: pivot.y - s * pivot.x - c * pivot.y)
    }
    public static func zoomAbout(
        screenPoint: Point, oldZoom: Double, newZoom: Double, oldPan: Point
    ) -> Point? {
        guard oldZoom.isFinite, newZoom.isFinite, oldZoom > 0, newZoom > 0 else { return nil }
        let documentPoint = Point(
            x: (screenPoint.x - oldPan.x) / oldZoom, y: (screenPoint.y - oldPan.y) / oldZoom)
        return Point(
            x: screenPoint.x - documentPoint.x * newZoom,
            y: screenPoint.y - documentPoint.y * newZoom)
    }
}

public enum MarqueeInteraction {
    public static func hasCrossedThreshold(
        start: Point, current: Point, zoom: Double, thresholdInScreenPoints: Double
    ) -> Bool {
        guard zoom.isFinite, zoom > 0, thresholdInScreenPoints.isFinite, thresholdInScreenPoints >= 0 else {
            return false
        }
        return start.distance(to: current) * zoom >= thresholdInScreenPoints
    }
}
