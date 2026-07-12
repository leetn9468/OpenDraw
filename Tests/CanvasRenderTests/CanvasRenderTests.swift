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
        CoreGraphicsRenderer().render(.sample(), in: context, scale: scale)
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
    var document = EditorDocument.sample()
    let path = try #require(document.layers[0].paths.first)
    document.layers[0].paths = Array(repeating: path, count: 1_000)
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
    var document = EditorDocument.sample()
    let path = try #require(document.layers[0].paths.first)
    document.layers[0].paths = Array(repeating: path, count: 1_000)
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
    var document = EditorDocument.sample()
    document.gradients = [gradient]
    document.layers[0].paths[0].style.fillGradientID = gradient.id
    document.layers[0].paths[0].style.opacity = 0.5
    document.layers[0].textObjects = [TextObject(text: "مرحبا 👋", origin: Geometry.Point(x: 20, y: 40))]
    document.layers[0].imageObjects = [
        ImageObject(
            frame: Geometry.Rect(minX: 10, minY: 10, maxX: 30, maxY: 30), storage: .embedded(Data([0, 1, 2])),
            pixelWidth: 1, pixelHeight: 1)
    ]
    let context = try #require(
        CGContext(
            data: nil, width: 640, height: 480, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    CoreGraphicsRenderer().render(document, in: context)
    #expect(context.makeImage() != nil)
}
