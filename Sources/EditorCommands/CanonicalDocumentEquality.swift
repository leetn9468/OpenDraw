import DocumentModel
import Foundation

public enum CanonicalDocumentEquality {
    /// VERIFY-022 freezes the v4 volatile-field set as empty.
    public static let volatileFields: Set<String> = []

    public static func bytes(for document: EditorDocument) throws -> Data {
        try document.validate()
        return try canonicalBytes(document)
    }

    public static func equals(_ lhs: EditorDocument, _ rhs: EditorDocument) throws -> Bool {
        try bytes(for: lhs) == bytes(for: rhs)
    }
}

func canonicalBytes<Value: Encodable>(_ value: Value) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(value)
}
