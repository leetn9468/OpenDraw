import DocumentModel
import EditorCore
import Foundation
import Geometry

public struct ImportResult: Sendable {
    public var document: EditorDocument
    public var warnings: [FormatWarning]
}

public struct SVGImporter: Sendable {
    public static let maximumBytes = InputLimits.maximumSVGBytes
    public init() {}
    public func importFile(_ url: URL) throws -> ImportResult {
        try importData(BoundedFileReader().read(url, maximumBytes: Self.maximumBytes))
    }
    public func importData(_ data: Data) throws -> ImportResult {
        guard data.count <= Self.maximumBytes else { throw InputLimitError.byteCount }
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        parser.shouldResolveExternalEntities = false
        let parsed = parser.parse()
        guard parsed, delegate.sawRoot, delegate.depth == 0 else {
            throw delegate.failure
                ?? EditorError.corruptInput(parser.parserError?.localizedDescription ?? "Invalid SVG")
        }
        let document = try EditorDocument(
            width: delegate.width ?? 640, height: delegate.height ?? 480,
            layers: [Layer(name: "Imported SVG", nodes: delegate.nodes)])
        try document.validate()
        return ImportResult(document: document, warnings: delegate.warnings)
    }
}

private final class Delegate: NSObject, XMLParserDelegate {
    let namespace = "http://www.w3.org/2000/svg"
    var width: Double?
    var height: Double?
    var nodes: [SceneNode] = []
    var warnings: [FormatWarning] = []
    var sawRoot = false
    var depth = 0
    var elementCount = 0
    var characterByteCounts: [Int] = []
    var suppressedDepth: Int?
    var failure: Error?
    func parser(
        _ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName qName: String?,
        attributes: [String: String]
    ) {
        depth += 1
        elementCount += 1
        characterByteCounts.append(0)
        guard enforce(elementCount <= InputLimits.maximumSVGElements, .elementCount, parser),
            enforce(depth <= InputLimits.maximumSVGDepth, .nestingDepth, parser),
            enforce(name.utf8.count <= InputLimits.maximumStringUTF8Bytes, .stringLength, parser)
        else { return }
        for (key, value) in attributes {
            guard
                enforce(
                    key.utf8.count <= InputLimits.maximumStringUTF8Bytes
                        && value.utf8.count <= InputLimits.maximumStringUTF8Bytes, .stringLength, parser)
            else { return }
        }
        if let suppressedDepth {
            _ = suppressedDepth
            return
        }
        let lower = name.lowercased()
        if depth == 1 {
            guard !sawRoot, lower == "svg", namespaceURI == namespace else {
                abort(InputLimitError.invalidStructure, parser)
                return
            }
            sawRoot = true
            width = parseLength(attributes["width"], property: "width", parser: parser)
            height = parseLength(attributes["height"], property: "height", parser: parser)
            return
        }
        if lower == "svg" {
            abort(InputLimitError.invalidStructure, parser)
            return
        }
        switch lower {
        case "script", "foreignobject":
            addWarning(
                code: "SVG-UNSAFE-IGNORED", message: "Active SVG subtree was ignored.", property: lower, parser: parser)
            suppressedDepth = depth
        case "rect":
            let x = parseLength(attributes["x"], property: "x", parser: parser) ?? 0
            let y = parseLength(attributes["y"], property: "y", parser: parser) ?? 0
            guard let w = parseLength(attributes["width"], property: "width", parser: parser),
                let h = parseLength(attributes["height"], property: "height", parser: parser), w > 0, h > 0
            else {
                addWarning(
                    code: "SVG-INVALID-RECT", message: "Invalid rectangle was skipped.", property: "geometry",
                    parser: parser)
                return
            }
            guard nodes.count < InputLimits.maximumSVGNodes else {
                abort(InputLimitError.nodeCount, parser)
                return
            }
            nodes.append(.path(rect(x: x, y: y, w: w, h: h, attributes: attributes)))
        case "g", "title", "desc": break
        default:
            addWarning(
                code: "SVG-UNSUPPORTED-\(name.uppercased())", message: "Unsupported SVG element \(name) was skipped.",
                property: lower, parser: parser)
        }
    }
    func parser(
        _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?
    ) {
        if suppressedDepth == depth { suppressedDepth = nil }
        if !characterByteCounts.isEmpty { characterByteCounts.removeLast() }
        depth -= 1
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard !characterByteCounts.isEmpty else { return }
        let result = characterByteCounts[characterByteCounts.count - 1].addingReportingOverflow(string.utf8.count)
        guard !result.overflow, result.partialValue <= InputLimits.maximumStringUTF8Bytes else {
            abort(InputLimitError.stringLength, parser)
            return
        }
        characterByteCounts[characterByteCounts.count - 1] = result.partialValue
    }
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
        abort(InputLimitError.invalidStructure, parser)
    }
    func parser(
        _ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?
    ) { abort(InputLimitError.invalidStructure, parser) }
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? {
        abort(InputLimitError.invalidStructure, parser)
        return nil
    }
    private func enforce(_ condition: Bool, _ error: InputLimitError, _ parser: XMLParser) -> Bool {
        if !condition { abort(error, parser) }
        return condition
    }
    private func abort(_ error: Error, _ parser: XMLParser) {
        if failure == nil { failure = error }
        parser.abortParsing()
    }
    private func addWarning(code: String, message: String, property: String, parser: XMLParser) {
        guard warnings.count < InputLimits.maximumWarnings else {
            abort(InputLimitError.warningCount, parser)
            return
        }
        warnings.append(
            FormatWarning(
                code: code, message: message, property: property, reason: message, occurrenceCount: 1,
                layerName: "Imported SVG", layerIndex: 0, nodeIndex: nodes.count, line: parser.lineNumber,
                column: parser.columnNumber))
    }
    private func parseLength(_ value: String?, property: String, parser: XMLParser) -> Double? {
        guard let value else { return nil }
        do { return try SVGLengthParser().parse(value) } catch {
            addWarning(
                code: "SVG-INVALID-UNIT", message: "Unsupported or invalid \(property) unit.", property: property,
                parser: parser)
            return nil
        }
    }
    private func rect(x: Double, y: Double, w: Double, h: Double, attributes: [String: String]) -> PathObject {
        let points = [
            Point(x: x, y: y), Point(x: x + w, y: y), Point(x: x + w, y: y + h), Point(x: x, y: y + h),
            Point(x: x, y: y),
        ]
        return PathObject(
            segments: zip(points, points.dropFirst()).map {
                CubicBezier(start: $0, control1: $0, control2: $1, end: $1)
            }, isClosed: true,
            style: PathStyle(
                fill: color(attributes["fill"]), stroke: color(attributes["stroke"]),
                strokeWidth: (try? SVGLengthParser().parse(attributes["stroke-width"] ?? "1")) ?? 1))
    }
    private func color(_ value: String?) -> SRGBColor? {
        guard let value, value != "none", value.hasPrefix("#"), value.count == 7,
            let raw = Int(value.dropFirst(), radix: 16)
        else { return nil }
        return SRGBColor(
            red: Double((raw >> 16) & 255) / 255, green: Double((raw >> 8) & 255) / 255, blue: Double(raw & 255) / 255)
    }
}
