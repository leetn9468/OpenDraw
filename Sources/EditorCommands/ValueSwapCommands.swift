import DocumentModel
import EditorCore
import Foundation
import Geometry

public enum ValueSwapCommandError: Error, Equatable, Sendable {
    case nodeNotFound
    case wrongNodeKind
    case layerNotFound
}

public enum ValueSwapNodeProperty: Hashable, Codable, Sendable {
    case groupName(String)
    case textOrigin(Point)
    case textFontName(String)
    case textFontSize(Double)
    case textColor(SRGBColor)
    case imageFrame(Rect)
}

public struct LayerVisibilityAndLock: Hashable, Codable, Sendable {
    public var isVisible: Bool
    public var isLocked: Bool

    public init(isVisible: Bool, isLocked: Bool) {
        self.isVisible = isVisible
        self.isLocked = isLocked
    }
}

public struct ArtboardProperties: Hashable, Codable, Sendable {
    public var width: Double
    public var height: Double
    public var unit: MeasurementUnit

    public init(width: Double, height: Double, unit: MeasurementUnit) {
        self.width = width
        self.height = height
        self.unit = unit
    }
}

public enum ValueSwapCommands {
    public static func transform(
        in document: EditorDocument, nodeID: ObjectID, newValue: Geometry.AffineTransform,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        guard let context = nodeContext(in: document.layers, nodeID: nodeID) else {
            throw ValueSwapCommandError.nodeNotFound
        }
        let oldValue = nodeTransform(of: context.node)
        return try transform(
            in: document, nodeID: nodeID, oldValue: oldValue, newValue: newValue,
            commandID: commandID, timestamp: timestamp)
    }

    /// Explicit stored-value form used when a gesture has already rendered its
    /// post-state. Both values are captured data; inverse never uses matrix
    /// inversion or derives the old transform from the current document.
    public static func transform(
        in document: EditorDocument, nodeID: ObjectID,
        oldValue: Geometry.AffineTransform, newValue: Geometry.AffineTransform,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        guard let context = nodeContext(in: document.layers, nodeID: nodeID) else {
            throw ValueSwapCommandError.nodeNotFound
        }
        var originalNode = context.node
        _ = setTransform(oldValue, on: &originalNode)
        var changedNode = context.node
        _ = setTransform(newValue, on: &changedNode)
        return try nodeCommand(
            name: "Transform", before: documentBounds(of: originalNode, parent: context.parent),
            after: documentBounds(of: changedNode, parent: context.parent), commandID: commandID,
            timestamp: timestamp, oldValue: oldValue, newValue: newValue,
            validation: { document, value in
                try validateTransform(value)
                guard nodeContext(in: document.layers, nodeID: nodeID) != nil else {
                    throw ValueSwapCommandError.nodeNotFound
                }
            },
            mutation: { document, value in
                mutateNode(in: &document.layers, nodeID: nodeID, mutation: { setTransform(value, on: &$0) })
            })
    }

    public static func pathStyle(
        in document: EditorDocument, nodeID: ObjectID, newValue: PathStyle,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        guard let context = nodeContext(in: document.layers, nodeID: nodeID) else {
            throw ValueSwapCommandError.nodeNotFound
        }
        guard case .path(let path) = context.node else { throw ValueSwapCommandError.wrongNodeKind }
        var changedPath = path
        changedPath.style = newValue
        return try nodeCommand(
            name: "Style", before: documentBounds(of: context.node, parent: context.parent),
            after: documentBounds(of: .path(changedPath), parent: context.parent), commandID: commandID,
            timestamp: timestamp, oldValue: path.style, newValue: newValue,
            validation: { document, value in
                try validateStyle(value, in: document)
                guard case .path? = node(in: document.layers, nodeID: nodeID) else {
                    throw ValueSwapCommandError.wrongNodeKind
                }
            },
            mutation: { document, value in
                mutateNode(
                    in: &document.layers, nodeID: nodeID,
                    mutation: {
                        guard case .path(var path) = $0 else { return false }
                        path.style = value
                        $0 = .path(path)
                        return true
                    })
            })
    }

    public static func nodeProperty(
        in document: EditorDocument, nodeID: ObjectID, newValue: ValueSwapNodeProperty,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        guard let context = nodeContext(in: document.layers, nodeID: nodeID) else {
            throw ValueSwapCommandError.nodeNotFound
        }
        let oldValue = try propertyValue(for: context.node, matching: newValue)
        var changedNode = context.node
        _ = try setProperty(newValue, on: &changedNode)
        return try nodeCommand(
            name: "Property", before: documentBounds(of: context.node, parent: context.parent),
            after: documentBounds(of: changedNode, parent: context.parent), commandID: commandID,
            timestamp: timestamp, oldValue: oldValue, newValue: newValue,
            validation: { document, value in
                guard let current = node(in: document.layers, nodeID: nodeID) else {
                    throw ValueSwapCommandError.nodeNotFound
                }
                _ = try propertyValue(for: current, matching: value)
                try validateProperty(value)
            },
            mutation: { document, value in
                mutateNode(
                    in: &document.layers, nodeID: nodeID,
                    mutation: {
                        do { return try setProperty(value, on: &$0) } catch { return false }
                    })
            })
    }

    public static func textContent(
        in document: EditorDocument, nodeID: ObjectID, newValue: String,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        guard let context = nodeContext(in: document.layers, nodeID: nodeID) else {
            throw ValueSwapCommandError.nodeNotFound
        }
        guard case .text(let text) = context.node else { throw ValueSwapCommandError.wrongNodeKind }
        var changedText = text
        changedText.text = newValue
        return try nodeCommand(
            name: "Text", before: documentBounds(of: context.node, parent: context.parent),
            after: documentBounds(of: .text(changedText), parent: context.parent), commandID: commandID,
            timestamp: timestamp, oldValue: text.text, newValue: newValue,
            validation: { document, value in
                try validateString(value)
                guard case .text? = node(in: document.layers, nodeID: nodeID) else {
                    throw ValueSwapCommandError.wrongNodeKind
                }
            },
            mutation: { document, value in
                mutateNode(
                    in: &document.layers, nodeID: nodeID,
                    mutation: {
                        guard case .text(var text) = $0 else { return false }
                        text.text = value
                        $0 = .text(text)
                        return true
                    })
            })
    }

    public static func layerVisibilityAndLock(
        in document: EditorDocument, layerID: ObjectID, newValue: LayerVisibilityAndLock,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        guard let layer = document.layers.first(where: { $0.id == layerID }) else {
            throw ValueSwapCommandError.layerNotFound
        }
        let oldValue = LayerVisibilityAndLock(isVisible: layer.isVisible, isLocked: layer.isLocked)
        return try command(
            name: "Layer visibility and lock", commandID: commandID, timestamp: timestamp, damageBounds: .full,
            oldValue: oldValue, newValue: newValue,
            validation: { document, _ in
                guard document.layers.contains(where: { $0.id == layerID }) else {
                    throw ValueSwapCommandError.layerNotFound
                }
            },
            mutation: { document, value in
                guard let index = document.layers.firstIndex(where: { $0.id == layerID }) else {
                    return false
                }
                document.layers[index].isVisible = value.isVisible
                document.layers[index].isLocked = value.isLocked
                return true
            })
    }

    public static func layerName(
        in document: EditorDocument, layerID: ObjectID, newValue: String,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        guard let layer = document.layers.first(where: { $0.id == layerID }) else {
            throw ValueSwapCommandError.layerNotFound
        }
        return try command(
            name: "Layer name", commandID: commandID, timestamp: timestamp,
            damageBounds: .none, oldValue: layer.name, newValue: newValue,
            validation: { document, value in
                try validateString(value)
                guard document.layers.contains(where: { $0.id == layerID }) else {
                    throw ValueSwapCommandError.layerNotFound
                }
            },
            mutation: { document, value in
                guard let index = document.layers.firstIndex(where: { $0.id == layerID }) else {
                    return false
                }
                document.layers[index].name = value
                return true
            })
    }

    public static func artboardProperties(
        in document: EditorDocument, newValue: ArtboardProperties,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        let oldValue = ArtboardProperties(width: document.width, height: document.height, unit: document.unit)
        return try command(
            name: "Artboard properties", commandID: commandID, timestamp: timestamp, damageBounds: .full,
            oldValue: oldValue, newValue: newValue,
            validation: { _, value in try validateArtboard(value) },
            mutation: { document, value in
                document.width = value.width
                document.height = value.height
                document.unit = value.unit
                return true
            })
    }

    private static func nodeCommand<Value: Codable & Sendable>(
        name: String, before: Rect?, after: Rect?, commandID: UUID, timestamp: Date, oldValue: Value,
        newValue: Value,
        validation: @escaping @Sendable (EditorDocument, Value) throws -> Void,
        mutation: @escaping @Sendable (inout EditorDocument, Value) -> Bool
    ) throws -> DocumentCommand {
        return try command(
            name: name, commandID: commandID, timestamp: timestamp,
            damageBounds: damageBounds(before: before, after: after), oldValue: oldValue, newValue: newValue,
            validation: validation, mutation: mutation)
    }

    private static func command<Value: Codable & Sendable>(
        name: String, commandID: UUID, timestamp: Date, damageBounds: DocumentCommandDamageBounds,
        oldValue: Value, newValue: Value,
        validation: @escaping @Sendable (EditorDocument, Value) throws -> Void,
        mutation: @escaping @Sendable (inout EditorDocument, Value) -> Bool
    ) throws -> DocumentCommand {
        let oldBytes = try canonicalBytes(oldValue)
        let newBytes = try canonicalBytes(newValue)
        let structuralCost = 128 + oldBytes.count + newBytes.count
        return try DocumentCommand(
            commandID: commandID, timestamp: timestamp, name: name, damageBounds: damageBounds,
            costInBytes: structuralCost, pinnedAssets: [], oldPayload: oldBytes, newPayload: newBytes,
            validatedApply: {
                guard mutation(&$0, newValue) else { throw ValueSwapCommandError.nodeNotFound }
            },
            validatedUnapply: {
                guard mutation(&$0, oldValue) else { throw ValueSwapCommandError.nodeNotFound }
            },
            applyPreflight: { try validation($0, newValue) }, unapplyPreflight: { try validation($0, oldValue) })
    }
}

private func damageBounds(before: Rect?, after: Rect?) -> DocumentCommandDamageBounds {
    switch (before, after) {
    case (nil, nil): return .none
    case (.some(let value), nil), (nil, .some(let value)): return .rect(value)
    case (.some(let before), .some(let after)): return .rect(before.union(after))
    }
}

private func node(in layers: [Layer], nodeID: ObjectID) -> SceneNode? {
    for layer in layers {
        if let value = node(in: layer.nodes, nodeID: nodeID) { return value }
    }
    return nil
}

private func nodeContext(in layers: [Layer], nodeID: ObjectID) -> (node: SceneNode, parent: Geometry.AffineTransform)? {
    for layer in layers {
        if let value = nodeContext(in: layer.nodes, nodeID: nodeID, parent: .identity) { return value }
    }
    return nil
}

private func nodeContext(
    in nodes: [SceneNode], nodeID: ObjectID, parent: Geometry.AffineTransform
) -> (node: SceneNode, parent: Geometry.AffineTransform)? {
    for item in nodes {
        if item.id == nodeID { return (item, parent) }
        if case .group(let group) = item,
            let value = nodeContext(
                in: group.children, nodeID: nodeID, parent: group.transform.concatenating(parent))
        {
            return value
        }
    }
    return nil
}

private func node(in nodes: [SceneNode], nodeID: ObjectID) -> SceneNode? {
    for item in nodes {
        if item.id == nodeID { return item }
        if case .group(let group) = item, let value = node(in: group.children, nodeID: nodeID) { return value }
    }
    return nil
}

private func mutateNode(
    in layers: inout [Layer], nodeID: ObjectID, mutation: (inout SceneNode) -> Bool
) -> Bool {
    for index in layers.indices {
        if mutateNode(in: &layers[index].nodes, nodeID: nodeID, mutation: mutation) { return true }
    }
    return false
}

private func mutateNode(
    in nodes: inout [SceneNode], nodeID: ObjectID, mutation: (inout SceneNode) -> Bool
) -> Bool {
    for index in nodes.indices {
        if nodes[index].id == nodeID { return mutation(&nodes[index]) }
        if case .group(var group) = nodes[index],
            mutateNode(in: &group.children, nodeID: nodeID, mutation: mutation)
        {
            nodes[index] = .group(group)
            return true
        }
    }
    return false
}

private func nodeTransform(of node: SceneNode) -> Geometry.AffineTransform {
    switch node {
    case .path(let value): return value.transform
    case .text(let value): return value.transform
    case .image(let value): return value.transform
    case .group(let value): return value.transform
    }
}

private func documentBounds(of node: SceneNode, parent: Geometry.AffineTransform) -> Rect? {
    node.visualBounds?.transformed(by: parent)
}

private func validateTransform(_ value: Geometry.AffineTransform) throws {
    for component in [value.a, value.b, value.c, value.d, value.tx, value.ty] {
        guard component.isFinite, abs(component) <= DocumentLimits.maximumCoordinateMagnitude else {
            throw DocumentValidationError.coordinateMagnitude
        }
    }
}

private func validateString(_ value: String) throws {
    guard value.utf8.count <= DocumentLimits.maximumStringUTF8Bytes else {
        throw DocumentValidationError.stringLength
    }
}

private func validateColor(_ color: SRGBColor) throws {
    for value in [color.red, color.green, color.blue, color.alpha] {
        guard value.isFinite, value >= 0, value <= 1 else { throw DocumentValidationError.invalidStyle }
    }
}

private func validateStyle(_ style: PathStyle, in document: EditorDocument) throws {
    guard style.strokeWidth.isFinite, style.strokeWidth >= 0, style.miterLimit.isFinite, style.miterLimit >= 1,
        let opacity = style.opacity, opacity.isFinite, opacity >= 0, opacity <= 1,
        style.dash.allSatisfy({ $0.isFinite && $0 >= 0 }), style.dash.isEmpty || style.dash.contains(where: { $0 > 0 })
    else { throw DocumentValidationError.invalidStyle }
    if let color = style.fill { try validateColor(color) }
    if let color = style.stroke { try validateColor(color) }
    if let reference = style.fillGradientID,
        !document.gradients.contains(where: { $0.id == reference })
    {
        throw DocumentValidationError.danglingResource
    }
    for reference in [style.fillSwatchID, style.strokeSwatchID].compactMap({ $0 })
    where !document.swatches.contains(where: { $0.id == reference }) {
        throw DocumentValidationError.danglingResource
    }
}

private func validateProperty(_ value: ValueSwapNodeProperty) throws {
    switch value {
    case .groupName(let name), .textFontName(let name): try validateString(name)
    case .textOrigin(let origin):
        guard validCoordinate(origin.x), validCoordinate(origin.y) else {
            throw DocumentValidationError.coordinateMagnitude
        }
    case .textFontSize(let size):
        guard size.isFinite, size > 0 else { throw DocumentValidationError.coordinateMagnitude }
    case .textColor(let color): try validateColor(color)
    case .imageFrame(let frame):
        guard validCoordinate(frame.minX), validCoordinate(frame.minY), validCoordinate(frame.maxX),
            validCoordinate(frame.maxY), frame.width > 0, frame.height > 0
        else { throw DocumentValidationError.invalidImage }
    }
}

private func validateArtboard(_ value: ArtboardProperties) throws {
    guard value.width.isFinite, value.height.isFinite, value.width > 0, value.height > 0,
        value.width <= DocumentLimits.maximumArtboardDimension,
        value.height <= DocumentLimits.maximumArtboardDimension
    else { throw DocumentValidationError.artboardMagnitude }
}

private func validCoordinate(_ value: Double) -> Bool {
    value.isFinite && abs(value) <= DocumentLimits.maximumCoordinateMagnitude
}

private func setTransform(_ transform: Geometry.AffineTransform, on node: inout SceneNode) -> Bool {
    switch node {
    case .path(var value):
        value.transform = transform
        node = .path(value)
    case .text(var value):
        value.transform = transform
        node = .text(value)
    case .image(var value):
        value.transform = transform
        node = .image(value)
    case .group(var value):
        value.transform = transform
        node = .group(value)
    }
    return true
}

private func propertyValue(for node: SceneNode, matching value: ValueSwapNodeProperty) throws -> ValueSwapNodeProperty {
    switch (node, value) {
    case (.group(let group), .groupName): return .groupName(group.name)
    case (.text(let text), .textOrigin): return .textOrigin(text.origin)
    case (.text(let text), .textFontName): return .textFontName(text.fontName)
    case (.text(let text), .textFontSize): return .textFontSize(text.fontSize)
    case (.text(let text), .textColor): return .textColor(text.color)
    case (.image(let image), .imageFrame): return .imageFrame(image.frame)
    default: throw ValueSwapCommandError.wrongNodeKind
    }
}

private func setProperty(_ value: ValueSwapNodeProperty, on node: inout SceneNode) throws -> Bool {
    switch (node, value) {
    case (.group(var group), .groupName(let name)):
        group.name = name
        node = .group(group)
    case (.text(var text), .textOrigin(let origin)):
        text.origin = origin
        node = .text(text)
    case (.text(var text), .textFontName(let name)):
        text.fontName = name
        node = .text(text)
    case (.text(var text), .textFontSize(let size)):
        text.fontSize = size
        node = .text(text)
    case (.text(var text), .textColor(let color)):
        text.color = color
        node = .text(text)
    case (.image(var image), .imageFrame(let frame)):
        image.frame = frame
        node = .image(image)
    default: throw ValueSwapCommandError.wrongNodeKind
    }
    return true
}
