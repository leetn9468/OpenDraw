import CoreGraphics
import DocumentModel
import EditorCore
import Foundation
import ImageIO

public enum ImageApprovalError: Error, Equatable, Sendable {
    case unsupported, frameCount, pixelCount, totalPixelBudget, overflow, decodeFailed, pathEscape
}

public struct EmbeddedImageValidator: Sendable {
    public static let maximumFrames = 32
    public init() {}
    public static func checkFrameCount(_ count: Int) throws {
        guard count > 0, count <= maximumFrames else { throw ImageApprovalError.frameCount }
    }
    public func validate(data: Data) throws { _ = try decode(data) }
    public func validate(_ document: EditorDocument) throws {
        for request in embeddedRequests(document) { _ = try decode(request.data) }
    }
    func decode(_ data: Data) throws -> (CGImage, Int64) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetType(source) != nil else {
            throw ImageApprovalError.unsupported
        }
        let frames = CGImageSourceGetCount(source)
        try Self.checkFrameCount(frames)
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { throw ImageApprovalError.unsupported }
        let pixels: Int64
        do { pixels = try DocumentLimits.checkedPixelCount(width: Int64(width), height: Int64(height)) } catch {
            throw ImageApprovalError.pixelCount
        }
        guard
            let image = CGImageSourceCreateImageAtIndex(
                source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else { throw ImageApprovalError.decodeFailed }
        return (image, pixels)
    }
}

public actor ApprovedImageCache {
    public static let maximumTotalPixels: Int64 = 268_435_456
    private var images: [ObjectID: CGImage] = [:]
    private var totalPixels: Int64 = 0
    public init() {}
    public static func checkedTotalPixels(current: Int64, adding: Int64) throws -> Int64 {
        let result = current.addingReportingOverflow(adding)
        guard !result.overflow else { throw ImageApprovalError.overflow }
        guard result.partialValue <= maximumTotalPixels else { throw ImageApprovalError.totalPixelBudget }
        return result.partialValue
    }
    public func approve(_ document: EditorDocument) async throws {
        let requests = embeddedRequests(document)
        let decoded = try await Task.detached(priority: .userInitiated) { () throws -> [(ObjectID, CGImage, Int64)] in
            var result: [(ObjectID, CGImage, Int64)] = []
            let validator = EmbeddedImageValidator()
            for request in requests {
                try Task.checkCancellation()
                let (image, pixels) = try validator.decode(request.data)
                result.append((request.id, image, pixels))
            }
            return result
        }.value
        var next: [ObjectID: CGImage] = [:]
        var count: Int64 = 0
        for item in decoded {
            try Task.checkCancellation()
            count = try Self.checkedTotalPixels(current: count, adding: item.2)
            next[item.0] = item.1
        }
        images = next
        totalPixels = count
    }
    public func snapshot() -> [ObjectID: CGImage] { images }
    public func approvedPixelCount() -> Int64 { totalPixels }
}

public struct LinkedResourceResolver: Sendable {
    public let root: URL
    public init(root: URL) { self.root = root.standardizedFileURL.resolvingSymlinksInPath() }
    public func resolve(_ relativePath: String) throws -> URL {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/") else {
            throw ImageApprovalError.pathEscape
        }
        let candidate = root.appendingPathComponent(relativePath).standardizedFileURL.resolvingSymlinksInPath()
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(prefix) else { throw ImageApprovalError.pathEscape }
        return candidate
    }
}

private struct EmbeddedRequest: Sendable {
    var id: ObjectID
    var data: Data
}
private func embeddedRequests(_ document: EditorDocument) -> [EmbeddedRequest] {
    document.layers.flatMap { layer in layer.nodes.flatMap(embeddedRequests) }
}
private func embeddedRequests(_ node: SceneNode) -> [EmbeddedRequest] {
    switch node {
    case .image(let image):
        if case .embedded(let data) = image.storage { return [EmbeddedRequest(id: image.id, data: data)] }
        return []
    case .group(let group): return group.children.flatMap(embeddedRequests)
    default: return []
    }
}
