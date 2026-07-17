import CoreGraphics
import DocumentModel
import EditorCommands
import EditorCore
import Foundation
import Geometry

public enum TileCompositeError: Error, Equatable, Sendable {
    case bitmapAllocationFailed
    case invalidTileGeometry
}

public struct TileCompositeFrame: Equatable, Sendable {
    public let grid: TileGrid
    public let visibleCoordinates: [TileCoordinate]
    public let renderedTiles: [TileCoordinate]
    public let hitTiles: [TileCoordinate]
}

public enum TileInvalidationReason: Equatable, Sendable {
    case documentChange(EditorCommands.DocumentChange.Kind)
    case deviceScaleChange
}

public struct TileInvalidationRecord: Equatable, Sendable {
    public let sequence: UInt64
    public let reason: TileInvalidationReason
    public let damage: DocumentDamage?
    public let invalidatedCoordinates: Set<TileCoordinate>
    public let generationBefore: UInt64
    public let generationAfter: UInt64

    public var didBumpGeneration: Bool { generationBefore != generationAfter }
}

/// The production renderer. Tiles are rendered by the full-scene renderer
/// under an integer device-pixel clip and translation; conservative root-node
/// culling is allowed, but object-by-object cropping is not used.
public final class TileCompositeRenderer: @unchecked Sendable {
    public let cache: TileCache<CGImage>
    private let stateLock = NSLock()
    private var activeGrid: TileGrid?
    private var observation: DocumentChangeObservation?
    private var nextInvalidationSequence: UInt64 = 0
    private var invalidationLog: [TileInvalidationRecord] = []
    private var spatialIndexNeedsRebuild = true
    private var spatialIndexGrid: TileGrid?
    private var spatialIndexEnabled = false
    private var rootNodeIndicesByTile: [TileCoordinate: [[Int]]] = [:]
    private let renderer = CoreGraphicsRenderer()

    public init(byteBudget: Int = TileCache<CGImage>.defaultByteBudget) {
        cache = TileCache(byteBudget: byteBudget)
    }

    deinit { observation?.cancel() }

    /// Installs the single typed-change choke point used by commands,
    /// undo/redo, and live gesture publication.
    public func subscribe(to history: DeltaCommandHistory) {
        let replacement = history.observeChanges { [weak self] change in
            self?.consume(change)
        }
        let previous = stateLock.withLock {
            let previous = observation
            observation = replacement
            spatialIndexNeedsRebuild = true
            return previous
        }
        previous?.cancel()
    }

    public func unsubscribe() {
        let previous = stateLock.withLock {
            let previous = observation
            observation = nil
            return previous
        }
        previous?.cancel()
    }

    public var invalidationRecords: [TileInvalidationRecord] {
        stateLock.withLock { invalidationLog }
    }

    public func clearInvalidationRecords() {
        stateLock.withLock { invalidationLog.removeAll(keepingCapacity: true) }
    }

    @discardableResult
    public func composite(
        _ document: EditorDocument, in destination: CGContext,
        zoom: Double = 1, backingScale: Double = 1,
        visibleDeviceRect: DevicePixelRect? = nil,
        approvedImages: [ObjectID: CGImage] = [:]
    ) throws -> TileCompositeFrame {
        try stateLock.withLock {
            try compositeLocked(
                document, in: destination, zoom: zoom, backingScale: backingScale,
                visibleDeviceRect: visibleDeviceRect, approvedImages: approvedImages,
                layout: .viewportOrigin)
        }
    }

    /// Composites into a destination whose current user space is document
    /// coordinates. CanvasView uses this entry so overlays retain their
    /// existing document-space geometry and line-width behavior.
    @discardableResult
    public func compositeDocumentCoordinates(
        _ document: EditorDocument, in destination: CGContext,
        zoom: Double = 1, backingScale: Double = 1,
        visibleDeviceRect: DevicePixelRect? = nil,
        approvedImages: [ObjectID: CGImage] = [:]
    ) throws -> TileCompositeFrame {
        try stateLock.withLock {
            try compositeLocked(
                document, in: destination, zoom: zoom, backingScale: backingScale,
                visibleDeviceRect: visibleDeviceRect, approvedImages: approvedImages,
                layout: .documentCoordinates)
        }
    }

    /// OD-6 keeps continuous zoom gestures direct, but the production caller
    /// still enters through the tile renderer, which owns this miss renderer.
    public func renderZoomGestureDirect(
        _ document: EditorDocument, in destination: CGContext,
        viewport: RenderViewport, approvedImages: [ObjectID: CGImage] = [:]
    ) {
        renderer.render(document, in: destination, viewport: viewport, approvedImages: approvedImages)
    }

    private enum DestinationLayout {
        case viewportOrigin
        case documentCoordinates
    }

    private func compositeLocked(
        _ document: EditorDocument, in destination: CGContext,
        zoom: Double, backingScale: Double,
        visibleDeviceRect: DevicePixelRect?, approvedImages: [ObjectID: CGImage],
        layout: DestinationLayout
    ) throws -> TileCompositeFrame {
        let grid = try TileGrid(
            documentWidth: document.width, documentHeight: document.height,
            zoom: zoom, backingScale: backingScale)
        if let activeGrid,
            activeGrid.zoom != grid.zoom || activeGrid.backingScale != grid.backingScale
        {
            recordGenerationBump(reason: .deviceScaleChange, damage: nil)
            spatialIndexNeedsRebuild = true
        }
        activeGrid = grid
        ensureSpatialIndex(for: document, grid: grid)
        let visibleRect = visibleDeviceRect ?? grid.fullDeviceRect
        let visible = grid.coordinates(intersecting: visibleRect)
        var rendered: [TileCoordinate] = []
        var hits: [TileCoordinate] = []

        destination.saveGState()
        defer { destination.restoreGState() }
        switch layout {
        case .viewportOrigin:
            destination.clip(
                to: CGRect(x: 0, y: 0, width: visibleRect.width, height: visibleRect.height))
        case .documentCoordinates:
            destination.clip(
                to: CGRect(
                    x: Double(visibleRect.minX) / grid.deviceScale,
                    y: Double(visibleRect.minY) / grid.deviceScale,
                    width: Double(visibleRect.width) / grid.deviceScale,
                    height: Double(visibleRect.height) / grid.deviceScale))
        }
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
                    approvedImages: approvedImages,
                    rootNodeIndicesByLayer: spatialIndexEnabled
                        ? rootNodeIndicesByTile[coordinate]
                            ?? Array(repeating: [], count: document.layers.count)
                        : nil)
                _ = cache.insert(image, geometry: geometry)
                rendered.append(coordinate)
            }
            let destinationRect: CGRect
            switch layout {
            case .viewportOrigin:
                destinationRect = CGRect(
                    x: geometry.originX - visibleRect.minX,
                    y: geometry.originY - visibleRect.minY,
                    width: geometry.width, height: geometry.height)
            case .documentCoordinates:
                destinationRect = CGRect(
                    x: Double(geometry.originX) / grid.deviceScale,
                    y: Double(geometry.originY) / grid.deviceScale,
                    width: Double(geometry.width) / grid.deviceScale,
                    height: Double(geometry.height) / grid.deviceScale)
            }
            destination.draw(image, in: destinationRect)
        }
        return TileCompositeFrame(
            grid: grid, visibleCoordinates: visible, renderedTiles: rendered,
            hitTiles: hits)
    }

    private func consume(_ change: EditorCommands.DocumentChange) {
        stateLock.withLock {
            spatialIndexNeedsRebuild = true
            invalidate(change.damage, reason: .documentChange(change.kind))
        }
    }

    private func ensureSpatialIndex(for document: EditorDocument, grid: TileGrid) {
        guard spatialIndexNeedsRebuild || spatialIndexGrid != grid else { return }
        let rootNodeCount = document.layers.reduce(0) { $0 + $1.nodes.count }
        guard rootNodeCount > 0 else {
            spatialIndexEnabled = false
            rootNodeIndicesByTile.removeAll(keepingCapacity: false)
            spatialIndexGrid = grid
            spatialIndexNeedsRebuild = false
            return
        }
        var index: [TileCoordinate: [[Int]]] = [:]
        let allCoordinates = Set(grid.coordinates(intersecting: grid.fullDeviceRect))
        for (layerIndex, layer) in document.layers.enumerated() where layer.isVisible {
            for (nodeIndex, node) in layer.nodes.enumerated() {
                let coordinates: Set<TileCoordinate>
                if let bounds = node.conservativeInkBounds,
                    let mapped = TileDamageMapper.coordinates(forInkBounds: bounds, in: grid)
                {
                    coordinates = mapped
                } else {
                    coordinates = allCoordinates
                }
                for coordinate in coordinates {
                    if index[coordinate] == nil {
                        index[coordinate] = Array(repeating: [], count: document.layers.count)
                    }
                    index[coordinate]![layerIndex].append(nodeIndex)
                }
            }
        }
        rootNodeIndicesByTile = index
        spatialIndexEnabled = true
        spatialIndexGrid = grid
        spatialIndexNeedsRebuild = false
    }

    /// The sole damage-to-cache mutation point. `nil` is untrustworthy damage
    /// and therefore has the same lazy full invalidation semantics as `.full`.
    private func invalidate(_ damage: DocumentDamage?, reason: TileInvalidationReason) {
        guard let damage else {
            recordGenerationBump(reason: reason, damage: nil)
            return
        }
        switch damage {
        case .none:
            appendInvalidation(
                reason: reason, damage: damage, coordinates: [],
                generationBefore: cache.generation, generationAfter: cache.generation)
        case .full:
            recordGenerationBump(reason: reason, damage: damage)
        case .rects:
            guard let activeGrid else {
                appendInvalidation(
                    reason: reason, damage: damage, coordinates: [],
                    generationBefore: cache.generation, generationAfter: cache.generation)
                return
            }
            let mapping = TileDamageMapper.map(damage, in: activeGrid)
            if mapping == .all {
                recordGenerationBump(reason: reason, damage: damage)
            } else {
                let coordinates = mapping.resolvedCoordinates(in: activeGrid)
                let generation = cache.generation
                _ = cache.invalidate(coordinates)
                appendInvalidation(
                    reason: reason, damage: damage, coordinates: coordinates,
                    generationBefore: generation, generationAfter: generation)
            }
        }
    }

    private func recordGenerationBump(
        reason: TileInvalidationReason, damage: DocumentDamage?
    ) {
        let before = cache.generation
        cache.bumpGeneration()
        appendInvalidation(
            reason: reason, damage: damage, coordinates: [],
            generationBefore: before, generationAfter: cache.generation)
    }

    private func appendInvalidation(
        reason: TileInvalidationReason, damage: DocumentDamage?,
        coordinates: Set<TileCoordinate>, generationBefore: UInt64, generationAfter: UInt64
    ) {
        nextInvalidationSequence &+= 1
        invalidationLog.append(
            TileInvalidationRecord(
                sequence: nextInvalidationSequence, reason: reason, damage: damage,
                invalidatedCoordinates: coordinates, generationBefore: generationBefore,
                generationAfter: generationAfter))
    }

    private func renderTile(
        _ document: EditorDocument, geometry: TileGeometry, deviceScale: Double,
        approvedImages: [ObjectID: CGImage], rootNodeIndicesByLayer: [[Int]]?
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
        renderer.render(
            document, in: bitmap, viewport: RenderViewport(),
            approvedImages: approvedImages,
            rootNodeIndicesByLayer: rootNodeIndicesByLayer)
        guard let image = bitmap.makeImage() else {
            throw TileCompositeError.bitmapAllocationFailed
        }
        return image
    }
}
