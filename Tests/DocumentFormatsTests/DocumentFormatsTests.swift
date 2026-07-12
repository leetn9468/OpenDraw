import DocumentFormats
import DocumentModel
import Foundation
import Geometry
import Testing

@Test func nativeRoundTripIsDeterministic() throws {
    let codec = NativeDocumentCodec()
    let document = EditorDocument.sample()
    let first = try codec.encode(document)
    let decoded = try codec.decode(first)
    let second = try codec.encode(decoded)
    #expect(document == decoded)
    #expect(first == second)
}

@Test func rejectsUnknownVersion() throws {
    let data = try NativeDocumentCodec().encode(.sample())
    let changed = Data(
        String(decoding: data, as: UTF8.self).replacingOccurrences(
            of: "\"formatVersion\":\(EditorDocument.formatVersion)", with: "\"formatVersion\":99"
        ).utf8)
    #expect(throws: (any Error).self) { try NativeDocumentCodec().decode(changed) }
}

@Test func svgExportIsDeterministicAndEscaped() throws {
    var document = EditorDocument.sample()
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
    let url = directory.appendingPathComponent("sample.vfd")
    let codec = NativeDocumentCodec()
    let document = EditorDocument.sample()
    try codec.saveAtomically(document, to: url)
    #expect(try codec.load(from: url) == document)
    var changed = document
    changed.width = 700
    try codec.saveAtomically(changed, to: url)
    #expect(try codec.load(from: url).width == 700)
}

@Test func migratesVersionTwoDocument() throws {
    let codec = NativeDocumentCodec()
    let current = EditorDocument.sample()
    let data = try codec.encode(current)
    var root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    root["formatVersion"] = 2
    let old = try JSONSerialization.data(withJSONObject: root)
    let migrated = try codec.decode(old)
    #expect(migrated.formatVersion == EditorDocument.formatVersion)
    #expect(migrated.layers == current.layers)
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
    var document = EditorDocument.sample()
    document.gradients = [gradient]
    document.layers[0].paths[0].style.fillGradientID = gradient.id
    document.layers[0].imageObjects = [
        ImageObject(
            frame: Geometry.Rect(minX: 0, minY: 0, maxX: 10, maxY: 10), storage: .linked(relativePath: "image.png"),
            pixelWidth: 1, pixelHeight: 1)
    ]
    let result = try SVGExporter().export(document)
    #expect(result.warnings.map(\.code) == ["SVG-GRADIENT-DEFERRED", "SVG-IMAGE-DEFERRED"])
}

@Test func svgImportIsIsolatedSafeAndDiagnosable() throws {
    let input = Data(
        "<svg width=\"100\" height=\"80\"><rect x=\"5\" y=\"6\" width=\"20\" height=\"30\" fill=\"#FF0000\"/><script>alert(1)</script><circle/></svg>"
            .utf8)
    let result = try SVGImporter().importData(input)
    #expect(result.document.layers[0].paths.count == 1)
    #expect(result.warnings.map(\.code) == ["SVG-UNSAFE-IGNORED", "SVG-UNSUPPORTED-CIRCLE"])
    #expect(throws: (any Error).self) { try SVGImporter().importData(Data("<svg><rect>".utf8)) }
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
