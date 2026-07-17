import CoreGraphics
import DocumentModel
import EditorCore
import Geometry

public enum TileCompositeError: Error, Equatable, Sendable {
    case featureDisabled
    case bitmapAllocationFailed
    case invalidTileGeometry
}

public struct TileCompositeFrame: Equatable, Sendable {
    public let grid: TileGrid
    public let visibleCoordinates: [TileCoordinate]
    public let renderedTiles: [TileCoordinate]
    public let hitTiles: [TileCoordinate]
}

/// T1 entry point only. No production caller is wired to this renderer yet.
/// Tiles are rendered by the existing full-scene renderer under an integer
/// device-pixel clip and translation; object-by-object cropping is not used.
public final class TileCompositeRenderer {
    public let cache: TileCache<CGImage>
    public let configuration: TileCacheStartupConfiguration
    private var activeGrid: TileGrid?
    private let renderer = CoreGraphicsRenderer()

    public init(
        configuration: TileCacheStartupConfiguration = .process,
        byteBudget: Int = TileCache<CGImage>.defaultByteBudget
    ) {
        self.configuration = configuration
        cache = TileCache(byteBudget: byteBudget)
    }

    @discardableResult
    public func composite(
        _ document: EditorDocument, in destination: CGContext,
        zoom: Double = 1, backingScale: Double = 1,
        visibleDeviceRect: DevicePixelRect? = nil,
        approvedImages: [ObjectID: CGImage] = [:]
    ) throws -> TileCompositeFrame {
        guard configuration.isEnabled else { throw TileCompositeError.featureDisabled }
        let grid = try TileGrid(
            documentWidth: document.width, documentHeight: document.height,
            zoom: zoom, backingScale: backingScale)
        if let activeGrid, activeGrid != grid {
            cache.bumpGeneration()
        }
        activeGrid = grid
        let visibleRect = visibleDeviceRect ?? grid.fullDeviceRect
        let visible = grid.coordinates(intersecting: visibleRect)
        var rendered: [TileCoordinate] = []
        var hits: [TileCoordinate] = []

        destination.saveGState()
        defer { destination.restoreGState() }
        destination.clip(
            to: CGRect(x: 0, y: 0, width: visibleRect.width, height: visibleRect.height))
        destination.interpolationQuality = .none
        for coordinate in visible {
            guard let geometry = grid.geometry(at: coordinate) else {
                throw TileCompositeError.invalidTileGeometry
            }
            let image: CGImage
            if let cached = cache.value(for: coordinate) {
                image = cached
                hits.append(coordinate)
            } else {
                image = try renderTile(
                    document, geometry: geometry, deviceScale: grid.deviceScale,
                    approvedImages: approvedImages)
                _ = cache.insert(image, geometry: geometry)
                rendered.append(coordinate)
            }
            destination.draw(
                image,
                in: CGRect(
                    x: geometry.originX - visibleRect.minX,
                    y: geometry.originY - visibleRect.minY,
                    width: geometry.width, height: geometry.height))
        }
        return TileCompositeFrame(
            grid: grid, visibleCoordinates: visible, renderedTiles: rendered, hitTiles: hits)
    }

    private func renderTile(
        _ document: EditorDocument, geometry: TileGeometry, deviceScale: Double,
        approvedImages: [ObjectID: CGImage]
    ) throws -> CGImage {
        guard
            let bitmap = CGContext(
                data: nil, width: geometry.width, height: geometry.height,
                bitsPerComponent: 8, bytesPerRow: geometry.width * TileGrid.bytesPerPixel,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw TileCompositeError.bitmapAllocationFailed }
        bitmap.translateBy(x: -CGFloat(geometry.originX), y: -CGFloat(geometry.originY))
        bitmap.clip(
            to: CGRect(
                x: geometry.originX, y: geometry.originY,
                width: geometry.width, height: geometry.height))
        bitmap.scaleBy(x: deviceScale, y: deviceScale)
        renderer.render(document, in: bitmap, approvedImages: approvedImages)
        guard let image = bitmap.makeImage() else {
            throw TileCompositeError.bitmapAllocationFailed
        }
        return image
    }
}
