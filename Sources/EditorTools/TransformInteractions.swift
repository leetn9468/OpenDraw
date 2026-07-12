import Darwin
import Geometry

public enum TransformHandle: Sendable, CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
}

public enum TransformInteractions {
    public static let minZoom = 0.05
    public static let maxZoom = 64.0
    public static func clampedZoom(_ requested: Double) -> Double { min(max(requested, minZoom), maxZoom) }
    public static func snappedRotation(radians: Double, constrain: Bool) -> Double {
        guard constrain else { return radians }
        let step = Double.pi / 12
        return (radians / step).rounded() * step
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
