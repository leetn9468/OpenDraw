import DocumentModel
import EditorCore
import Foundation
import Geometry

public struct FormatWarning: Hashable, Sendable {
    public var code: String
    public var message: String
}
public struct ExportResult: Sendable {
    public var data: Data
    public var warnings: [FormatWarning]
}

public struct SVGExporter: Sendable {
    public init() {}
    public func export(_ document: EditorDocument) throws -> ExportResult {
        try document.validate()
        let swatches = Dictionary(uniqueKeysWithValues: document.swatches.map { ($0.id, $0.color) })
        var warnings: [FormatWarning] = []
        var body = ""
        for layer in document.layers where layer.isVisible {
            body += "<g id=\"\(escape(layer.name))\">"
            for node in layer.nodes { body += export(node, swatches: swatches, warnings: &warnings) }
            body += "</g>"
        }
        // SVG viewBox uses visual bounds because it must contain the rendered ink.
        let content = document.layers.filter(\.isVisible).flatMap(\.nodes).compactMap(\.visualBounds)
        let viewBox: Geometry.Rect
        if let first = content.first {
            viewBox = content.dropFirst().reduce(first) { $0.union($1) }
        } else {
            viewBox = Geometry.Rect(minX: 0, minY: 0, maxX: document.width, maxY: document.height)
        }
        let svg =
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(number(document.width))\" height=\"\(number(document.height))\" viewBox=\"\(number(viewBox.minX)) \(number(viewBox.minY)) \(number(viewBox.width)) \(number(viewBox.height))\">\(body)</svg>"
        return ExportResult(data: Data(svg.utf8), warnings: Array(Set(warnings)).sorted { $0.code < $1.code })
    }
    private func export(_ node: SceneNode, swatches: [ObjectID: SRGBColor], warnings: inout [FormatWarning]) -> String {
        switch node {
        case .path(let object):
            var d = ""
            for subpath in object.path.subpaths {
                guard let first = subpath.segments.first else { continue }
                d += "M \(number(first.start.x)) \(number(first.start.y))"
                for s in subpath.segments {
                    d +=
                        " C \(number(s.control1.x)) \(number(s.control1.y)) \(number(s.control2.x)) \(number(s.control2.y)) \(number(s.end.x)) \(number(s.end.y))"
                }
                if subpath.isClosed { d += " Z" }
            }
            if object.style.fillGradientID != nil {
                warnings.append(
                    FormatWarning(
                        code: "SVG-GRADIENT-DEFERRED", message: "Gradient was exported using its fallback solid fill."))
            }
            let fill = (object.style.fillSwatchID.flatMap { swatches[$0] } ?? object.style.fill).map(css) ?? "none"
            let stroke =
                (object.style.strokeSwatchID.flatMap { swatches[$0] } ?? object.style.stroke).map(css) ?? "none"
            return
                "<path d=\"\(d)\" fill=\"\(fill)\" fill-rule=\"\(object.path.fillRule == .evenOdd ? "evenodd":"nonzero")\" stroke=\"\(stroke)\" stroke-width=\"\(number(object.style.strokeWidth))\" opacity=\"\(number(object.style.opacity ?? 1))\" transform=\"\(matrix(object.transform))\"/>"
        case .text(let text):
            return
                "<text x=\"\(number(text.origin.x))\" y=\"\(number(text.origin.y))\" font-family=\"\(escape(text.fontName))\" font-size=\"\(number(text.fontSize))\" fill=\"\(css(text.color))\" transform=\"\(matrix(text.transform))\">\(escape(text.text))</text>"
        case .image:
            warnings.append(
                FormatWarning(code: "SVG-IMAGE-DEFERRED", message: "Raster images are omitted from SVG export."))
            return ""
        case .group(let group):
            return
                "<g transform=\"\(matrix(group.transform))\">\(group.children.map{export($0,swatches:swatches,warnings:&warnings)}.joined())</g>"
        }
    }
    private func matrix(_ t: Geometry.AffineTransform) -> String {
        "matrix(\(number(t.a)) \(number(t.b)) \(number(t.c)) \(number(t.d)) \(number(t.tx)) \(number(t.ty)))"
    }
    private func number(_ value: Double) -> String {
        String(format: "%.6g", locale: Locale(identifier: "en_US_POSIX"), value)
    }
    private func css(_ color: SRGBColor) -> String {
        String(format: "#%02X%02X%02X", Int(color.red * 255), Int(color.green * 255), Int(color.blue * 255))
    }
    private func escape(_ string: String) -> String {
        string.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
    }
}
