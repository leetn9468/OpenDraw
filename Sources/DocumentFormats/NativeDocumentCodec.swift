import DocumentModel
import EditorCore
import Foundation

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
        let probe = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let version = probe?["formatVersion"] as? Int else {
            throw EditorError.corruptInput("Missing format version")
        }
        guard version <= EditorDocument.formatVersion, version >= 2 else {
            throw EditorError.unsupported("Unsupported document version \(version)")
        }
        let migrated = version == 2 ? try migrateV2(data) : data
        var document = try JSONDecoder().decode(EditorDocument.self, from: migrated)
        document.formatVersion = EditorDocument.formatVersion
        try document.validate()
        return document
    }
    private func migrateV2(_ data: Data) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EditorError.corruptInput("Invalid v2 document")
        }
        root["formatVersion"] = EditorDocument.formatVersion
        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
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
