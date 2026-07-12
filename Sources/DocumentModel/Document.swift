import EditorCore
import Foundation
import Geometry

public enum LineCap: String, Codable, Sendable { case butt, round, square }
public enum LineJoin: String, Codable, Sendable { case miter, round, bevel }
public enum BlendMode: String, Codable, Sendable { case normal, multiply, screen }
public enum GradientKind: String, Codable, Sendable { case linear, radial }

public enum PixelCountError: Error, Equatable, Sendable { case nonPositive, overflow, budget }
public enum DocumentValidationError: Error, Equatable, Sendable {
    case coordinateMagnitude, artboardMagnitude, layerCount, nodeCount, segmentCount, stringLength, duplicateID,
        danglingResource, invalidGradient, invalidStyle, invalidImage, assetBytes, aggregateAssetBytes,
        assetByteOverflow
}

public enum DocumentLimits {
    public static let maximumCoordinateMagnitude = 1_000_000_000.0
    public static let maximumArtboardDimension = 1_000_000.0
    public static let maximumLayers = 1_024
    public static let maximumNodes = 100_000
    public static let maximumSegments = 1_000_000
    public static let maximumStringUTF8Bytes = 1_000_000
    public static let maximumEmbeddedAssetBytes = 100 * 1_024 * 1_024
    public static let maximumAggregateAssetBytes = 500 * 1_024 * 1_024
    public static let maximumImagePixelCount: Int64 = 67_108_864
    public static let maximumHistoryEstimatedBytes = 512 * 1_024 * 1_024
    public static let minimumHistoryEntriesUnderMemoryPressure = 5
    /// Independent retained-rendering budget; numerically equal to VERIFY-007's
    /// image cap today, but intentionally named separately so policies can diverge.
    public static let maximumRetainedBitmapPixels: Int64 = 67_108_864
    public static func checkedPixelCount(width: Int64, height: Int64) throws -> Int64 {
        guard width > 0, height > 0 else { throw PixelCountError.nonPositive }
        let result = width.multipliedReportingOverflow(by: height)
        guard !result.overflow else { throw PixelCountError.overflow }
        guard result.partialValue <= maximumImagePixelCount else { throw PixelCountError.budget }
        return result.partialValue
    }
    public static func checkedAggregateAssetBytes(current: Int, adding: Int) throws -> Int {
        guard current >= 0, adding >= 0 else { throw DocumentValidationError.assetBytes }
        let result = current.addingReportingOverflow(adding)
        guard !result.overflow else { throw DocumentValidationError.assetByteOverflow }
        guard result.partialValue <= maximumAggregateAssetBytes else {
            throw DocumentValidationError.aggregateAssetBytes
        }
        return result.partialValue
    }
}

public struct ColorStop: Hashable, Codable, Sendable {
    public var offset: Double
    public var color: SRGBColor
    public init(offset: Double, color: SRGBColor) {
        self.offset = offset
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
        self.stops = stops
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
        self.strokeWidth = strokeWidth
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = miterLimit
        self.dash = dash
        self.fillGradientID = fillGradientID
        self.fillSwatchID = fillSwatchID
        self.strokeSwatchID = strokeSwatchID
        self.opacity = opacity
        self.blendMode = blendMode
    }
}

public struct PathObject: Identifiable, Hashable, Codable, Sendable {
    public var id: ObjectID
    public var path: CompoundPath
    public var style: PathStyle
    public var transform: Geometry.AffineTransform
    public init(
        id: ObjectID = ObjectID(), path: CompoundPath, style: PathStyle = PathStyle(),
        transform: Geometry.AffineTransform = .identity
    ) {
        self.id = id
        self.path = path
        self.style = style
        self.transform = transform
    }
    public init(
        id: ObjectID = ObjectID(), segments: [CubicBezier], isClosed: Bool = false, style: PathStyle = PathStyle(),
        transform: Geometry.AffineTransform = .identity
    ) {
        self.init(
            id: id,
            path: CompoundPath(subpaths: [BezierPath(segments: segments, isClosed: isClosed)], fillRule: .nonZero),
            style: style, transform: transform)
    }
    public var segments: [CubicBezier] {
        get { path.subpaths.first?.segments ?? [] }
        set {
            if path.subpaths.isEmpty {
                path.subpaths = [BezierPath(segments: newValue)]
            } else {
                path.subpaths[0].segments = newValue
            }
        }
    }
    public var localBounds: Rect? { path.localBounds }
    public var visualBounds: Rect? {
        guard let localBounds else { return nil }
        let mapped = localBounds.transformed(by: transform)
        guard style.stroke != nil || style.strokeSwatchID != nil else { return mapped }
        let joinFactor = style.lineJoin == .miter ? max(1, style.miterLimit) : 1
        let capFactor = style.lineCap == .square ? sqrt(2) : 1
        return mapped.expanded(by: (style.strokeWidth / 2) * max(joinFactor, capFactor))
    }
}
public struct TextObject: Identifiable, Hashable, Codable, Sendable {
    public var id: ObjectID
    public var text: String
    public var origin: Point
    public var fontName: String
    public var fontSize: Double
    public var color: SRGBColor
    public var transform: Geometry.AffineTransform
    public var layoutBounds: Rect
    public init(
        id: ObjectID = ObjectID(), text: String, origin: Point, fontName: String = "Helvetica", fontSize: Double = 16,
        color: SRGBColor = .black, transform: Geometry.AffineTransform = .identity, layoutBounds: Rect? = nil
    ) {
        self.id = id
        self.text = text
        self.origin = origin
        self.fontName = fontName
        self.fontSize = fontSize
        self.color = color
        self.transform = transform
        self.layoutBounds = layoutBounds ?? Rect(minX: origin.x, minY: origin.y, maxX: origin.x, maxY: origin.y)
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
    public var transform: Geometry.AffineTransform
    public init(
        id: ObjectID = ObjectID(), frame: Rect, storage: ImageStorage, pixelWidth: Int, pixelHeight: Int,
        transform: Geometry.AffineTransform = .identity
    ) {
        self.id = id
        self.frame = frame
        self.storage = storage
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.transform = transform
    }
}
public struct GroupNode: Identifiable, Hashable, Codable, Sendable {
    public var id: ObjectID
    public var name: String
    public var transform: Geometry.AffineTransform
    public var children: [SceneNode]
    public init(
        id: ObjectID = ObjectID(), name: String = "Group", transform: Geometry.AffineTransform = .identity,
        children: [SceneNode]
    ) {
        self.id = id
        self.name = name
        self.transform = transform
        self.children = children
    }
}

public indirect enum SceneNode: Hashable, Codable, Sendable {
    case path(PathObject)
    case text(TextObject)
    case image(ImageObject)
    case group(GroupNode)
    public var id: ObjectID {
        switch self {
        case .path(let x): x.id
        case .text(let x): x.id
        case .image(let x): x.id
        case .group(let x): x.id
        }
    }
    public var localBounds: Rect? {
        switch self {
        case .path(let x): return x.localBounds
        case .text(let x): return x.layoutBounds
        case .image(let x): return x.frame
        case .group(let x): return unionRects(x.children.compactMap(\.visualBounds))
        }
    }
    public var visualBounds: Rect? {
        switch self {
        case .path(let x): return x.visualBounds
        case .text(let x): return x.layoutBounds.transformed(by: x.transform)
        case .image(let x): return x.frame.transformed(by: x.transform)
        case .group(let x):
            guard let union = unionRects(x.children.compactMap(\.visualBounds)) else { return nil }
            return union.transformed(by: x.transform)
        }
    }
    public mutating func translate(dx: Double, dy: Double) {
        switch self {
        case .path(var x):
            x.transform.tx += dx
            x.transform.ty += dy
            self = .path(x)
        case .text(var x):
            x.transform.tx += dx
            x.transform.ty += dy
            self = .text(x)
        case .image(var x):
            x.transform.tx += dx
            x.transform.ty += dy
            self = .image(x)
        case .group(var x):
            x.transform.tx += dx
            x.transform.ty += dy
            self = .group(x)
        }
    }
}

public struct Layer: Identifiable, Hashable, Codable, Sendable {
    public var id: ObjectID
    public var name: String
    public var isVisible: Bool
    public var isLocked: Bool
    public var nodes: [SceneNode]
    public init(
        id: ObjectID = ObjectID(), name: String, isVisible: Bool = true, isLocked: Bool = false, nodes: [SceneNode] = []
    ) {
        self.id = id
        self.name = name
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.nodes = nodes
    }
}
public struct DocumentChange: Hashable, Sendable {
    public var changedObjectIDs: Set<ObjectID>
    public var requiresFullRedraw: Bool
}

public struct EditorDocument: Hashable, Codable, Sendable {
    public static let formatVersion = 4
    public var formatVersion: Int
    public var width: Double
    public var height: Double
    public var unit: MeasurementUnit
    public var layers: [Layer]
    public var swatches: [Swatch]
    public var gradients: [GradientResource]
    public init(
        width: Double, height: Double, unit: MeasurementUnit = .points, layers: [Layer] = [Layer(name: "Layer 1")],
        swatches: [Swatch] = [], gradients: [GradientResource] = []
    ) throws {
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
        guard finite(width), finite(height), width > 0, height > 0, width <= DocumentLimits.maximumArtboardDimension,
            height <= DocumentLimits.maximumArtboardDimension
        else { throw DocumentValidationError.artboardMagnitude }
        guard !layers.isEmpty, layers.count <= DocumentLimits.maximumLayers else {
            throw DocumentValidationError.layerCount
        }
        var ids = Set<ObjectID>()
        var nodeCount = 0
        var segmentCount = 0
        var assetBytes = 0
        let swatchIDs = Set(swatches.map(\.id))
        let gradientIDs = Set(gradients.map(\.id))
        let resourceIDList = swatches.map(\.id) + gradients.map(\.id)
        for id in layers.map(\.id) + resourceIDList {
            guard ids.insert(id).inserted else { throw DocumentValidationError.duplicateID }
        }
        for swatch in swatches {
            try validString(swatch.name)
            try validColor(swatch.color)
        }
        for gradient in gradients {
            try validString(gradient.name)
            guard gradient.stops.count >= 2, finite(gradient.start), finite(gradient.end) else {
                throw DocumentValidationError.invalidGradient
            }
            var prior = -Double.infinity
            for stop in gradient.stops {
                guard stop.offset.isFinite, stop.offset >= 0, stop.offset <= 1, stop.offset >= prior else {
                    throw DocumentValidationError.invalidGradient
                }
                prior = stop.offset
                try validColor(stop.color)
            }
        }
        func visit(_ node: SceneNode) throws {
            nodeCount += 1
            guard nodeCount <= DocumentLimits.maximumNodes, ids.insert(node.id).inserted else {
                throw nodeCount > DocumentLimits.maximumNodes ? DocumentValidationError.nodeCount : .duplicateID
            }
            switch node {
            case .path(let x):
                try validTransform(x.transform)
                try validStyle(x.style, swatchIDs: swatchIDs, gradientIDs: gradientIDs)
                for subpath in x.path.subpaths {
                    segmentCount += subpath.segments.count
                    guard segmentCount <= DocumentLimits.maximumSegments else {
                        throw DocumentValidationError.segmentCount
                    }
                    for segment in subpath.segments {
                        for point in [segment.start, segment.control1, segment.control2, segment.end] {
                            guard finite(point) else { throw DocumentValidationError.coordinateMagnitude }
                        }
                    }
                }
            case .text(let x):
                try validString(x.text)
                try validString(x.fontName)
                guard x.fontSize.isFinite, x.fontSize > 0, finite(x.origin), finite(x.layoutBounds) else {
                    throw DocumentValidationError.coordinateMagnitude
                }
                try validColor(x.color)
                try validTransform(x.transform)
            case .image(let x):
                try validTransform(x.transform)
                guard finite(x.frame), x.frame.width > 0, x.frame.height > 0 else {
                    throw DocumentValidationError.invalidImage
                }
                do {
                    _ = try DocumentLimits.checkedPixelCount(width: Int64(x.pixelWidth), height: Int64(x.pixelHeight))
                } catch { throw DocumentValidationError.invalidImage }
                if case .embedded(let data) = x.storage {
                    guard data.count <= DocumentLimits.maximumEmbeddedAssetBytes, isSupportedImageHeader(data) else {
                        throw DocumentValidationError.invalidImage
                    }
                    assetBytes = try DocumentLimits.checkedAggregateAssetBytes(current: assetBytes, adding: data.count)
                }
            case .group(let x):
                try validString(x.name)
                try validTransform(x.transform)
                for child in x.children { try visit(child) }
            }
        }
        for layer in layers {
            try validString(layer.name)
            for node in layer.nodes { try visit(node) }
        }
    }
    public func visualBounds(for id: ObjectID) -> Rect? {
        for layer in layers {
            for node in layer.nodes {
                if let bounds = node.visualBounds(for: id, parentTransform: .identity) { return bounds }
            }
        }
        return nil
    }
    @discardableResult public mutating func translateNode(id: ObjectID, documentDX: Double, documentDY: Double) -> Bool
    {
        for layerIndex in layers.indices {
            if translateNodeRecursive(
                in: &layers[layerIndex].nodes, id: id, documentDX: documentDX, documentDY: documentDY,
                parentTransform: .identity)
            {
                return true
            }
        }
        return false
    }
    @discardableResult public mutating func mutatePath(id: ObjectID, _ mutation: (inout PathObject) -> Void) -> Bool {
        for layerIndex in layers.indices {
            if mutatePathRecursive(in: &layers[layerIndex].nodes, id: id, mutation) { return true }
        }
        return false
    }
    @discardableResult public mutating func movePathAnchor(
        id: ObjectID, subpath: Int, segment: Int, documentDelta: Point
    ) -> Bool {
        for layerIndex in layers.indices {
            if movePathAnchorRecursive(
                in: &layers[layerIndex].nodes, id: id, subpath: subpath,
                segment: segment, documentDelta: documentDelta, parentTransform: .identity)
            {
                return true
            }
        }
        return false
    }
    public static func sample() throws -> EditorDocument {
        let curve = CubicBezier(
            start: Point(x: 80, y: 250), control1: Point(x: 180, y: 40), control2: Point(x: 350, y: 440),
            end: Point(x: 500, y: 180))
        return try EditorDocument(
            width: 640, height: 480,
            layers: [
                Layer(
                    name: "Curves",
                    nodes: [
                        .path(
                            PathObject(
                                segments: [curve],
                                style: PathStyle(stroke: SRGBColor(red: 0.12, green: 0.36, blue: 0.86), strokeWidth: 4))
                        )
                    ])
            ])
    }
}

extension SceneNode {
    fileprivate func visualBounds(for id: ObjectID, parentTransform: Geometry.AffineTransform) -> Rect? {
        if self.id == id { return visualBounds?.transformed(by: parentTransform) }
        guard case .group(let group) = self else { return nil }
        let childParent = group.transform.concatenating(parentTransform)
        for child in group.children {
            if let bounds = child.visualBounds(for: id, parentTransform: childParent) { return bounds }
        }
        return nil
    }
}

private func translateNodeRecursive(
    in nodes: inout [SceneNode], id: ObjectID, documentDX: Double, documentDY: Double,
    parentTransform: Geometry.AffineTransform
) -> Bool {
    for index in nodes.indices {
        if nodes[index].id == id {
            guard let inverse = parentTransform.inverted() else { return false }
            let localDX = inverse.a * documentDX + inverse.c * documentDY
            let localDY = inverse.b * documentDX + inverse.d * documentDY
            nodes[index].translate(dx: localDX, dy: localDY)
            return true
        }
        if case .group(var group) = nodes[index] {
            let childParent = group.transform.concatenating(parentTransform)
            if translateNodeRecursive(
                in: &group.children, id: id, documentDX: documentDX, documentDY: documentDY,
                parentTransform: childParent)
            {
                nodes[index] = .group(group)
                return true
            }
        }
    }
    return false
}
private func mutatePathRecursive(in nodes: inout [SceneNode], id: ObjectID, _ mutation: (inout PathObject) -> Void)
    -> Bool
{
    for index in nodes.indices {
        switch nodes[index] {
        case .path(var path) where path.id == id:
            mutation(&path)
            nodes[index] = .path(path)
            return true
        case .group(var group):
            if mutatePathRecursive(in: &group.children, id: id, mutation) {
                nodes[index] = .group(group)
                return true
            }
        default: break
        }
    }
    return false
}
private func movePathAnchorRecursive(
    in nodes: inout [SceneNode], id: ObjectID, subpath: Int, segment: Int,
    documentDelta: Point, parentTransform: Geometry.AffineTransform
) -> Bool {
    for index in nodes.indices {
        switch nodes[index] {
        case .path(var path) where path.id == id:
            guard path.path.subpaths.indices.contains(subpath),
                path.path.subpaths[subpath].segments.indices.contains(segment),
                let inverse = path.transform.concatenating(parentTransform).inverted()
            else { return false }
            let delta = Point(
                x: inverse.a * documentDelta.x + inverse.c * documentDelta.y,
                y: inverse.b * documentDelta.x + inverse.d * documentDelta.y)
            var item = path.path.subpaths[subpath].segments[segment]
            item.start = Point(x: item.start.x + delta.x, y: item.start.y + delta.y)
            item.control1 = Point(x: item.control1.x + delta.x, y: item.control1.y + delta.y)
            path.path.subpaths[subpath].segments[segment] = item
            if segment > 0 { path.path.subpaths[subpath].segments[segment - 1].end = item.start }
            nodes[index] = .path(path)
            return true
        case .group(var group):
            let accumulated = group.transform.concatenating(parentTransform)
            if movePathAnchorRecursive(
                in: &group.children, id: id, subpath: subpath, segment: segment,
                documentDelta: documentDelta, parentTransform: accumulated)
            {
                nodes[index] = .group(group)
                return true
            }
        default: break
        }
    }
    return false
}

private func finite(_ value: Double) -> Bool {
    value.isFinite && abs(value) <= DocumentLimits.maximumCoordinateMagnitude
}
private func finite(_ point: Point) -> Bool { finite(point.x) && finite(point.y) }
private func finite(_ rect: Rect) -> Bool {
    finite(rect.minX) && finite(rect.minY) && finite(rect.maxX) && finite(rect.maxY)
}
private func validTransform(_ x: Geometry.AffineTransform) throws {
    for value in [x.a, x.b, x.c, x.d, x.tx, x.ty] {
        guard finite(value) else { throw DocumentValidationError.coordinateMagnitude }
    }
}
private func validString(_ value: String) throws {
    guard value.utf8.count <= DocumentLimits.maximumStringUTF8Bytes else { throw DocumentValidationError.stringLength }
}
private func validColor(_ color: SRGBColor) throws {
    for value in [color.red, color.green, color.blue, color.alpha] {
        guard value.isFinite, value >= 0, value <= 1 else { throw DocumentValidationError.invalidStyle }
    }
}
private func validStyle(_ style: PathStyle, swatchIDs: Set<ObjectID>, gradientIDs: Set<ObjectID>) throws {
    guard style.strokeWidth.isFinite, style.strokeWidth >= 0, style.miterLimit.isFinite, style.miterLimit >= 1,
        let opacity = style.opacity, opacity.isFinite, opacity >= 0, opacity <= 1,
        style.dash.allSatisfy({ $0.isFinite && $0 >= 0 }), style.dash.isEmpty || style.dash.contains(where: { $0 > 0 })
    else { throw DocumentValidationError.invalidStyle }
    if let color = style.fill { try validColor(color) }
    if let color = style.stroke { try validColor(color) }
    if let reference = style.fillGradientID {
        guard gradientIDs.contains(reference) else { throw DocumentValidationError.danglingResource }
    }
    for reference in [style.fillSwatchID, style.strokeSwatchID].compactMap({ $0 }) {
        guard swatchIDs.contains(reference) else { throw DocumentValidationError.danglingResource }
    }
}
private func isSupportedImageHeader(_ data: Data) -> Bool {
    let bytes = [UInt8](data.prefix(8))
    return bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        || bytes.starts(with: [0xFF, 0xD8, 0xFF])
}
private func unionRects(_ rects: [Rect]) -> Rect? {
    guard let first = rects.first else { return nil }
    return rects.dropFirst().reduce(first) { $0.union($1) }
}
