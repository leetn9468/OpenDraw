import DocumentModel
import Geometry

/// Frozen BENCH-2b exposure-corridor geometry. The document contains 364
/// device-tile periods, including the 32-device-pixel final period, with 25
/// nodes wholly inside every period.
public enum TileExposureCorridor {
    public static let documentWidth = 46_480.0
    public static let documentHeight = 250.0
    public static let zoom = 2.0
    public static let backingScale = 1.0
    public static let deviceWidth = 92_960
    public static let deviceHeight = 500
    public static let viewportWidth = 800
    public static let viewportHeight = 500
    public static let panAdvance = 256
    public static let advanceCount = 360
    public static let warmupCount = 60
    public static let measuredCount = 300
    public static let periodCount = 364
    public static let nodesPerPeriod = 25
    public static let nodeCount = 9_100

    public static func document() throws -> EditorDocument {
        var nodes: [SceneNode] = []
        nodes.reserveCapacity(nodeCount)
        let documentUnitsPerTile = Double(TileGrid.tileSize) / zoom
        for period in 0..<periodCount {
            let minX = Double(period) * documentUnitsPerTile
            let maxX = min(documentWidth, minX + documentUnitsPerTile)
            let periodWidth = maxX - minX
            let halfWidth = min(1.0, periodWidth / 16)
            for index in 0..<nodesPerPeriod {
                let column = index % 5
                let row = index / 5
                let x = minX + periodWidth * Double(column + 1) / 6
                let y = documentHeight * Double(row + 1) / 6
                nodes.append(
                    .path(
                        corridorRectangle(
                            minX: x - halfWidth, minY: y - 1,
                            maxX: x + halfWidth, maxY: y + 1)))
            }
        }
        precondition(nodes.count == nodeCount)
        return try EditorDocument(
            width: documentWidth, height: documentHeight,
            layers: [Layer(name: "BENCH-2b corridor", nodes: nodes)])
    }

    public static var setupVisibleRect: DevicePixelRect {
        DevicePixelRect(
            minX: 0, minY: 0, maxX: viewportWidth, maxY: viewportHeight)
    }

    public static func visibleRect(frame: Int) -> DevicePixelRect {
        precondition((1...advanceCount).contains(frame))
        let minX = frame * panAdvance
        return DevicePixelRect(
            minX: minX, minY: 0,
            maxX: minX + viewportWidth, maxY: viewportHeight)
    }

    public static func expectedSetupTiles() -> Set<TileCoordinate> {
        Set(
            (0...1).flatMap { row in
                (0...3).map { TileCoordinate(column: $0, row: row) }
            })
    }

    public static func expectedRenderedTiles(frame: Int) -> Set<TileCoordinate> {
        precondition((1...advanceCount).contains(frame))
        return [
            TileCoordinate(column: frame + 3, row: 0),
            TileCoordinate(column: frame + 3, row: 1),
        ]
    }

    private static func corridorRectangle(
        minX: Double, minY: Double, maxX: Double, maxY: Double
    ) -> PathObject {
        let points = [
            Point(x: minX, y: minY), Point(x: maxX, y: minY),
            Point(x: maxX, y: maxY), Point(x: minX, y: maxY),
            Point(x: minX, y: minY),
        ]
        return PathObject(
            segments: zip(points, points.dropFirst()).map {
                CubicBezier(start: $0, control1: $0, control2: $1, end: $1)
            }, isClosed: true, style: PathStyle(fill: .black, stroke: nil))
    }
}
