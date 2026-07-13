import CanvasRender
import CoreGraphics
import DocumentFormats
import DocumentModel
import EditorCore
import Foundation
import Geometry
import ImageIO
import UniformTypeIdentifiers

private func identifier(_ value: Int) -> ObjectID {
    let suffix = String(format: "%012X", value)
    return ObjectID(rawValue: UUID(uuidString: "10000000-0000-0000-0000-\(suffix)")!)
}

private func embeddedImageData() throws -> Data {
    let context = try require(
        CGContext(
            data: nil, width: 2_500, height: 2_000, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(srgbRed: 0.25, green: 0.5, blue: 0.75, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 2_500, height: 2_000))
    let image = try require(context.makeImage())
    let data = NSMutableData()
    let destination = try require(
        CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw EditorError.invalidValue("Representative image encoding failed")
    }
    return data as Data
}

private func representativeDocument() throws -> EditorDocument {
    var nodes: [SceneNode] = []
    var anchorCount = 0
    for objectIndex in 0..<990 {
        let segmentCount = objectIndex < 100 ? 11 : 10
        let originX = Double((objectIndex % 45) * 40)
        let originY = Double((objectIndex / 45) * 40)
        var segments: [CubicBezier] = []
        for segmentIndex in 0..<segmentCount {
            let x = originX + Double(segmentIndex * 2)
            segments.append(
                CubicBezier(
                    start: Point(x: x, y: originY),
                    control1: Point(x: x + 0.5, y: originY + 1),
                    control2: Point(x: x + 1.5, y: originY + 1),
                    end: Point(x: x + 2, y: originY)))
        }
        anchorCount += segments.count
        nodes.append(
            .path(
                PathObject(
                    id: identifier(objectIndex), segments: segments,
                    style: PathStyle(fill: nil, stroke: .black, strokeWidth: 1))))
    }
    let imageData = try embeddedImageData()
    let loader = RasterResourceLoader()
    for imageIndex in 0..<10 {
        let x = Double(imageIndex * 120)
        var image = try loader.embedded(
            data: imageData, frame: Rect(minX: x, minY: 900, maxX: x + 100, maxY: 980))
        image.id = identifier(990 + imageIndex)
        nodes.append(.image(image))
    }
    precondition(nodes.count == 1_000)
    precondition(anchorCount == 10_000)
    return try EditorDocument(width: 1_920, height: 1_080, layers: [Layer(name: "Representative", nodes: nodes)])
}

private func bitmapContext() -> CGContext {
    CGContext(
        data: nil, width: 1_920, height: 1_080, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

private struct SettledScenario: @unchecked Sendable {
    var context: CGContext
    var approvedImages: [ObjectID: CGImage]
}

private func settle(_ document: EditorDocument) async throws -> SettledScenario {
    try document.validate()
    let cache = ApprovedImageCache()
    try await cache.approve(document)
    let approvedImages = await cache.snapshot()
    precondition(approvedImages.count == 10, "All representative images must decode")
    let approvedPixelCount = await cache.approvedPixelCount()
    precondition(approvedPixelCount == 50_000_000, "Decoded pixel count must be representative")
    let context = bitmapContext()
    CoreGraphicsRenderer().render(document, in: context, approvedImages: approvedImages)
    return SettledScenario(context: context, approvedImages: approvedImages)
}

private func exportPNG(_ context: CGContext) throws {
    let image = try require(context.makeImage())
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("opendraw-r4-memory.png")
    defer { try? FileManager.default.removeItem(at: url) }
    let destination = try require(
        CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw EditorError.invalidValue("PNG export failed") }
    _ = try Data(contentsOf: url, options: .mappedIfSafe)
}

private func require<T>(_ value: T?) throws -> T {
    guard let value else { throw EditorError.invalidValue("R4 gate allocation failed") }
    return value
}

let mode = CommandLine.arguments.dropFirst().first ?? "settle"
let document = try representativeDocument()
let extraByteCount = Int(ProcessInfo.processInfo.environment["R4_MEMORY_EXTRA_BYTES"] ?? "0") ?? 0
let extraAllocation = [UInt8](repeating: 0xA5, count: extraByteCount)
private let scenario = try await settle(document)
withExtendedLifetime((scenario.approvedImages, extraAllocation)) {
    switch mode {
    case "settle":
        print(
            "R4_MEMORY_SCENARIO=settle objects=1000 anchors=10000 decodedImages=10 decodedPixels=50000000 extraBytes=\(extraByteCount)"
        )
    case "export":
        do {
            try exportPNG(scenario.context)
            print(
                "R4_MEMORY_SCENARIO=export objects=1000 anchors=10000 decodedImages=10 decodedPixels=50000000 extraBytes=\(extraByteCount)"
            )
        } catch {
            fputs("R4 PNG export failed: \(error)\n", stderr)
            exit(EXIT_FAILURE)
        }
    default:
        fputs("usage: R4GateHarness [settle|export]\n", stderr)
        exit(EXIT_FAILURE)
    }
}
