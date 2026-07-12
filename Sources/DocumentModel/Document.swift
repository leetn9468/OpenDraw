import EditorCore
import Foundation
import Geometry

public enum LineCap: String, Codable, Sendable { case butt, round, square }
public enum LineJoin: String, Codable, Sendable { case miter, round, bevel }
public enum BlendMode: String, Codable, Sendable { case normal, multiply, screen }
public enum GradientKind: String, Codable, Sendable { case linear, radial }

public struct ColorStop: Hashable, Codable, Sendable {
    public var offset: Double
    public var color: SRGBColor
    public init(offset: Double, color: SRGBColor) {
        self.offset = min(max(offset, 0), 1)
        self.color = color
    }
}
public struct GradientResource: Identifiable, Hashable, Codable, Sendable {
    public var id: ObjectID
    public var name: String
    public var kind: GradientKind
    public var start: Point
    public var end: Point
    public var stops: [ColorStop]
    public init(
        id: ObjectID = ObjectID(), name: String, kind: GradientKind, start: Point, end: Point, stops: [ColorStop]
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.start = start
        self.end = end
        self.stops = stops.sorted { $0.offset < $1.offset }
    }
}
public struct Swatch: Identifiable, Hashable, Codable, Sendable {
    public var id: ObjectID
    public var name: String
    public var color: SRGBColor
    public init(id: ObjectID = ObjectID(), name: String, color: SRGBColor) {
        self.id = id
        self.name = name
        self.color = color
    }
}

public struct PathStyle: Hashable, Codable, Sendable {
    public var fill: SRGBColor?
    public var stroke: SRGBColor?
    public var strokeWidth: Double
    public var lineCap: LineCap
    public var lineJoin: LineJoin
    public var miterLimit: Double
    public var dash: [Double]
    public var fillGradientID: ObjectID?
    public var fillSwatchID: ObjectID?
    public var strokeSwatchID: ObjectID?
    public var opacity: Double?
    public var blendMode: BlendMode?
    public init(
        fill: SRGBColor? = nil, stroke: SRGBColor? = .black, strokeWidth: Double = 1, lineCap: LineCap = .butt,
        lineJoin: LineJoin = .miter, miterLimit: Double = 10, dash: [Double] = [], fillGradientID: ObjectID? = nil,
        fillSwatchID: ObjectID? = nil, strokeSwatchID: ObjectID? = nil, opacity: Double = 1,
        blendMode: BlendMode = .normal
    ) {
        self.fill = fill
        self.stroke = stroke
        self.strokeWidth = max(0, strokeWidth)
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = max(1, miterLimit)
        self.dash = dash.map { max(0, $0) }
        self.fillGradientID = fillGradientID
        self.fillSwatchID = fillSwatchID
        self.strokeSwatchID = strokeSwatchID
        self.opacity = min(max(opacity, 0), 1)
        self.blendMode = blendMode
    }
}

public struct PathObject: Identifiable, Hashable, Codable, Sendable {
    public var id: ObjectID
    public var path: BezierPath
    public var style: PathStyle
    public var transform: Geometry.AffineTransform
    public init(
        id: ObjectID = ObjectID(), segments: [CubicBezier], isClosed: Bool = false, style: PathStyle = PathStyle(),
        transform: Geometry.AffineTransform = .identity
    ) {
        self.id = id
        path = BezierPath(segments: segments, isClosed: isClosed)
        self.style = style
        self.transform = transform
    }
    public var segments: [CubicBezier] {
        get { path.segments }
        set { path.segments = newValue }
    }
    public var bounds: Rect? { path.bounds }
}
public struct TextObject: Identifiable, Hashable, Codable, Sendable {
    public var id: ObjectID
    public var text: String
    public var origin: Point
    public var fontName: String
    public var fontSize: Double
    public var color: SRGBColor
    public var transform: Geometry.AffineTransform
    public init(
        id: ObjectID = ObjectID(), text: String, origin: Point, fontName: String = "Helvetica", fontSize: Double = 16,
        color: SRGBColor = .black, transform: Geometry.AffineTransform = .identity
    ) {
        self.id = id
        self.text = text
        self.origin = origin
        self.fontName = fontName
        self.fontSize = fontSize
        self.color = color
        self.transform = transform
    }
}
public enum ImageStorage: Hashable, Codable, Sendable {
    case embedded(Data)
    case linked(relativePath: String)
}
public struct ImageObject: Identifiable, Hashable, Codable, Sendable {
    public var id: ObjectID
    public var frame: Rect
    public var storage: ImageStorage
    public var pixelWidth: Int
    public var pixelHeight: Int
    public init(id: ObjectID = ObjectID(), frame: Rect, storage: ImageStorage, pixelWidth: Int, pixelHeight: Int) {
        self.id = id
        self.frame = frame
        self.storage = storage
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

public struct Layer: Identifiable, Hashable, Codable, Sendable {
    public var id: ObjectID
    public var name: String
    public var isVisible: Bool
    public var isLocked: Bool
    public var paths: [PathObject]
    public var textObjects: [TextObject]?
    public var imageObjects: [ImageObject]?
    public init(
        id: ObjectID = ObjectID(), name: String, isVisible: Bool = true, isLocked: Bool = false,
        paths: [PathObject] = [], textObjects: [TextObject]? = nil, imageObjects: [ImageObject]? = nil
    ) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.paths = paths
        self.textObjects = textObjects
        self.imageObjects = imageObjects
    }
}
public struct DocumentChange: Hashable, Sendable {
    public var changedObjectIDs: Set<ObjectID>
    public var requiresFullRedraw: Bool
}

public struct EditorDocument: Hashable, Codable, Sendable {
    public static let formatVersion = 3
    public var formatVersion: Int
    public var width: Double
    public var height: Double
    public var unit: MeasurementUnit
    public var layers: [Layer]
    public var swatches: [Swatch]?
    public var gradients: [GradientResource]?
    public init(
        width: Double, height: Double, unit: MeasurementUnit = .points, layers: [Layer] = [Layer(name: "Layer 1")],
        swatches: [Swatch]? = nil, gradients: [GradientResource]? = nil
    ) throws {
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            throw EditorError.invalidValue("Document dimensions must be positive and finite")
        }
        guard !layers.isEmpty else { throw EditorError.invariantViolation("A document requires one layer") }
        formatVersion = Self.formatVersion
        self.width = width
        self.height = height
        self.unit = unit
        self.layers = layers
        self.swatches = swatches
        self.gradients = gradients
        try validate()
    }
    public func validate() throws {
        guard width.isFinite, height.isFinite, width > 0, height > 0, !layers.isEmpty else {
            throw EditorError.invariantViolation("Invalid document")
        }
        let objects = layers.flatMap(\.paths)
        let objectIDs = objects.map(\.id)
        guard Set(objectIDs).count == objectIDs.count else {
            throw EditorError.invariantViolation("Duplicate object ID")
        }
        for object in objects {
            guard object.style.strokeWidth.isFinite, object.style.strokeWidth >= 0, (object.style.opacity ?? 1).isFinite
            else { throw EditorError.invariantViolation("Invalid style") }
        }
        let resourceIDs = (swatches ?? []).map(\.id) + (gradients ?? []).map(\.id)
        guard Set(resourceIDs).count == resourceIDs.count else {
            throw EditorError.invariantViolation("Duplicate resource ID")
        }
        for layer in layers {
            for text in layer.textObjects ?? [] {
                guard text.fontSize.isFinite, text.fontSize > 0 else {
                    throw EditorError.invariantViolation("Invalid text")
                }
            }
            for image in layer.imageObjects ?? [] {
                guard image.pixelWidth > 0, image.pixelHeight > 0, image.frame.width > 0, image.frame.height > 0 else {
                    throw EditorError.invariantViolation("Invalid image")
                }
            }
        }
    }
    public static func sample() -> EditorDocument {
        let curve = CubicBezier(
            start: Point(x: 80, y: 250), control1: Point(x: 180, y: 40), control2: Point(x: 350, y: 440),
            end: Point(x: 500, y: 180))
        return try! EditorDocument(
            width: 640, height: 480,
            layers: [
                Layer(
                    name: "Curves",
                    paths: [
                        PathObject(
                            segments: [curve],
                            style: PathStyle(stroke: SRGBColor(red: 0.12, green: 0.36, blue: 0.86), strokeWidth: 4))
                    ])
            ])
    }
}
