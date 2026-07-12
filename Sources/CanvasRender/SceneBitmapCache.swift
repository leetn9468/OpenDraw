import CoreGraphics
import DocumentModel
import Foundation

public final class SceneBitmapCache: @unchecked Sendable {
    private let lock = NSLock()
    private var key: Int?
    private var image: CGImage?
    public init() {}
    public func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        key = nil
        image = nil
    }
    public func render(_ document: EditorDocument, in destination: CGContext, viewport: RenderViewport) {
        lock.lock()
        defer { lock.unlock() }
        let nextKey = document.hashValue
        if key != nextKey || image == nil {
            let width = max(1, Int(document.width.rounded(.up)))
            let height = max(1, Int(document.height.rounded(.up)))
            if let bitmap = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            {
                CoreGraphicsRenderer().render(document, in: bitmap)
                image = bitmap.makeImage()
                key = nextKey
            }
        }
        guard let image else { return }
        destination.saveGState()
        defer { destination.restoreGState() }
        if let clip = viewport.clip {
            destination.clip(to: CGRect(x: clip.minX, y: clip.minY, width: clip.width, height: clip.height))
        }
        destination.translateBy(x: viewport.pan.x, y: viewport.pan.y)
        destination.scaleBy(x: viewport.zoom, y: viewport.zoom)
        destination.draw(image, in: CGRect(x: 0, y: 0, width: document.width, height: document.height))
    }
}
