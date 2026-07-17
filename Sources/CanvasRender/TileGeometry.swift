import DocumentModel
import Foundation
import Geometry

public struct TileCacheStartupConfiguration: Equatable, Sendable {
    public static let process = TileCacheStartupConfiguration(
        isEnabled: ProcessInfo.processInfo.environment["OPENDRAW_TILE_CACHE"] == "1")

    public let isEnabled: Bool

    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}

public enum TileGridError: Error, Equatable, Sendable {
    case invalidDimensionsOrScale
    case dimensionOverflow
}

public struct TileCoordinate: Hashable, Sendable {
    public let column: Int
    public let row: Int

    public init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }
}

public struct DevicePixelRect: Equatable, Sendable {
    public let minX: Int
    public let minY: Int
    public let maxX: Int
    public let maxY: Int

    public init(minX: Int, minY: Int, maxX: Int, maxY: Int) {
        self.minX = min(minX, maxX)
        self.minY = min(minY, maxY)
        self.maxX = max(minX, maxX)
        self.maxY = max(minY, maxY)
    }

    public var width: Int { maxX - minX }
    public var height: Int { maxY - minY }
}

public struct TileGeometry: Equatable, Sendable {
    public let coordinate: TileCoordinate
    public let originX: Int
    public let originY: Int
    public let width: Int
    public let height: Int
    public let byteCount: Int

    public var deviceRect: DevicePixelRect {
        DevicePixelRect(minX: originX, minY: originY, maxX: originX + width, maxY: originY + height)
    }
}

public struct TileGrid: Equatable, Sendable {
    public static let tileSize = 256
    public static let bytesPerPixel = 4
    public static let fullTileByteCount = 256 * 256 * 4

    public let documentWidth: Double
    public let documentHeight: Double
    public let zoom: Double
    public let backingScale: Double
    public let deviceScale: Double
    public let canvasWidth: Int
    public let canvasHeight: Int
    public let columnCount: Int
    public let rowCount: Int

    public init(
        documentWidth: Double, documentHeight: Double, zoom: Double = 1,
        backingScale: Double = 1
    ) throws {
        guard documentWidth.isFinite, documentHeight.isFinite, zoom.isFinite, backingScale.isFinite,
            documentWidth > 0, documentHeight > 0, zoom > 0, backingScale > 0
        else { throw TileGridError.invalidDimensionsOrScale }
        let deviceScale = zoom * backingScale
        guard deviceScale.isFinite, deviceScale > 0 else {
            throw TileGridError.invalidDimensionsOrScale
        }
        let scaledWidth = (documentWidth * deviceScale).rounded(.up)
        let scaledHeight = (documentHeight * deviceScale).rounded(.up)
        guard scaledWidth.isFinite, scaledHeight.isFinite,
            let canvasWidth = Int(exactly: scaledWidth), let canvasHeight = Int(exactly: scaledHeight),
            canvasWidth > 0, canvasHeight > 0
        else { throw TileGridError.dimensionOverflow }

        self.documentWidth = documentWidth
        self.documentHeight = documentHeight
        self.zoom = zoom
        self.backingScale = backingScale
        self.deviceScale = deviceScale
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        columnCount = (canvasWidth - 1) / Self.tileSize + 1
        rowCount = (canvasHeight - 1) / Self.tileSize + 1
    }

    public var fullDeviceRect: DevicePixelRect {
        DevicePixelRect(minX: 0, minY: 0, maxX: canvasWidth, maxY: canvasHeight)
    }

    public func geometry(at coordinate: TileCoordinate) -> TileGeometry? {
        guard coordinate.column >= 0, coordinate.column < columnCount,
            coordinate.row >= 0, coordinate.row < rowCount
        else { return nil }
        let originX = coordinate.column * Self.tileSize
        let originY = coordinate.row * Self.tileSize
        let width = min(Self.tileSize, canvasWidth - originX)
        let height = min(Self.tileSize, canvasHeight - originY)
        let pixels = width.multipliedReportingOverflow(by: height)
        guard !pixels.overflow else { return nil }
        let bytes = pixels.partialValue.multipliedReportingOverflow(by: Self.bytesPerPixel)
        guard !bytes.overflow else { return nil }
        return TileGeometry(
            coordinate: coordinate, originX: originX, originY: originY,
            width: width, height: height, byteCount: bytes.partialValue)
    }

    public func coordinates(intersecting requested: DevicePixelRect) -> [TileCoordinate] {
        let minX = max(0, requested.minX)
        let minY = max(0, requested.minY)
        let maxX = min(canvasWidth, requested.maxX)
        let maxY = min(canvasHeight, requested.maxY)
        guard maxX > minX, maxY > minY else { return [] }
        let firstColumn = minX / Self.tileSize
        let firstRow = minY / Self.tileSize
        let lastColumn = (maxX - 1) / Self.tileSize
        let lastRow = (maxY - 1) / Self.tileSize
        return (firstRow...lastRow).flatMap { row in
            (firstColumn...lastColumn).map { TileCoordinate(column: $0, row: row) }
        }
    }
}

public enum TileDamageMapping: Equatable, Sendable {
    case none
    case tiles(Set<TileCoordinate>)
    case all

    public func resolvedCoordinates(in grid: TileGrid) -> Set<TileCoordinate> {
        switch self {
        case .none: []
        case .tiles(let coordinates): coordinates
        case .all: Set(grid.coordinates(intersecting: grid.fullDeviceRect))
        }
    }
}

public enum TileDamageMapper {
    public static func map(_ damage: DamageRegion?, in grid: TileGrid) -> TileDamageMapping {
        guard let damage else { return .all }
        switch damage {
        case .none:
            return .none
        case .full:
            return .all
        case .rects(let rects):
            var result = Set<TileCoordinate>()
            for rect in rects {
                guard let mapped = coordinates(forInkBounds: rect, in: grid) else { return .all }
                result.formUnion(mapped)
            }
            return result.isEmpty ? .none : .tiles(result)
        }
    }

    public static func coordinates(
        forInkBounds bounds: Geometry.Rect, in grid: TileGrid
    ) -> Set<TileCoordinate>? {
        let values = [bounds.minX, bounds.minY, bounds.maxX, bounds.maxY]
        guard values.allSatisfy(\.isFinite) else { return nil }
        let scale = grid.deviceScale
        let deviceMinX = bounds.minX * scale - 1
        let deviceMinY = bounds.minY * scale - 1
        let deviceMaxX = bounds.maxX * scale + 1
        let deviceMaxY = bounds.maxY * scale + 1
        guard [deviceMinX, deviceMinY, deviceMaxX, deviceMaxY].allSatisfy(\.isFinite) else {
            return nil
        }
        let rawFirstColumn = floor(deviceMinX / Double(TileGrid.tileSize))
        let rawFirstRow = floor(deviceMinY / Double(TileGrid.tileSize))
        let rawLastColumn = ceil(deviceMaxX / Double(TileGrid.tileSize)) - 1
        let rawLastRow = ceil(deviceMaxY / Double(TileGrid.tileSize)) - 1
        guard let firstColumnValue = Int(exactly: rawFirstColumn),
            let firstRowValue = Int(exactly: rawFirstRow),
            let lastColumnValue = Int(exactly: rawLastColumn),
            let lastRowValue = Int(exactly: rawLastRow)
        else { return nil }
        let firstColumn = max(0, firstColumnValue)
        let firstRow = max(0, firstRowValue)
        let lastColumn = min(grid.columnCount - 1, lastColumnValue)
        let lastRow = min(grid.rowCount - 1, lastRowValue)
        guard firstColumn <= lastColumn, firstRow <= lastRow else { return [] }
        return Set(
            (firstRow...lastRow).flatMap { row in
                (firstColumn...lastColumn).map { TileCoordinate(column: $0, row: row) }
            })
    }

    public static func conservativeInkBounds(for node: SceneNode) -> Geometry.Rect? {
        node.conservativeInkBounds
    }
}
