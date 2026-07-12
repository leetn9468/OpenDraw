import DocumentModel
import EditorCore
import Foundation
import Geometry

public struct NativeDocumentCodec: Sendable {
    public static let maximumBytes = 100 * 1_024 * 1_024
    public init() {}
    public func encode(_ document: EditorDocument) throws -> Data {
        try document.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(document)
    }
    public func decode(_ data: Data) throws -> EditorDocument {
        guard data.count <= Self.maximumBytes else { throw EditorError.corruptInput("Document exceeds size limit") }
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let version = root?["formatVersion"] as? Int else {
            throw EditorError.corruptInput("Missing format version")
        }
        let decoder = JSONDecoder()
        let document: EditorDocument
        switch version {
        case 4: document = try decoder.decode(EditorDocument.self, from: data)
        case 3: document = try migrateV3ToV4(try decoder.decode(LegacyV3Document.self, from: data))
        case 2:
            let v2 = try decoder.decode(LegacyV2Document.self, from: data)
            let v3 = try migrateV2ToV3(v2)
            try migrateV3ToV4(v3).validate()
            document = try migrateV3ToV4(v3)
        default: throw EditorError.unsupported("Unsupported document version \(version)")
        }
        try document.validate()
        return document
    }
    public func saveAtomically(_ document: EditorDocument, to url: URL) throws {
        let data = try encode(document)
        let manager = FileManager.default
        let temporary = url.deletingLastPathComponent().appendingPathComponent(
            ".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try data.write(to: temporary, options: .withoutOverwriting)
            if manager.fileExists(atPath: url.path) {
                _ = try manager.replaceItemAt(url, withItemAt: temporary)
            } else {
                try manager.moveItem(at: temporary, to: url)
            }
        } catch {
            try? manager.removeItem(at: temporary)
            throw error
        }
    }
    public func load(from url: URL) throws -> EditorDocument {
        try decode(Data(contentsOf: url, options: .mappedIfSafe))
    }
}

private struct LegacyPathObject: Codable {
    var id: ObjectID
    var path: BezierPath
    var style: PathStyle
    var transform: Geometry.AffineTransform
}
private struct LegacyTextObject: Codable {
    var id: ObjectID
    var text: String
    var origin: Point
    var fontName: String
    var fontSize: Double
    var color: SRGBColor
    var transform: Geometry.AffineTransform
}
private struct LegacyImageObject: Codable {
    var id: ObjectID
    var frame: Rect
    var storage: ImageStorage
    var pixelWidth: Int
    var pixelHeight: Int
}
private struct LegacyLayer: Codable {
    var id: ObjectID
    var name: String
    var isVisible: Bool
    var isLocked: Bool
    var paths: [LegacyPathObject]
    var textObjects: [LegacyTextObject]?
    var imageObjects: [LegacyImageObject]?
}
private struct LegacyPayload: Codable {
    var formatVersion: Int
    var width: Double
    var height: Double
    var unit: MeasurementUnit
    var layers: [LegacyLayer]
    var swatches: [Swatch]?
    var gradients: [GradientResource]?
}
private struct LegacyV2Document: Decodable {
    var payload: LegacyPayload
    init(from decoder: Decoder) throws { payload = try LegacyPayload(from: decoder) }
}
private struct LegacyV3Document: Decodable {
    var payload: LegacyPayload
    init(from decoder: Decoder) throws { payload = try LegacyPayload(from: decoder) }
    init(payload: LegacyPayload) { self.payload = payload }
}

private func migrateV2ToV3(_ source: LegacyV2Document) throws -> LegacyV3Document {
    var payload = source.payload
    payload.formatVersion = 3
    return LegacyV3Document(payload: payload)
}
private func migrateV3ToV4(_ source: LegacyV3Document) throws -> EditorDocument {
    let payload = source.payload
    let layers = payload.layers.map { legacy in
        // v3 rendered paths, then images, then text; preserving that order preserves what users saw.
        var nodes = legacy.paths.map {
            var style = $0.style
            if style.opacity == nil { style.opacity = 1 }
            if style.blendMode == nil { style.blendMode = .normal }
            return SceneNode.path(
                PathObject(
                    id: $0.id, path: CompoundPath(subpaths: [$0.path], fillRule: $0.path.fillRule), style: style,
                    transform: $0.transform))
        }
        nodes += (legacy.imageObjects ?? []).map {
            .image(
                ImageObject(
                    id: $0.id, frame: $0.frame, storage: $0.storage, pixelWidth: $0.pixelWidth,
                    pixelHeight: $0.pixelHeight))
        }
        nodes += (legacy.textObjects ?? []).map {
            .text(
                TextObject(
                    id: $0.id, text: $0.text, origin: $0.origin, fontName: $0.fontName, fontSize: $0.fontSize,
                    color: $0.color, transform: $0.transform))
        }
        return Layer(
            id: legacy.id, name: legacy.name, isVisible: legacy.isVisible, isLocked: legacy.isLocked, nodes: nodes)
    }
    return try EditorDocument(
        width: payload.width, height: payload.height, unit: payload.unit, layers: layers,
        swatches: payload.swatches ?? [], gradients: payload.gradients ?? [])
}
