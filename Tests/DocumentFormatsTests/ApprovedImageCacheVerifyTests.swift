import DocumentFormats
import DocumentModel
import Foundation
import Geometry
import Testing

private let approvedPNG = Data(
    base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!

@Test func verify012ApprovedImageBudgetExamples() throws {
    let maximum: Int64 = 67_108_864
    var total: Int64 = 0
    for _ in 0..<4 { total = try ApprovedImageCache.checkedTotalPixels(current: total, adding: maximum) }
    #expect(total == 268_435_456)
    #expect(throws: ImageApprovalError.totalPixelBudget) {
        try ApprovedImageCache.checkedTotalPixels(current: total, adding: 1)
    }
    #expect(throws: ImageApprovalError.overflow) {
        try ApprovedImageCache.checkedTotalPixels(current: Int64.max, adding: 1)
    }
    #expect(EmbeddedImageValidator.maximumFrames == 32)
    #expect(try EmbeddedImageValidator.checkFrameCount(32) == ())
    #expect(throws: ImageApprovalError.frameCount) { try EmbeddedImageValidator.checkFrameCount(33) }
    #expect(throws: ImageApprovalError.unsupported) {
        try EmbeddedImageValidator().validate(data: Data([0, 1, 2]))
    }
}

@Test func approvedImageCacheDecodesOffActorAndPublishesSnapshot() async throws {
    let image = ImageObject(
        frame: Rect(minX: 0, minY: 0, maxX: 10, maxY: 10), storage: .embedded(approvedPNG), pixelWidth: 1,
        pixelHeight: 1)
    let document = try EditorDocument(width: 10, height: 10, layers: [Layer(name: "L", nodes: [.image(image)])])
    let cache = ApprovedImageCache()
    try await cache.approve(document)
    #expect(await cache.approvedPixelCount() == 1)
    #expect(await cache.snapshot()[image.id] != nil)
}

@Test func linkedResourceResolverRejectsTraversalAndSymlinkEscape() throws {
    let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let root = base.appendingPathComponent("root")
    let outside = base.appendingPathComponent("outside")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data([1]).write(to: outside)
    defer { try? FileManager.default.removeItem(at: base) }
    let resolver = LinkedResourceResolver(root: root)
    #expect(throws: ImageApprovalError.pathEscape) { try resolver.resolve("../../outside") }
    let link = root.appendingPathComponent("escape")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
    #expect(throws: ImageApprovalError.pathEscape) { try resolver.resolve("escape") }
    let safe = root.appendingPathComponent("safe.png")
    try approvedPNG.write(to: safe)
    #expect(try resolver.resolve("safe.png") == safe.standardizedFileURL.resolvingSymlinksInPath())
}
