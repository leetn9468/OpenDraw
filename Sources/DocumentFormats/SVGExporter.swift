import DocumentModel
import EditorCore
import Foundation

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
        var body = ""
        var warnings: [FormatWarning] = []
        for layer in document.layers where layer.isVisible {
            body += "<g id=\"\(escape(layer.name))\">"
            for object in layer.paths {
                guard let first = object.segments.first else { continue }
                var d = "M \(number(first.start.x)) \(number(first.start.y))"
                for s in object.segments {
                    d +=
                        " C \(number(s.control1.x)) \(number(s.control1.y)) \(number(s.control2.x)) \(number(s.control2.y)) \(number(s.end.x)) \(number(s.end.y))"
                }
                if object.path.isClosed { d += " Z" }
                if object.style.fillGradientID != nil {
                    warnings.append(
                        FormatWarning(
                            code: "SVG-GRADIENT-DEFERRED",
                            message: "Gradient was exported using its fallback solid fill."))
                }
                let swatches = Dictionary(uniqueKeysWithValues: (document.swatches ?? []).map { ($0.id, $0.color) })
                let fill = (object.style.fillSwatchID.flatMap { swatches[$0] } ?? object.style.fill).map(css) ?? "none"
                let stroke =
                    (object.style.strokeSwatchID.flatMap { swatches[$0] } ?? object.style.stroke).map(css) ?? "none"
                body +=
                    "<path d=\"\(d)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(number(object.style.strokeWidth))\" opacity=\"\(number(object.style.opacity ?? 1))\"/>"
            }
            for text in layer.textObjects ?? [] {
                body +=
                    "<text x=\"\(number(text.origin.x))\" y=\"\(number(text.origin.y))\" font-family=\"\(escape(text.fontName))\" font-size=\"\(number(text.fontSize))\" fill=\"\(css(text.color))\">\(escape(text.text))</text>"
            }
            if !(layer.imageObjects ?? []).isEmpty {
                warnings.append(
                    FormatWarning(code: "SVG-IMAGE-DEFERRED", message: "Raster images are omitted from SVG export."))
            }
            body += "</g>"
        }
        let svg =
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(number(document.width))\" height=\"\(number(document.height))\" viewBox=\"0 0 \(number(document.width)) \(number(document.height))\">\(body)</svg>"
        return ExportResult(data: Data(svg.utf8), warnings: Array(Set(warnings)).sorted { $0.code < $1.code })
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
