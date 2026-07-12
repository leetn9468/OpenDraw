import EditorCore
import Foundation

public enum InputLimitError: Error, Equatable, Sendable {
    case byteCount, nestingDepth, valueCount, stringLength, elementCount, nodeCount, warningCount, invalidStructure
}

public enum InputLimits {
    public static let maximumNativeBytes = 100 * 1_024 * 1_024
    public static let maximumSVGBytes = 10 * 1_024 * 1_024
    public static let maximumJSONDepth = 128
    public static let maximumJSONValues = 1_000_000
    public static let maximumSVGDepth = 256
    public static let maximumSVGElements = 100_000
    public static let maximumSVGNodes = 100_000
    public static let maximumWarnings = 1_000
    public static let maximumStringUTF8Bytes = 1_000_000
}

public struct BoundedFileReader: Sendable {
    public init() {}
    public func read(_ url: URL, maximumBytes: Int) throws -> Data {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true else { throw InputLimitError.invalidStructure }
        if let size = values.fileSize, size > maximumBytes { throw InputLimitError.byteCount }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else { throw InputLimitError.byteCount }
        return data
    }
}

public struct JSONStructureValidator: Sendable {
    public init() {}
    public func parseAndValidate(_ data: Data) throws -> Any {
        let root = try JSONSerialization.jsonObject(with: data)
        var count = 0
        try visit(root, depth: 1, count: &count)
        return root
    }
    private func visit(_ value: Any, depth: Int, count: inout Int) throws {
        guard depth <= InputLimits.maximumJSONDepth else { throw InputLimitError.nestingDepth }
        count += 1
        guard count <= InputLimits.maximumJSONValues else { throw InputLimitError.valueCount }
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                try validateString(key)
                try visit(child, depth: depth + 1, count: &count)
            }
        } else if let array = value as? [Any] {
            for child in array { try visit(child, depth: depth + 1, count: &count) }
        } else if let string = value as? String {
            try validateString(string)
        }
    }
    private func validateString(_ value: String) throws {
        guard value.utf8.count <= InputLimits.maximumStringUTF8Bytes else { throw InputLimitError.stringLength }
    }
}
