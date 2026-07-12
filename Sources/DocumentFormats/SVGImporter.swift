import DocumentModel
import EditorCore
import Foundation
import Geometry

public struct ImportResult: Sendable {
    public var document: EditorDocument
    public var warnings: [FormatWarning]
}

public struct SVGImporter: Sendable {
    public static let maximumBytes = 10 * 1_024 * 1_024
    public init() {}
    public func importData(_ data: Data) throws -> ImportResult {
        guard data.count <= Self.maximumBytes else { throw EditorError.corruptInput("SVG exceeds size limit") }
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), delegate.sawRoot else {
            throw EditorError.corruptInput(parser.parserError?.localizedDescription ?? delegate.error ?? "Invalid SVG")
        }
        let document = try EditorDocument(
            width: delegate.width ?? 640, height: delegate.height ?? 480,
            layers: [Layer(name: "Imported SVG", nodes: delegate.paths.map(SceneNode.path))])
        return ImportResult(document: document, warnings: Array(Set(delegate.warnings)).sorted { $0.code < $1.code })
    }
}

private final class Delegate: NSObject, XMLParserDelegate {
    var width: Double?
    var height: Double?
    var paths: [PathObject] = []
    var warnings: [FormatWarning] = []
    var sawRoot = false
    var error: String?
    func parser(
        _ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName qName: String?,
        attributes: [String: String]
    ) {
        switch name.lowercased() {
        case "svg":
            sawRoot = true
            width = number(attributes["width"])
            height = number(attributes["height"])
        case "rect":
            if let x = number(attributes["x"]) ?? 0 as Double?, let y = number(attributes["y"]) ?? 0 as Double?,
                let w = number(attributes["width"]), let h = number(attributes["height"]), w > 0, h > 0
            {
                paths.append(rect(x: x, y: y, w: w, h: h, attributes: attributes))
            } else {
                warnings.append(FormatWarning(code: "SVG-INVALID-RECT", message: "Invalid rectangle was skipped."))
            }
        case "script", "foreignobject":
            warnings.append(FormatWarning(code: "SVG-UNSAFE-IGNORED", message: "Active SVG content was ignored."))
        case "g", "title", "desc": break
        default:
            if name.lowercased() != "svg" {
                warnings.append(
                    FormatWarning(
                        code: "SVG-UNSUPPORTED-\(name.uppercased())",
                        message: "Unsupported SVG element \(name) was skipped."))
            }
        }
    }
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? {
        warnings.append(FormatWarning(code: "SVG-EXTERNAL-BLOCKED", message: "External entity was blocked."))
        return nil
    }
    private func number(_ text: String?) -> Double? {
        guard let text else { return nil }
        return Double(text.replacingOccurrences(of: "px", with: ""))
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
                strokeWidth: number(attributes["stroke-width"]) ?? 1))
    }
    private func color(_ value: String?) -> SRGBColor? {
        guard let value, value != "none", value.hasPrefix("#"), value.count == 7,
            let raw = Int(value.dropFirst(), radix: 16)
        else { return nil }
        return SRGBColor(
            red: Double((raw >> 16) & 255) / 255, green: Double((raw >> 8) & 255) / 255, blue: Double(raw & 255) / 255)
    }
}
