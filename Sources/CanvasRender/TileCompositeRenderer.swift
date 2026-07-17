import CoreGraphics
import DocumentModel
import EditorCommands
import EditorCore
import Foundation
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

/// Flag-isolated entry point. No production caller is wired to this renderer yet.
/// Tiles are rendered by the existing full-scene renderer under an integer
/// device-pixel clip and translation; object-by-object cropping is not used.
public final class TileCompositeRenderer: @unchecked Sendable {
    public let cache: TileCache<CGImage>
    public let configuration: TileCacheStartupConfiguration
    private let stateLock = NSLock()
    private var activeGrid: TileGrid?
    private var observation: DocumentChangeObservation?
    private var nextInvalidationSequence: UInt64 = 0
    private var invalidationLog: [TileInvalidationRecord] = []
    private let renderer = CoreGraphicsRenderer()

    public init(
        configuration: TileCacheStartupConfiguration = .process,
        byteBudget: Int = TileCache<CGImage>.defaultByteBudget
    ) {
        self.configuration = configuration
        cache = TileCache(byteBudget: byteBudget)
    }

    deinit { observation?.cancel() }

    /// Installs the single typed-change choke point used by commands,
    /// undo/redo, and live gesture publication. Production does not call this
    /// while the tile path remains isolated behind its startup flag.
    public func subscribe(to history: DeltaCommandHistory) {
        let replacement = history.observeChanges { [weak self] change in
            self?.consume(change)
        }
        let previous = stateLock.withLock {
            let previous = observation
            observation = replacement
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
            guard configuration.isEnabled else { throw TileCompositeError.featureDisabled }
            let grid = try TileGrid(
                documentWidth: document.width, documentHeight: document.height,
                zoom: zoom, backingScale: backingScale)
            if let activeGrid,
                activeGrid.zoom != grid.zoom || activeGrid.backingScale != grid.backingScale
            {
                recordGenerationBump(reason: .deviceScaleChange, damage: nil)
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
    }

    private func consume(_ change: EditorCommands.DocumentChange) {
        stateLock.withLock {
            invalidate(change.damage, reason: .documentChange(change.kind))
        }
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
