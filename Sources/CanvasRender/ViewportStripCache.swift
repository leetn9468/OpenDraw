import CoreGraphics
import DocumentModel
import Foundation
import Geometry

/// Retains a viewport-sized bitmap and redraws only strips exposed by integer pans.
public final class ViewportStripCache {
    private struct State {
        var image: CGImage
        var revision: UInt64
        var zoom: Double
        var pan: Point
    }
    private let lock = NSLock()
    private var state: State?
    private var stripRedraws = 0
    public init() {}
    public var redrawnStripCount: Int { lock.withLock { stripRedraws } }
    public func purge() {
        lock.withLock {
            state = nil
            stripRedraws = 0
        }
    }
    public func render(
        _ document: EditorDocument, revision: UInt64, in destination: CGContext,
        viewport: RenderViewport, pixelWidth: Int, pixelHeight: Int
    ) {
        guard pixelWidth > 0, pixelHeight > 0 else { return }
        let previous = lock.withLock { state }
        let bitmap = CGContext(
            data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        var strips: [CGRect] = []
        if let previous, previous.revision == revision, previous.zoom == viewport.zoom {
            let dx = Int((viewport.pan.x - previous.pan.x).rounded())
            let dy = Int((viewport.pan.y - previous.pan.y).rounded())
            bitmap.draw(previous.image, in: CGRect(x: dx, y: dy, width: pixelWidth, height: pixelHeight))
            if dx > 0 { strips.append(CGRect(x: 0, y: 0, width: min(dx, pixelWidth), height: pixelHeight)) }
            if dx < 0 {
                strips.append(
                    CGRect(x: max(0, pixelWidth + dx), y: 0, width: min(-dx, pixelWidth), height: pixelHeight))
            }
            if dy > 0 { strips.append(CGRect(x: 0, y: 0, width: pixelWidth, height: min(dy, pixelHeight))) }
            if dy < 0 {
                strips.append(
                    CGRect(x: 0, y: max(0, pixelHeight + dy), width: pixelWidth, height: min(-dy, pixelHeight)))
            }
        } else {
            strips = [CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)]
        }
        for strip in strips {
            bitmap.saveGState()
            bitmap.clip(to: strip)
            bitmap.translateBy(x: viewport.pan.x, y: viewport.pan.y)
            bitmap.scaleBy(x: viewport.zoom, y: viewport.zoom)
            CoreGraphicsRenderer().render(document, in: bitmap)
            bitmap.restoreGState()
        }
        guard let image = bitmap.makeImage() else { return }
        lock.withLock {
            state = State(image: image, revision: revision, zoom: viewport.zoom, pan: viewport.pan)
            stripRedraws += strips.count
        }
        destination.draw(image, in: CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
    }
}
