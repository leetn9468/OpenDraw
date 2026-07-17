import CoreGraphics
import DocumentModel
import EditorCore
import Foundation
import Geometry
import TextEngine

public struct RenderViewport: Sendable {
    public var zoom: Double
    public var pan: Point
    public var clip: Rect?
    public init(zoom: Double = 1, pan: Point = Point(x: 0, y: 0), clip: Rect? = nil) {
        self.zoom = zoom
        self.pan = pan
        self.clip = clip
    }
}
public typealias DamageRegion = DocumentDamage

public struct CoreGraphicsRenderer: Sendable {
    public init() {}
    public func render(
        _ document: EditorDocument, in context: CGContext, scale: Double = 1, approvedImages: [ObjectID: CGImage] = [:]
    ) {
        render(document, in: context, viewport: RenderViewport(zoom: scale), approvedImages: approvedImages)
    }
    public func render(
        _ document: EditorDocument, in context: CGContext, viewport: RenderViewport,
        approvedImages: [ObjectID: CGImage] = [:]
    ) {
        context.saveGState()
        defer { context.restoreGState() }
        if let clip = viewport.clip {
            context.clip(to: CGRect(x: clip.minX, y: clip.minY, width: clip.width, height: clip.height))
        }
        context.translateBy(x: viewport.pan.x, y: viewport.pan.y)
        context.scaleBy(x: viewport.zoom, y: viewport.zoom)
        let swatches = Dictionary(uniqueKeysWithValues: document.swatches.map { ($0.id, $0.color) })
        let gradients = Dictionary(uniqueKeysWithValues: document.gradients.map { ($0.id, $0) })
        let visibleDocumentRect = viewport.clip.map {
            Rect(
                minX: ($0.minX - viewport.pan.x) / viewport.zoom,
                minY: ($0.minY - viewport.pan.y) / viewport.zoom,
                maxX: ($0.maxX - viewport.pan.x) / viewport.zoom,
                maxY: ($0.maxY - viewport.pan.y) / viewport.zoom)
        }
        for layer in document.layers where layer.isVisible {
            for node in layer.nodes
            where visibleDocumentRect.map({ node.visualBounds?.intersects($0) ?? false }) ?? true {
                render(node, swatches: swatches, gradients: gradients, approvedImages: approvedImages, in: context)
            }
        }
    }
    public func renderSelection(_ object: PathObject, in context: CGContext, zoom: Double) {
        // Selection overlays use visual bounds because they describe rendered ink.
        guard let b = object.visualBounds else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.setStrokeColor(CGColor(srgbRed: 0.1, green: 0.45, blue: 1, alpha: 1))
        context.setLineWidth(1 / zoom)
        context.stroke(CGRect(x: b.minX, y: b.minY, width: b.width, height: b.height))
        for s in object.segments {
            for p in [s.start, s.end] {
                context.fill(CGRect(x: p.x - 3 / zoom, y: p.y - 3 / zoom, width: 6 / zoom, height: 6 / zoom))
            }
        }
    }
    private func append(_ object: PathObject, to context: CGContext) {
        context.beginPath()
        for subpath in object.path.subpaths {
            guard let first = subpath.segments.first else { continue }
            context.move(to: object.transform.applying(to: first.start).cg)
            for s in subpath.segments {
                context.addCurve(
                    to: object.transform.applying(to: s.end).cg, control1: object.transform.applying(to: s.control1).cg,
                    control2: object.transform.applying(to: s.control2).cg)
            }
            if subpath.isClosed { context.closePath() }
        }
    }
    private func render(
        _ node: SceneNode, swatches: [ObjectID: SRGBColor], gradients: [ObjectID: GradientResource],
        approvedImages: [ObjectID: CGImage],
        in context: CGContext
    ) {
        switch node {
        case .path(let path): render(path, swatches: swatches, gradients: gradients, in: context)
        case .text(let text): render(text, in: context)
        case .image(let image): render(image, approvedImage: approvedImages[image.id], in: context)
        case .group(let group):
            context.saveGState()
            context.concatenate(
                CGAffineTransform(
                    a: group.transform.a, b: group.transform.b, c: group.transform.c, d: group.transform.d,
                    tx: group.transform.tx, ty: group.transform.ty))
            for child in group.children {
                render(child, swatches: swatches, gradients: gradients, approvedImages: approvedImages, in: context)
            }
            context.restoreGState()
        }
    }
    private func render(
        _ object: PathObject, swatches: [ObjectID: SRGBColor], gradients: [ObjectID: GradientResource],
        in context: CGContext
    ) {
        context.saveGState()
        defer { context.restoreGState() }
        context.setAlpha(object.style.opacity ?? 1)
        context.setBlendMode((object.style.blendMode ?? .normal).cg)
        append(object, to: context)
        if let id = object.style.fillGradientID, let gradient = gradients[id], let cg = gradient.cgGradient {
            context.saveGState()
            context.clip(using: object.path.fillRule == .evenOdd ? .evenOdd : .winding)
            if gradient.kind == .linear {
                context.drawLinearGradient(
                    cg, start: object.transform.applying(to: gradient.start).cg,
                    end: object.transform.applying(to: gradient.end).cg, options: [])
            } else {
                context.drawRadialGradient(
                    cg, startCenter: object.transform.applying(to: gradient.start).cg, startRadius: 0,
                    endCenter: object.transform.applying(to: gradient.end).cg,
                    endRadius: gradient.start.distance(to: gradient.end), options: [])
            }
            context.restoreGState()
        } else if let fill = object.style.fillSwatchID.flatMap({ swatches[$0] }) ?? object.style.fill {
            context.setFillColor(fill.cgColor)
            context.drawPath(using: object.path.fillRule == .evenOdd ? .eoFill : .fill)
        }
        if let stroke = object.style.strokeSwatchID.flatMap({ swatches[$0] }) ?? object.style.stroke {
            append(object, to: context)
            context.setStrokeColor(stroke.cgColor)
            context.setLineWidth(object.style.strokeWidth)
            context.setLineCap(object.style.lineCap.cg)
            context.setLineJoin(object.style.lineJoin.cg)
            context.setMiterLimit(object.style.miterLimit)
            context.setLineDash(phase: 0, lengths: object.style.dash.map { CGFloat($0) })
            context.strokePath()
        }
    }
    private func render(_ text: TextObject, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.concatenate(
            CGAffineTransform(
                a: text.transform.a, b: text.transform.b, c: text.transform.c, d: text.transform.d,
                tx: text.transform.tx, ty: text.transform.ty))
        do {
            try TextShaper().draw(
                text.text, fontName: text.fontName, size: text.fontSize, at: text.origin, color: text.color.cgColor,
                in: context)
        } catch {
            Diagnostics.rendering.error("Text draw failed: \(String(describing: error), privacy: .public)")
            context.setStrokeColor(CGColor(gray: 0.5, alpha: 1))
            context.stroke(
                CGRect(x: text.origin.x, y: text.origin.y - text.fontSize, width: text.fontSize, height: text.fontSize))
        }
    }
    private func render(_ image: ImageObject, approvedImage: CGImage?, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        context.concatenate(
            CGAffineTransform(
                a: image.transform.a, b: image.transform.b, c: image.transform.c, d: image.transform.d,
                tx: image.transform.tx, ty: image.transform.ty))
        let frame = CGRect(
            x: image.frame.minX, y: image.frame.minY, width: image.frame.width, height: image.frame.height)
        if let cg = approvedImage {
            context.draw(cg, in: frame)
        } else {
            placeholder(frame, in: context)
        }
    }
    private func placeholder(_ frame: CGRect, in context: CGContext) {
        context.setStrokeColor(CGColor(gray: 0.5, alpha: 1))
        context.stroke(frame)
        context.move(to: frame.origin)
        context.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
        context.move(to: CGPoint(x: frame.maxX, y: frame.minY))
        context.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
        context.strokePath()
    }
}

extension Geometry.Rect {
    fileprivate func intersects(_ other: Geometry.Rect) -> Bool {
        maxX >= other.minX && other.maxX >= minX && maxY >= other.minY && other.maxY >= minY
    }
}
extension SRGBColor {
    fileprivate var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }
}
extension Point { fileprivate var cg: CGPoint { CGPoint(x: x, y: y) } }
extension LineCap {
    fileprivate var cg: CGLineCap {
        switch self {
        case .butt: .butt
        case .round: .round
        case .square: .square
        }
    }
}
extension LineJoin {
    fileprivate var cg: CGLineJoin {
        switch self {
        case .miter: .miter
        case .round: .round
        case .bevel: .bevel
        }
    }
}
extension BlendMode {
    fileprivate var cg: CGBlendMode {
        switch self {
        case .normal: .normal
        case .multiply: .multiply
        case .screen: .screen
        }
    }
}
extension GradientResource {
    fileprivate var cgGradient: CGGradient? {
        guard stops.count >= 2 else { return nil }
        return CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: stops.map { $0.color.cgColor } as CFArray,
            locations: stops.map { CGFloat($0.offset) })
    }
}
