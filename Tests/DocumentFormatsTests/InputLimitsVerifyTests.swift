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

private let svgOpen = "<svg xmlns=\"http://www.w3.org/2000/svg\">"

@Test func verify011SVGElementAndNodeBoundaries() throws {
    let rectangle = "<rect width=\"1\" height=\"1\"/>"
    let accepted = Data((svgOpen + String(repeating: rectangle, count: 99_999) + "</svg>").utf8)
    let result = try SVGImporter().importData(accepted)
    #expect(result.document.layers[0].nodes.count == 99_999)

    let rejected = Data((svgOpen + String(repeating: "<g/>", count: 100_000) + "</svg>").utf8)
    #expect(throws: InputLimitError.elementCount) { try SVGImporter().importData(rejected) }
}

@Test func verify011SVGWarningAndDepthBoundaries() throws {
    let acceptedWarnings = Data((svgOpen + String(repeating: "<circle/>", count: 1_000) + "</svg>").utf8)
    #expect(try SVGImporter().importData(acceptedWarnings).warnings.count == 1_000)
    let rejectedWarnings = Data((svgOpen + String(repeating: "<circle/>", count: 1_001) + "</svg>").utf8)
    #expect(throws: InputLimitError.warningCount) { try SVGImporter().importData(rejectedWarnings) }

    func nestedSVG(childDepth: Int) -> Data {
        Data(
            (svgOpen + String(repeating: "<g>", count: childDepth)
                + String(repeating: "</g>", count: childDepth) + "</svg>").utf8)
    }
    #expect(try SVGImporter().importData(nestedSVG(childDepth: 255)).document.layers[0].nodes.isEmpty)
    #expect(throws: InputLimitError.nestingDepth) { try SVGImporter().importData(nestedSVG(childDepth: 256)) }
}

@Test func verify011SVGStringBoundaries() throws {
    let acceptedAttribute = Data(
        (svgOpen.dropLast() + " data-x=\""
            + String(repeating: "a", count: 1_000_000) + "\"></svg>").utf8)
    #expect(try SVGImporter().importData(acceptedAttribute).document.layers[0].nodes.isEmpty)
    let rejectedAttribute = Data(
        (svgOpen.dropLast() + " data-x=\""
            + String(repeating: "a", count: 1_000_001) + "\"></svg>").utf8)
    #expect(throws: InputLimitError.stringLength) { try SVGImporter().importData(rejectedAttribute) }

    let acceptedCharacters = Data(
        (svgOpen + "<title>" + String(repeating: "x", count: 1_000_000)
            + "</title></svg>").utf8)
    #expect(try SVGImporter().importData(acceptedCharacters).warnings.isEmpty)
    let rejectedCharacters = Data(
        (svgOpen + "<title>" + String(repeating: "x", count: 1_000_001)
            + "</title></svg>").utf8)
    #expect(throws: InputLimitError.stringLength) { try SVGImporter().importData(rejectedCharacters) }

}
