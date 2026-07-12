// swift-format-ignore-file

import CanvasRender
import CoreGraphics
import DocumentModel
import EditorCore
import Foundation
import Geometry
import ImageIO
import Testing
import UniformTypeIdentifiers

// swift-format-ignore: LineLength
private let compositeGoldenBase64 = "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"

private func goldenDocument() throws -> EditorDocument {
    let gradient = GradientResource(
        name: "G", kind: .linear, start: Point(x: 8, y: 8), end: Point(x: 80, y: 70),
        stops: [
            ColorStop(offset: 0, color: SRGBColor(red: 1, green: 0, blue: 0)),
            ColorStop(offset: 1, color: SRGBColor(red: 0, green: 0, blue: 1)),
        ])
    let rect = ShapeFactoryForGolden.rectangle
    var gradientPath = rect
    gradientPath.style = PathStyle(fillGradientID: gradient.id, opacity: 0.75)
    gradientPath.transform = AffineTransform(a: 0.94, b: 0.34, c: -0.34, d: 0.94, tx: 18, ty: -8)
    var dashed = rect
    dashed.id = ObjectID()
    dashed.style = PathStyle(
        fill: nil, stroke: SRGBColor(red: 0, green: 0.5, blue: 0), strokeWidth: 5,
        lineCap: .round, lineJoin: .bevel, miterLimit: 4, dash: [7, 3])
    dashed.transform = AffineTransform(a: 0.55, d: 0.55, tx: 35, ty: 38)
    let text = TextObject(
        text: "Ag", origin: Point(x: 12, y: 88), fontName: "Helvetica", fontSize: 18,
        color: SRGBColor(red: 0.1, green: 0.1, blue: 0.1), transform: AffineTransform(a: 1, b: 0, c: 0.12, d: 1))
    return try EditorDocument(
        width: 96, height: 96,
        layers: [Layer(name: "Golden", nodes: [.path(gradientPath), .text(text), .path(dashed)])], gradients: [gradient]
    )
}

private enum ShapeFactoryForGolden {
    static let rectangle: PathObject = {
        let p = [Point(x: 8, y: 8), Point(x: 72, y: 8), Point(x: 72, y: 58), Point(x: 8, y: 58), Point(x: 8, y: 8)]
        return PathObject(
            segments: zip(p, p.dropFirst()).map { CubicBezier(start: $0, control1: $0, control2: $1, end: $1) },
            isClosed: true)
    }()
}

private func renderGolden() throws -> CGImage {
    let context = try #require(
        CGContext(
            data: nil, width: 96, height: 96, bitsPerComponent: 8, bytesPerRow: 96 * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 96, height: 96))
    CoreGraphicsRenderer().render(try goldenDocument(), in: context)
    return try #require(context.makeImage())
}

private func png(_ image: CGImage) -> Data {
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
}

@Test func compositeSceneMatchesProjectGoldenWithExplicitTolerance() throws {
    let actual = try renderGolden()
    if ProcessInfo.processInfo.environment["UPDATE_GOLDENS"] == "1" {
        print("GOLDEN_BASE64=\(png(actual).base64EncodedString())")
        return
    }
    let encoded = try #require(Data(base64Encoded: compositeGoldenBase64))
    let source = try #require(CGImageSourceCreateWithData(encoded as CFData, nil))
    let expected = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    let a = try #require(actual.dataProvider?.data) as Data
    let e = try #require(expected.dataProvider?.data) as Data
    #expect(a.count == e.count)
    var differingPixels = 0
    var maxChannelDelta = 0
    for pixel in 0..<(min(a.count, e.count) / 4) {
        var differs = false
        for channel in 0..<4 {
            let delta = abs(Int(a[pixel * 4 + channel]) - Int(e[pixel * 4 + channel]))
            maxChannelDelta = max(maxChannelDelta, delta)
            differs = differs || delta > 3
        }
        if differs { differingPixels += 1 }
    }
    #expect(maxChannelDelta <= 12)
    #expect(differingPixels <= 96 * 96 / 100)
}
