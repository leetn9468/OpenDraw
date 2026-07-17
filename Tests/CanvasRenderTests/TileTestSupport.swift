import CanvasRender
import CoreGraphics
import DocumentModel
import EditorCore
import Foundation
import Geometry
import Testing

enum TileTestError: Error, Equatable {
    case pixelCountOverflow
}

struct RenderDifference {
    let differingPixels: Int
    let maximumChannelDelta: Int
    let allowedDifferingPixels: Int

    var passesFrozenInstrument: Bool {
        maximumChannelDelta <= 12 && differingPixels <= allowedDifferingPixels
    }
}

final class TileTestBitmap {
    let context: CGContext
    private let storage: UnsafeMutablePointer<UInt8>

    init(width: Int, height: Int) throws {
        storage = .allocate(capacity: width * height * 4)
        storage.initialize(repeating: 0, count: width * height * 4)
        guard
            let context = CGContext(
                data: storage, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            storage.deallocate()
            throw TileCompositeError.bitmapAllocationFailed
        }
        self.context = context
    }

    deinit { storage.deallocate() }
}

func frozenDifferingPixelLimit(width: Int, height: Int) throws -> Int {
    guard width >= 0, height >= 0 else { throw TileTestError.pixelCountOverflow }
    let pixels = width.multipliedReportingOverflow(by: height)
    guard !pixels.overflow else { throw TileTestError.pixelCountOverflow }
    return pixels.partialValue / 100
}

func compare(_ lhs: CGImage, _ rhs: CGImage) throws -> RenderDifference {
    guard lhs.width == rhs.width, lhs.height == rhs.height else {
        throw TileTestError.pixelCountOverflow
    }
    let left = try #require(lhs.dataProvider?.data) as Data
    let right = try #require(rhs.dataProvider?.data) as Data
    let pixels = lhs.width.multipliedReportingOverflow(by: lhs.height)
    guard !pixels.overflow else { throw TileTestError.pixelCountOverflow }
    let byteCount = pixels.partialValue.multipliedReportingOverflow(by: 4)
    guard !byteCount.overflow, left.count >= byteCount.partialValue, right.count >= byteCount.partialValue else {
        throw TileTestError.pixelCountOverflow
    }
    var differingPixels = 0
    var maximumChannelDelta = 0
    for pixel in 0..<pixels.partialValue {
        var exceedsIgnoredDelta = false
        for channel in 0..<4 {
            let offset = pixel * 4 + channel
            let delta = abs(Int(left[offset]) - Int(right[offset]))
            maximumChannelDelta = max(maximumChannelDelta, delta)
            exceedsIgnoredDelta = exceedsIgnoredDelta || delta > 3
        }
        if exceedsIgnoredDelta { differingPixels += 1 }
    }
    let result = RenderDifference(
        differingPixels: differingPixels, maximumChannelDelta: maximumChannelDelta,
        allowedDifferingPixels: try frozenDifferingPixelLimit(width: lhs.width, height: lhs.height))
    print(
        "VERIFY_032_DIFFERENCE width=\(lhs.width) height=\(lhs.height) "
            + "differing_pixels=\(result.differingPixels) max_channel_delta=\(result.maximumChannelDelta) "
            + "allowed_pixels=\(result.allowedDifferingPixels)")
    return result
}

func directImage(
    _ document: EditorDocument, width: Int, height: Int,
    deviceScale: Double = 1, approvedImages: [ObjectID: CGImage] = [:]
) throws -> CGImage {
    let bitmap = try TileTestBitmap(width: width, height: height)
    bitmap.context.scaleBy(x: deviceScale, y: deviceScale)
    CoreGraphicsRenderer().render(document, in: bitmap.context, approvedImages: approvedImages)
    return try #require(bitmap.context.makeImage())
}

func compositeImage(
    _ document: EditorDocument, renderer: TileCompositeRenderer,
    width: Int, height: Int, zoom: Double = 1, backingScale: Double = 1,
    approvedImages: [ObjectID: CGImage] = [:]
) throws -> (CGImage, TileCompositeFrame) {
    let bitmap = try TileTestBitmap(width: width, height: height)
    let frame = try renderer.composite(
        document, in: bitmap.context, zoom: zoom, backingScale: backingScale,
        approvedImages: approvedImages)
    return (try #require(bitmap.context.makeImage()), frame)
}

func rectanglePath(
    minX: Double, minY: Double, maxX: Double, maxY: Double,
    style: PathStyle = PathStyle(fill: .black, stroke: nil)
) -> PathObject {
    let points = [
        Point(x: minX, y: minY), Point(x: maxX, y: minY),
        Point(x: maxX, y: maxY), Point(x: minX, y: maxY), Point(x: minX, y: minY),
    ]
    return PathObject(
        segments: zip(points, points.dropFirst()).map {
            CubicBezier(start: $0, control1: $0, control2: $1, end: $1)
        }, isClosed: true, style: style)
}

func mixedTileDocument() throws -> EditorDocument {
    let path = rectanglePath(
        minX: 210, minY: 180, maxX: 340, maxY: 290,
        style: PathStyle(
            fill: SRGBColor(red: 0.2, green: 0.6, blue: 0.9),
            stroke: .black, strokeWidth: 3, lineJoin: .round))
    let text = TextObject(
        text: "Tile cache 👩🏽‍💻", origin: Point(x: 36, y: 90),
        fontName: "Helvetica", fontSize: 28,
        transform: Geometry.AffineTransform(a: 1, b: 0.08, c: 0.05, d: 1))
    let image = ImageObject(
        frame: Geometry.Rect(minX: 610, minY: 350, maxX: 760, maxY: 470),
        storage: .linked(relativePath: "tile-fixture.png"), pixelWidth: 1, pixelHeight: 1)
    return try EditorDocument(
        width: 800, height: 500,
        layers: [Layer(name: "Mixed", nodes: [.path(path), .text(text), .image(image)])])
}

func cornerStraddleDocument() throws -> EditorDocument {
    let radius = 40.0
    let center = Point(x: 256, y: 256)
    let control = radius * 0.552_284_749_830_793_6
    let segments = [
        CubicBezier(
            start: Point(x: center.x + radius, y: center.y),
            control1: Point(x: center.x + radius, y: center.y + control),
            control2: Point(x: center.x + control, y: center.y + radius),
            end: Point(x: center.x, y: center.y + radius)),
        CubicBezier(
            start: Point(x: center.x, y: center.y + radius),
            control1: Point(x: center.x - control, y: center.y + radius),
            control2: Point(x: center.x - radius, y: center.y + control),
            end: Point(x: center.x - radius, y: center.y)),
        CubicBezier(
            start: Point(x: center.x - radius, y: center.y),
            control1: Point(x: center.x - radius, y: center.y - control),
            control2: Point(x: center.x - control, y: center.y - radius),
            end: Point(x: center.x, y: center.y - radius)),
        CubicBezier(
            start: Point(x: center.x, y: center.y - radius),
            control1: Point(x: center.x + control, y: center.y - radius),
            control2: Point(x: center.x + radius, y: center.y - control),
            end: Point(x: center.x + radius, y: center.y)),
    ]
    let circle = PathObject(
        segments: segments, isClosed: true, style: PathStyle(fill: .black, stroke: nil))
    return try EditorDocument(
        width: 512, height: 512,
        layers: [Layer(name: "Corner straddle", nodes: [.path(circle)])])
}
