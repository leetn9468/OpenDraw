import CanvasRender
import CoreGraphics
import Darwin
import DocumentFormats
import DocumentModel
import EditorCommands
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

private struct Phase5HistoryEnvelope: Sendable {
    var floorHistory: DeltaCommandHistory
    var checkpointHistory: DeltaCommandHistory
}

private func noOpCommand(
    sequence: Int, costInBytes: Int, pinnedAssets: [HistoryAssetPin] = []
) throws -> DocumentCommand {
    let oldPayload = Data([UInt8(truncatingIfNeeded: sequence)])
    let newPayload = Data([UInt8(truncatingIfNeeded: sequence &+ 1)])
    return try DocumentCommand(
        commandID: identifier(10_000 + sequence).rawValue, timestamp: Date(timeIntervalSince1970: Double(sequence)),
        name: "Phase 5 memory fixture", damageBounds: .none, costInBytes: costInBytes,
        pinnedAssets: pinnedAssets, oldPayload: oldPayload, newPayload: newPayload,
        apply: { _ in }, unapply: { _ in })
}

private func phase5HistoryEnvelope(document: EditorDocument) throws -> Phase5HistoryEnvelope {
    var checkpointHistory = try DeltaCommandHistory(document: document, featureFlag: .environment())
    for sequence in 1...200 {
        try checkpointHistory.commit(noOpCommand(sequence: sequence, costInBytes: 1))
    }
    precondition(checkpointHistory.undoDepth == 200)
    precondition(checkpointHistory.checkpointCount == 9)

    let assetStore = ApprovedAssetStore()
    var floorHistory = try DeltaCommandHistory(
        document: document, featureFlag: .environment(), assetStore: assetStore)
    for sequence in 1...9 {
        try floorHistory.commit(noOpCommand(sequence: 1_000 + sequence, costInBytes: 1_000))
    }
    let pinnedBytes = Data(repeating: 0xA5, count: 70_000_000)
    let descriptor = assetStore.registerApproved(pinnedBytes)
    let pin = try HistoryAssetPin(approvedAsset: descriptor)
    try floorHistory.commit(
        noOpCommand(sequence: 2_000, costInBytes: 0, pinnedAssets: [pin]))
    precondition(floorHistory.undoDepth == 10)
    precondition(floorHistory.evictionCount == 0)
    precondition(floorHistory.totalCostInBytes == 70_009_000)
    precondition(assetStore.historyPinCount(assetID: descriptor.assetID) == 1)
    return Phase5HistoryEnvelope(floorHistory: floorHistory, checkpointHistory: checkpointHistory)
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

private func residentExtraAllocation(byteCount: Int) -> [UInt8] {
    guard byteCount > 0 else { return [] }
    var allocation = [UInt8](repeating: 0, count: byteCount)
    allocation.withUnsafeMutableBytes { buffer in
        arc4random_buf(buffer.baseAddress!, buffer.count)
    }
    return allocation
}

let mode = CommandLine.arguments.dropFirst().first ?? "settle"
let document = try representativeDocument()
let extraByteCount = Int(ProcessInfo.processInfo.environment["R4_MEMORY_EXTRA_BYTES"] ?? "0") ?? 0
let extraAllocation = residentExtraAllocation(byteCount: extraByteCount)
private let phase5History = try phase5HistoryEnvelope(document: document)
private let scenario = try await settle(document)
withExtendedLifetime((scenario.approvedImages, extraAllocation, phase5History)) {
    switch mode {
    case "settle":
        print(
            "R4_MEMORY_SCENARIO=settle objects=1000 anchors=10000 decodedImages=10 decodedPixels=50000000 deltaFloorCommands=10 deltaFloorBytes=70009000 deltaCheckpoints=9 extraBytes=\(extraByteCount)"
        )
    case "export":
        do {
            try exportPNG(scenario.context)
            print(
                "R4_MEMORY_SCENARIO=export objects=1000 anchors=10000 decodedImages=10 decodedPixels=50000000 deltaFloorCommands=10 deltaFloorBytes=70009000 deltaCheckpoints=9 extraBytes=\(extraByteCount)"
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
