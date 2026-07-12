import DocumentFormats
import DocumentModel
import EditorCore
import Foundation
import Geometry
import Testing

@Test func nativeRoundTripIsDeterministic() throws {
    let codec = NativeDocumentCodec()
    let document = try EditorDocument.sample()
    let first = try codec.encode(document)
    let decoded = try codec.decode(first)
    let second = try codec.encode(decoded)
    #expect(document == decoded)
    #expect(first == second)
}

@Test func rejectsUnknownVersion() throws {
    let data = try NativeDocumentCodec().encode(try .sample())
    let changed = Data(
        String(decoding: data, as: UTF8.self).replacingOccurrences(
            of: "\"formatVersion\":\(EditorDocument.formatVersion)", with: "\"formatVersion\":99"
        ).utf8)
    #expect(throws: (any Error).self) { try NativeDocumentCodec().decode(changed) }
}

@Test func svgExportIsDeterministicAndEscaped() throws {
    var document = try EditorDocument.sample()
    document.layers[0].name = "A&B\""
    let exporter = SVGExporter()
    let first = try exporter.export(document)
    let second = try exporter.export(document)
    #expect(first.data == second.data)
    let string = String(decoding: first.data, as: UTF8.self)
    #expect(string.contains("<path"))
    #expect(string.contains("A&amp;B&quot;"))
    #expect(first.warnings.isEmpty)
}

@Test func atomicSaveAndLoad() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("sample.odraw")
    let codec = NativeDocumentCodec()
    let document = try EditorDocument.sample()
    try codec.saveAtomically(document, to: url)
    #expect(try codec.load(from: url) == document)
    var changed = document
    changed.width = 700
    try codec.saveAtomically(changed, to: url)
    #expect(try codec.load(from: url).width == 700)
}

@Test func migratesVersionTwoDocument() throws {
    let codec = NativeDocumentCodec()
    let fixture = try #require(
        Bundle.module.url(forResource: "v2-reference", withExtension: "json", subdirectory: "Fixtures"))
    let migrated = try codec.decode(Data(contentsOf: fixture))
    #expect(migrated.formatVersion == 4)
    #expect(migrated.layers[0].nodes.count == 1)
}

@Test func migratesVersionThreeDocumentAndRoundTripsHistoricalFixtures() throws {
    let codec = NativeDocumentCodec()
    for name in ["v2-reference", "v3-reference"] {
        let fixture = try #require(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        let migrated = try codec.decode(Data(contentsOf: fixture))
        #expect(migrated.formatVersion == 4)
        let reopened = try codec.decode(codec.encode(migrated))
        #expect(reopened == migrated)
    }
}

private func canonicalReferenceDocument() throws -> EditorDocument {
    let layerID = ObjectID(rawValue: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000100")))
    let pathID = ObjectID(rawValue: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000101")))
    let segment = CubicBezier(
        start: Point(x: 0, y: 0), control1: Point(x: 0, y: 10), control2: Point(x: 10, y: 10), end: Point(x: 10, y: 0))
    let path = PathObject(
        id: pathID, segments: [segment],
        style: PathStyle(fill: SRGBColor(red: 1, green: 0, blue: 0), stroke: nil, strokeWidth: 0))
    return try EditorDocument(
        width: 100, height: 80, layers: [Layer(id: layerID, name: "Reference", nodes: [.path(path)])])
}

@Test func v4CanonicalGoldenBytes() throws {
    let encoded = try NativeDocumentCodec().encode(canonicalReferenceDocument())
    let fixture = try #require(
        Bundle.module.url(forResource: "v4-canonical-golden", withExtension: "odraw", subdirectory: "Fixtures"))
    var golden = try Data(contentsOf: fixture)
    if golden.last == 0x0A { golden.removeLast() }
    #expect(encoded == golden)
    #expect(try NativeDocumentCodec().decode(encoded) == canonicalReferenceDocument())
}

@Test func rasterLoaderEnforcesLimitsAndSafeLinks() throws {
    let png = try #require(
        Data(
            base64Encoded:
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
    let loader = RasterResourceLoader()
    let frame = Geometry.Rect(minX: 0, minY: 0, maxX: 10, maxY: 10)
    let image = try loader.embedded(data: png, frame: frame)
    #expect(image.pixelWidth == 1)
    #expect(throws: (any Error).self) {
        try loader.linked(relativePath: "../secret.png", frame: frame, pixelWidth: 1, pixelHeight: 1)
    }
}

@Test func svgReportsFeatureLoss() throws {
    let gradient = GradientResource(
        name: "G", kind: .linear, start: Geometry.Point(x: 0, y: 0), end: Geometry.Point(x: 10, y: 0),
        stops: [ColorStop(offset: 0, color: .black), ColorStop(offset: 1, color: .white)])
    var document = try EditorDocument.sample()
    document.gradients = [gradient]
    let firstID = try #require(document.layers[0].nodes.first?.id)
    _ = document.mutatePath(id: firstID) { $0.style.fillGradientID = gradient.id }
    document.layers[0].nodes.append(
        .image(
            ImageObject(
                frame: Geometry.Rect(minX: 0, minY: 0, maxX: 10, maxY: 10), storage: .linked(relativePath: "image.png"),
                pixelWidth: 1, pixelHeight: 1)))
    let result = try SVGExporter().export(document)
    let svg = String(decoding: result.data, as: UTF8.self)
    #expect(svg.contains("<linearGradient"))
    #expect(svg.contains("fill=\"url(#g"))
    #expect(result.warnings.map(\.code) == ["SVG-IMAGE-OMITTED"])
    #expect(result.warnings.first?.objectID != nil)
}

@Test func svgImportIsIsolatedSafeAndDiagnosable() throws {
    let input = Data(
        "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"80\"><rect x=\"5\" y=\"6\" width=\"20\" height=\"30\" fill=\"#FF0000\"/><script><rect width=\"9\" height=\"9\"/></script><circle/></svg>"
            .utf8)
    let result = try SVGImporter().importData(input)
    #expect(result.document.layers[0].nodes.count == 1)
    #expect(result.warnings.map(\.code) == ["SVG-UNSAFE-IGNORED", "SVG-UNSUPPORTED-CIRCLE"])
    #expect(throws: (any Error).self) {
        try SVGImporter().importData(Data("<svg xmlns=\"http://www.w3.org/2000/svg\"><rect>".utf8))
    }
}

@Test func svgRejectsWrongNamespaceRepeatedRootAndEntityDeclaration() {
    let importer = SVGImporter()
    for input in [
        "<svg/>",
        "<svg xmlns=\"http://www.w3.org/2000/svg\"><svg/></svg>",
        "<!DOCTYPE svg [<!ENTITY x \"boom\">]><svg xmlns=\"http://www.w3.org/2000/svg\">&x;</svg>",
    ] { #expect(throws: (any Error).self) { try importer.importData(Data(input.utf8)) } }
}

@Test func nativeDecoderDeterministicMalformedCorpus() {
    var state: UInt64 = 0xA110
    for length in 0..<128 {
        var bytes = [UInt8]()
        for _ in 0..<length {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            bytes.append(UInt8(truncatingIfNeeded: state >> 32))
        }
        #expect(throws: (any Error).self) { try NativeDocumentCodec().decode(Data(bytes)) }
    }
}
