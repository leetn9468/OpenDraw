import CanvasRender
import CoreGraphics
import DocumentModel
import Foundation
import Geometry
import Testing

@Test func bezierRendersAtMultipleScales() throws {
    for scale in [0.25, 1.0, 2.0, 8.0] {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try #require(
            CGContext(
                data: nil, width: 800, height: 800, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        CoreGraphicsRenderer().render(try .sample(), in: context, scale: scale)
        let image = try #require(context.makeImage())
        #expect(image.width == 800)
    }
}

@Test func coreGraphicsSupportsRequiredCompositingPrimitives() throws {
    let context = try #require(
        CGContext(
            data: nil, width: 256, height: 256, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setShouldAntialias(true)
    context.clip(to: CGRect(x: 10, y: 10, width: 236, height: 236))
    context.setAlpha(0.6)
    let gradient = try #require(
        CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [CGColor(gray: 0, alpha: 1), CGColor(gray: 1, alpha: 1)] as CFArray, locations: [0, 1]))
    context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 256, y: 256), options: [])
    #expect(context.makeImage() != nil)
}

@Test func representativeDocumentRenderBenchmark() throws {
    var document = try EditorDocument.sample()
    guard case .path(let path) = try #require(document.layers[0].nodes.first) else {
        Issue.record("Missing path")
        return
    }
    document.layers[0].nodes = (0..<1_000).map { _ in .path(PathObject(path: path.path, style: path.style)) }
    let context = try #require(
        CGContext(
            data: nil, width: 640, height: 480, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let start = ContinuousClock.now
    CoreGraphicsRenderer().render(document, in: context)
    let elapsed = start.duration(to: .now)
    #expect(elapsed < .seconds(5))
}

@Test func cachedPanMeetsInteractiveFrameBudget() throws {
    var document = try EditorDocument.sample()
    guard case .path(let path) = try #require(document.layers[0].nodes.first) else {
        Issue.record("Missing path")
        return
    }
    document.layers[0].nodes = (0..<1_000).map { _ in .path(PathObject(path: path.path, style: path.style)) }
    let context = try #require(
        CGContext(
            data: nil, width: 640, height: 480, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    let cache = SceneBitmapCache()
    cache.render(document, in: context, viewport: RenderViewport())
    var worst = Duration.zero
    for index in 0..<20 {
        let start = ContinuousClock.now
        cache.render(document, in: context, viewport: RenderViewport(pan: Geometry.Point(x: Double(index), y: 0)))
        worst = max(worst, start.duration(to: .now))
    }
    #expect(worst < .milliseconds(16.7))
}

@Test func expandedAppearanceTextAndImageRender() throws {
    let gradient = GradientResource(
        name: "G", kind: .linear, start: Geometry.Point(x: 0, y: 0), end: Geometry.Point(x: 100, y: 100),
        stops: [ColorStop(offset: 0, color: .black), ColorStop(offset: 1, color: .white)])
    var document = try EditorDocument.sample()
    document.gradients = [gradient]
    let firstID = try #require(document.layers[0].nodes.first?.id)
    _ = document.mutatePath(id: firstID) {
        $0.style.fillGradientID = gradient.id
        $0.style.opacity = 0.5
    }
    document.layers[0].nodes += [
        .text(TextObject(text: "مرحبا 👋", origin: Geometry.Point(x: 20, y: 40))),
        .image(
            ImageObject(
                frame: Geometry.Rect(minX: 10, minY: 10, maxX: 30, maxY: 30), storage: .embedded(Data([0, 1, 2])),
                pixelWidth: 1, pixelHeight: 1)),
    ]
    let context = try #require(
        CGContext(
            data: nil, width: 640, height: 480, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    CoreGraphicsRenderer().render(document, in: context)
    #expect(context.makeImage() != nil)
}

@Test func transformedStrokeInkIsContainedByVisualBounds() throws {
    let width = 256
    let height = 256
    let bytesPerRow = width * 4
    for index in 0..<24 {
        let angle = Double(index) * 0.21
        let scale = 0.5 + Double(index % 6) * 0.25
        let shear = Double((index % 5) - 2) * 0.08
        let rotation = Geometry.AffineTransform(
            a: cos(angle) * scale, b: sin(angle) * scale, c: -sin(angle) + shear, d: cos(angle),
            tx: 100 + Double(index % 4) * 5, ty: 90 + Double(index % 3) * 7)
        let segment = CubicBezier(
            start: Point(x: -20, y: -10), control1: Point(x: -5, y: 25), control2: Point(x: 25, y: -20),
            end: Point(x: 35, y: 15))
        let path = PathObject(
            segments: [segment], style: PathStyle(stroke: .black, strokeWidth: 8, lineCap: .round, lineJoin: .round),
            transform: rotation)
        let node = SceneNode.path(path)
        let document = try EditorDocument(width: 256, height: 256, layers: [Layer(name: "Ink", nodes: [node])])
        let bounds = try #require(node.visualBounds)
        let bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: bytesPerRow * height)
        bytes.initialize(repeating: 0, count: bytesPerRow * height)
        defer { bytes.deallocate() }
        let context = try #require(
            CGContext(
                data: bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        CoreGraphicsRenderer().render(document, in: context)
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                if bytes[offset + 3] != 0 {
                    let documentY = Double(height - 1 - y)
                    #expect(Double(x) >= bounds.minX - 1 && Double(x) <= bounds.maxX + 1)
                    #expect(documentY >= bounds.minY - 1 && documentY <= bounds.maxY + 1)
                }
            }
        }
    }
}
