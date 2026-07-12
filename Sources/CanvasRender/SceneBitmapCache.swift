import CoreGraphics
import DocumentModel
import Foundation
import Geometry

/// Threading contract: cache state is synchronized internally. Bitmap construction
/// happens without the state lock, and the caller-owned destination context is only
/// touched by the calling thread after all cache locks have been released.
public final class SceneBitmapCache {
    private struct Key: Equatable {
        var revision: UInt64
        var zoomBucket: Int
        var backingScale: Double
        var width: Double
        var height: Double
    }
    private let lock = NSLock()
    private var key: Key?
    private var image: CGImage?
    public init() {}
    public func invalidate() {
        lock.withLock {
            key = nil
            image = nil
        }
    }
    public func render(
        _ document: EditorDocument, revision: UInt64, in destination: CGContext, viewport: RenderViewport,
        backingScale: Double = 1
    ) {
        let zoomBucket = max(1, Int((max(viewport.zoom, 0.01) * 8).rounded(.up)))
        let requestedScale = max(1, backingScale) * Double(zoomBucket) / 8
        let area = max(1, document.width * document.height)
        let budgetScale = sqrt(Double(DocumentLimits.maximumSceneCachePixels) / area)
        let renderScale = min(requestedScale, budgetScale)
        let nextKey = Key(
            revision: revision, zoomBucket: zoomBucket, backingScale: backingScale, width: document.width,
            height: document.height)
        var cached = lock.withLock { key == nextKey ? image : nil }
        if cached == nil {
            let width = max(1, Int((document.width * renderScale).rounded(.up)))
            let height = max(1, Int((document.height * renderScale).rounded(.up)))
            let pixels = Int64(width).multipliedReportingOverflow(by: Int64(height))
            if !pixels.overflow, pixels.partialValue <= DocumentLimits.maximumSceneCachePixels,
                let bitmap = CGContext(
                    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            {
                bitmap.scaleBy(x: renderScale, y: renderScale)
                CoreGraphicsRenderer().render(document, in: bitmap)
                cached = bitmap.makeImage()
                lock.withLock {
                    key = nextKey
                    image = cached
                }
            }
        }
        guard let cached else { return }
        destination.saveGState()
        defer { destination.restoreGState() }
        if let clip = viewport.clip {
            destination.clip(to: CGRect(x: clip.minX, y: clip.minY, width: clip.width, height: clip.height))
        }
        destination.translateBy(x: viewport.pan.x, y: viewport.pan.y)
        destination.scaleBy(x: viewport.zoom, y: viewport.zoom)
        destination.draw(cached, in: CGRect(x: 0, y: 0, width: document.width, height: document.height))
    }
}
