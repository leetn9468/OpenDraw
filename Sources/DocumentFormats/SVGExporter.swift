import DocumentModel
import EditorCore
import Foundation
import Geometry

public struct FormatWarning: Hashable, Sendable {
    public var code: String
    public var message: String
    public var objectID: ObjectID?
    public var nodeType: String?
    public var property: String?
    public var reason: String?
    public var occurrenceCount: Int
    public var layerName: String?
    public var layerIndex: Int?
    public var nodeIndex: Int?
    public var line: Int?
    public var column: Int?
    public init(
        code: String, message: String, objectID: ObjectID? = nil, nodeType: String? = nil,
        property: String? = nil, reason: String? = nil, occurrenceCount: Int = 1,
        layerName: String? = nil, layerIndex: Int? = nil, nodeIndex: Int? = nil,
        line: Int? = nil, column: Int? = nil
    ) {
        self.code = code
        self.message = message
        self.objectID = objectID
        self.nodeType = nodeType
        self.property = property
        self.reason = reason
        self.occurrenceCount = occurrenceCount
        self.layerName = layerName
        self.layerIndex = layerIndex
        self.nodeIndex = nodeIndex
        self.line = line
        self.column = column
    }
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
        let gradients = Dictionary(uniqueKeysWithValues: document.gradients.map { ($0.id, $0) })
        let defs = document.gradients.map(exportGradient).joined()
        for (layerIndex, layer) in document.layers.enumerated() where layer.isVisible {
            body += "<g id=\"\(escape(layer.name))\">"
            for (nodeIndex, node) in layer.nodes.enumerated() {
                body += export(
                    node, swatches: swatches, gradients: gradients, warnings: &warnings,
                    layer: layer, layerIndex: layerIndex, nodeIndex: nodeIndex)
            }
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
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(number(document.width))\" height=\"\(number(document.height))\" viewBox=\"\(number(viewBox.minX)) \(number(viewBox.minY)) \(number(viewBox.width)) \(number(viewBox.height))\"><defs>\(defs)</defs>\(body)</svg>"
        return ExportResult(data: Data(svg.utf8), warnings: warnings)
    }
    private func export(
        _ node: SceneNode, swatches: [ObjectID: SRGBColor], gradients: [ObjectID: GradientResource],
        warnings: inout [FormatWarning], layer: Layer, layerIndex: Int, nodeIndex: Int
    ) -> String {
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
            let fill =
                object.style.fillGradientID.flatMap { gradients[$0] }.map { "url(#g\($0.id.rawValue.uuidString))" }
                ?? (object.style.fillSwatchID.flatMap { swatches[$0] } ?? object.style.fill).map(css) ?? "none"
            let stroke =
                (object.style.strokeSwatchID.flatMap { swatches[$0] } ?? object.style.stroke).map(css) ?? "none"
            let fillAlpha = object.style.fillSwatchID.flatMap { swatches[$0] }?.alpha ?? object.style.fill?.alpha ?? 1
            let strokeAlpha =
                object.style.strokeSwatchID.flatMap { swatches[$0] }?.alpha ?? object.style.stroke?.alpha ?? 1
            return
                "<path d=\"\(d)\" fill=\"\(fill)\" fill-opacity=\"\(number(fillAlpha))\" fill-rule=\"\(object.path.fillRule == .evenOdd ? "evenodd":"nonzero")\" stroke=\"\(stroke)\" stroke-opacity=\"\(number(strokeAlpha))\" stroke-width=\"\(number(object.style.strokeWidth))\" stroke-linecap=\"\(object.style.lineCap.rawValue)\" stroke-linejoin=\"\(object.style.lineJoin.rawValue)\" stroke-miterlimit=\"\(number(object.style.miterLimit))\" stroke-dasharray=\"\(object.style.dash.isEmpty ? "none" : object.style.dash.map(number).joined(separator: " "))\" opacity=\"\(number(object.style.opacity ?? 1))\" style=\"mix-blend-mode:\((object.style.blendMode ?? .normal).rawValue)\" transform=\"\(matrix(object.transform))\"/>"
        case .text(let text):
            return
                "<text x=\"\(number(text.origin.x))\" y=\"\(number(text.origin.y))\" font-family=\"\(escape(text.fontName))\" font-size=\"\(number(text.fontSize))\" fill=\"\(css(text.color))\" transform=\"\(matrix(text.transform))\">\(escape(text.text))</text>"
        case .image(let image):
            warnings.append(
                FormatWarning(
                    code: "SVG-IMAGE-OMITTED", message: "Raster image was omitted from SVG export.",
                    objectID: image.id, nodeType: "image", property: "storage",
                    reason: "Raster embedding is not supported", layerName: layer.name,
                    layerIndex: layerIndex, nodeIndex: nodeIndex))
            return ""
        case .group(let group):
            return
                "<g transform=\"\(matrix(group.transform))\">\(group.children.enumerated().map{export($0.element,swatches:swatches,gradients:gradients,warnings:&warnings,layer:layer,layerIndex:layerIndex,nodeIndex:$0.offset)}.joined())</g>"
        }
    }
    private func exportGradient(_ gradient: GradientResource) -> String {
        let tag = gradient.kind == .linear ? "linearGradient" : "radialGradient"
        let geometry =
            gradient.kind == .linear
            ? "x1=\"\(number(gradient.start.x))\" y1=\"\(number(gradient.start.y))\" x2=\"\(number(gradient.end.x))\" y2=\"\(number(gradient.end.y))\""
            : "cx=\"\(number(gradient.start.x))\" cy=\"\(number(gradient.start.y))\" r=\"\(number(hypot(gradient.end.x-gradient.start.x,gradient.end.y-gradient.start.y)))\""
        let stops = gradient.stops.map {
            "<stop offset=\"\(number($0.offset * 100))%\" stop-color=\"\(css($0.color))\" stop-opacity=\"\(number($0.color.alpha))\"/>"
        }.joined()
        return
            "<\(tag) id=\"g\(gradient.id.rawValue.uuidString)\" gradientUnits=\"userSpaceOnUse\" \(geometry)>\(stops)</\(tag)>"
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
