import DocumentFormats
import Foundation
import Testing

private func nestedJSON(depth: Int) -> Data {
    var value = "0"
    for _ in 1..<depth { value = "[\(value)]" }
    return Data(value.utf8)
}

@Test func verify011JSONDepthAndValueBoundaries() throws {
    #expect(try JSONStructureValidator().parseAndValidate(nestedJSON(depth: 128)) is [Any])
    #expect(throws: InputLimitError.nestingDepth) {
        try JSONStructureValidator().parseAndValidate(nestedJSON(depth: 129))
    }
    let accepted = Data(("[" + Array(repeating: "0", count: 999_999).joined(separator: ",") + "]").utf8)
    #expect(try JSONStructureValidator().parseAndValidate(accepted) is [Any])
    let rejected = Data(("[" + Array(repeating: "0", count: 1_000_000).joined(separator: ",") + "]").utf8)
    #expect(throws: InputLimitError.valueCount) { try JSONStructureValidator().parseAndValidate(rejected) }
}

@Test func boundedReaderRejectsMetadataBeforeReadAndTruncation() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let oversized = directory.appendingPathComponent("large")
    FileManager.default.createFile(atPath: oversized.path, contents: nil)
    let handle = try FileHandle(forWritingTo: oversized)
    try handle.truncate(atOffset: UInt64(InputLimits.maximumSVGBytes + 1))
    try handle.close()
    #expect(throws: InputLimitError.byteCount) {
        try BoundedFileReader().read(oversized, maximumBytes: InputLimits.maximumSVGBytes)
    }
    let truncated = Data("{\"formatVersion\":4".utf8)
    #expect(throws: (any Error).self) { try NativeDocumentCodec().decode(truncated) }
}
