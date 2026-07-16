import DocumentModel
import EditorCore
import Foundation

public enum StructuralCommandError: Error, Equatable, Sendable {
    case nodeNotFound
    case layerNotFound
    case parentNotFound
    case invalidIndex
    case duplicateSelection
    case overlappingSelection
    case assetStoreRequired
    case assetNotApproved
}

public enum SceneParent: Hashable, Codable, Sendable {
    case layer(ObjectID)
    case group(ObjectID)
}

public struct SceneNodeSlot: Hashable, Codable, Sendable {
    public let parent: SceneParent
    public let childIndex: Int
    public let node: SceneNode

    public init(parent: SceneParent, childIndex: Int, node: SceneNode) {
        self.parent = parent
        self.childIndex = childIndex
        self.node = node
    }
}

private struct NodePosition: Hashable, Codable, Sendable {
    var parent: SceneParent
    var childIndex: Int
}

private struct NodeMovePayload: Hashable, Codable, Sendable {
    var nodeID: ObjectID
    var position: NodePosition
}

private struct LayerMovePayload: Hashable, Codable, Sendable {
    var layerID: ObjectID
    var index: Int
}

private struct LayerSlot: Hashable, Codable, Sendable {
    var index: Int
    var layer: Layer
}

public enum StructuralCommands {
    public static func slot(
        for nodeID: ObjectID, in document: EditorDocument
    ) throws -> SceneNodeSlot {
        try locate(nodeID: nodeID, in: document).slot
    }

    public static func childCount(
        of parent: SceneParent, in document: EditorDocument
    ) throws -> Int {
        try children(of: parent, in: document).count
    }

    public static func insertLayer(
        _ layer: Layer, in document: EditorDocument, at index: Int,
        assetStore: ApprovedAssetStore? = nil,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        let slot = LayerSlot(index: index, layer: layer)
        let oldBytes = try canonicalBytes([LayerSlot]())
        let newBytes = try canonicalBytes([slot])
        let forward: @Sendable (inout EditorDocument) throws -> Void = {
            guard index >= 0, index <= $0.layers.count else { throw StructuralCommandError.invalidIndex }
            $0.layers.insert(layer, at: index)
        }
        let reverse: @Sendable (inout EditorDocument) throws -> Void = {
            guard $0.layers.indices.contains(index), $0.layers[index].id == layer.id else {
                throw StructuralCommandError.layerNotFound
            }
            $0.layers.remove(at: index)
        }
        let pins = try assetPins(for: layer.nodes, assetStore: assetStore)
        return try DocumentCommand(
            commandID: commandID, timestamp: timestamp, name: "Insert layer", damageBounds: .full,
            costInBytes: 256 + layer.name.utf8.count + layer.nodes.reduce(0) { $0 + structuralCost(for: $1) },
            pinnedAssets: pins, oldPayload: oldBytes, newPayload: newBytes,
            validatedApply: forward, validatedUnapply: reverse,
            applyPreflight: { try validateLayerInsertion($0, layer: layer, at: index) },
            unapplyPreflight: { try validateLayerRemoval($0, layerID: layer.id, at: index) })
    }

    public static func createShape(
        _ path: PathObject, in document: EditorDocument, parent: SceneParent, at index: Int,
        assetStore: ApprovedAssetStore? = nil, commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        try insert(
            .path(path), in: document, parent: parent, at: index, name: "Create shape",
            assetStore: assetStore, commandID: commandID, timestamp: timestamp)
    }

    public static func createText(
        _ text: TextObject, in document: EditorDocument, parent: SceneParent, at index: Int,
        assetStore: ApprovedAssetStore? = nil, commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        try insert(
            .text(text), in: document, parent: parent, at: index, name: "Create text",
            assetStore: assetStore, commandID: commandID, timestamp: timestamp)
    }

    public static func createImage(
        _ image: ImageObject, in document: EditorDocument, parent: SceneParent, at index: Int,
        assetStore: ApprovedAssetStore? = nil, commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        try insert(
            .image(image), in: document, parent: parent, at: index, name: "Create image",
            assetStore: assetStore, commandID: commandID, timestamp: timestamp)
    }

    public static func insert(
        _ node: SceneNode, in document: EditorDocument, parent: SceneParent, at index: Int,
        name: String = "Insert node", assetStore: ApprovedAssetStore? = nil,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        try makeInsert(
            slots: [SceneNodeSlot(parent: parent, childIndex: index, node: node)], in: document,
            name: name, assetStore: assetStore, commandID: commandID, timestamp: timestamp)
    }

    public static func paste(
        _ nodes: [SceneNode], in document: EditorDocument, parent: SceneParent, at index: Int,
        assetStore: ApprovedAssetStore? = nil, commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        let slots = nodes.enumerated().map {
            SceneNodeSlot(parent: parent, childIndex: index + $0.offset, node: $0.element)
        }
        return try makeInsert(
            slots: slots, in: document, name: "Paste", assetStore: assetStore,
            commandID: commandID, timestamp: timestamp)
    }

    public static func delete(
        nodeIDs: [ObjectID], in document: EditorDocument, assetStore: ApprovedAssetStore? = nil,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        try remove(
            nodeIDs: nodeIDs, in: document, name: "Delete", assetStore: assetStore,
            commandID: commandID, timestamp: timestamp)
    }

    public static func cut(
        nodeIDs: [ObjectID], in document: EditorDocument, assetStore: ApprovedAssetStore? = nil,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        try remove(
            nodeIDs: nodeIDs, in: document, name: "Cut", assetStore: assetStore,
            commandID: commandID, timestamp: timestamp)
    }

    /// A multi-node removal is one command. Slots are removed deepest-first
    /// and, within one parent, from highest index to lowest. The inverse
    /// reinserts the stored full payloads in exact reverse removal order; this
    /// is the element-order pattern used by P3 composites.
    public static func remove(
        nodeIDs: [ObjectID], in document: EditorDocument, name: String,
        assetStore: ApprovedAssetStore? = nil, commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        guard Set(nodeIDs).count == nodeIDs.count else { throw StructuralCommandError.duplicateSelection }
        let located = try nodeIDs.map { try locate(nodeID: $0, in: document) }
        let selected = Set(nodeIDs)
        for slot in located where containsSelectedDescendant(slot.slot.node, selected: selected) {
            throw StructuralCommandError.overlappingSelection
        }
        let removalOrder = located.sorted {
            if $0.depth != $1.depth { return $0.depth > $1.depth }
            if parentSortKey($0.slot.parent) != parentSortKey($1.slot.parent) {
                return parentSortKey($0.slot.parent) < parentSortKey($1.slot.parent)
            }
            return $0.slot.childIndex > $1.slot.childIndex
        }.map(\.slot)
        let pins = try assetPins(for: removalOrder.map(\.node), assetStore: assetStore)
        let oldBytes = try canonicalBytes(removalOrder)
        let newBytes = try canonicalBytes([SceneNodeSlot]())
        let cost = structuralCost(for: removalOrder.map(\.node), base: 192)
        let applyMutation: @Sendable (inout EditorDocument) throws -> Void = { candidate in
            for slot in removalOrder { _ = try removeExact(slot, from: &candidate) }
        }
        let unapplyMutation: @Sendable (inout EditorDocument) throws -> Void = { candidate in
            for slot in removalOrder.reversed() { try insertExact(slot, into: &candidate) }
        }
        return try DocumentCommand(
            commandID: commandID, timestamp: timestamp, name: name, damageBounds: .full,
            costInBytes: cost, pinnedAssets: pins, oldPayload: oldBytes, newPayload: newBytes,
            validatedApply: applyMutation, validatedUnapply: unapplyMutation,
            applyPreflight: { try validateRemoval($0, slots: removalOrder) },
            unapplyPreflight: {
                try validateNodeInsertion($0, slots: Array(removalOrder.reversed()))
            })
    }

    /// Moves a node to a final child index. The index is interpreted after the
    /// node has been removed from its old parent.
    public static func reorderNode(
        in document: EditorDocument, nodeID: ObjectID, to parent: SceneParent, at finalIndex: Int,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        let located = try locate(nodeID: nodeID, in: document).slot
        let before = NodeMovePayload(
            nodeID: nodeID, position: NodePosition(parent: located.parent, childIndex: located.childIndex))
        let after = NodeMovePayload(
            nodeID: nodeID, position: NodePosition(parent: parent, childIndex: finalIndex))
        let oldBytes = try canonicalBytes(before)
        let newBytes = try canonicalBytes(after)
        let forward: @Sendable (inout EditorDocument) throws -> Void = {
            try moveNode(nodeID, from: before.position, to: after.position, in: &$0)
        }
        let reverse: @Sendable (inout EditorDocument) throws -> Void = {
            try moveNode(nodeID, from: after.position, to: before.position, in: &$0)
        }
        return try DocumentCommand(
            commandID: commandID, timestamp: timestamp, name: "Reorder node", damageBounds: .full,
            costInBytes: 192 + oldBytes.count + newBytes.count, pinnedAssets: [],
            oldPayload: oldBytes, newPayload: newBytes,
            validatedApply: forward, validatedUnapply: reverse,
            applyPreflight: { try validatePositionMutation($0, mutation: forward) },
            unapplyPreflight: { try validatePositionMutation($0, mutation: reverse) })
    }

    public static func reorderLayer(
        in document: EditorDocument, layerID: ObjectID, to finalIndex: Int,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        guard let oldIndex = document.layers.firstIndex(where: { $0.id == layerID }) else {
            throw StructuralCommandError.layerNotFound
        }
        let before = LayerMovePayload(layerID: layerID, index: oldIndex)
        let after = LayerMovePayload(layerID: layerID, index: finalIndex)
        let oldBytes = try canonicalBytes(before)
        let newBytes = try canonicalBytes(after)
        let forward: @Sendable (inout EditorDocument) throws -> Void = {
            try moveLayer(layerID, from: oldIndex, to: finalIndex, in: &$0)
        }
        let reverse: @Sendable (inout EditorDocument) throws -> Void = {
            try moveLayer(layerID, from: finalIndex, to: oldIndex, in: &$0)
        }
        return try DocumentCommand(
            commandID: commandID, timestamp: timestamp, name: "Reorder layer", damageBounds: .full,
            costInBytes: 128 + oldBytes.count + newBytes.count, pinnedAssets: [],
            oldPayload: oldBytes, newPayload: newBytes,
            validatedApply: forward, validatedUnapply: reverse,
            applyPreflight: { try validatePositionMutation($0, mutation: forward) },
            unapplyPreflight: { try validatePositionMutation($0, mutation: reverse) })
    }

    private static func makeInsert(
        slots: [SceneNodeSlot], in document: EditorDocument, name: String,
        assetStore: ApprovedAssetStore?, commandID: UUID, timestamp: Date
    ) throws -> DocumentCommand {
        let oldBytes = try canonicalBytes([SceneNodeSlot]())
        let newBytes = try canonicalBytes(slots)
        let cost = structuralCost(for: slots.map(\.node), base: 192)
        let forward: @Sendable (inout EditorDocument) throws -> Void = { candidate in
            for slot in slots { try insertExact(slot, into: &candidate) }
        }
        let reverse: @Sendable (inout EditorDocument) throws -> Void = { candidate in
            for slot in slots.reversed() { _ = try removeExact(slot, from: &candidate) }
        }
        let pins = try assetPins(for: slots.map(\.node), assetStore: assetStore)
        return try DocumentCommand(
            commandID: commandID, timestamp: timestamp, name: name, damageBounds: .full,
            costInBytes: cost, pinnedAssets: pins, oldPayload: oldBytes, newPayload: newBytes,
            validatedApply: forward, validatedUnapply: reverse,
            applyPreflight: { try validateNodeInsertion($0, slots: slots) },
            unapplyPreflight: { try validateRemoval($0, slots: Array(slots.reversed())) })
    }
}

private func validateMutation(
    _ document: EditorDocument, mutation: @Sendable (inout EditorDocument) throws -> Void
) throws {
    var candidate = document
    try mutation(&candidate)
    try candidate.validate()
}

/// Removal and reorder preserve every numeric/collection ceiling of an already
/// valid document. Their preflight therefore proves only exact positional
/// applicability on a candidate; insertion preflights still run full document
/// validation before the accepted document is mutated.
private func validatePositionMutation(
    _ document: EditorDocument, mutation: @Sendable (inout EditorDocument) throws -> Void
) throws {
    var candidate = document
    try mutation(&candidate)
}

private struct SceneStatistics {
    var ids: Set<ObjectID> = []
    var nodeCount = 0
    var segmentCount = 0
    var assetBytes = 0
}

/// Delta history only contains validated documents. Insert preflight therefore
/// validates the new payload in isolation, scans the current valid document for
/// additive global limits/ID collisions, and proves the exact positional
/// mutation on a candidate. This enforces the same frozen ceilings without a
/// second full validation of every unchanged node.
private func validateNodeInsertion(
    _ document: EditorDocument, slots: [SceneNodeSlot]
) throws {
    try validateInsertionPositions(document, slots: slots)
    let nodes = slots.map(\.node)
    guard !nodes.isEmpty else { return }
    let validationLayerID = document.layers[0].id
    _ = try EditorDocument(
        width: document.width, height: document.height, unit: document.unit,
        layers: [Layer(id: validationLayerID, name: "History insertion preflight", nodes: nodes)],
        swatches: document.swatches, gradients: document.gradients)
    try validateAdditiveLimits(document, adding: nodes, additionalLayerID: nil)
}

private func validateLayerInsertion(
    _ document: EditorDocument, layer: Layer, at index: Int
) throws {
    guard index >= 0, index <= document.layers.count else { throw StructuralCommandError.invalidIndex }
    guard document.layers.count < DocumentLimits.maximumLayers else {
        throw DocumentValidationError.layerCount
    }
    _ = try EditorDocument(
        width: document.width, height: document.height, unit: document.unit, layers: [layer],
        swatches: document.swatches, gradients: document.gradients)
    try validateAdditiveLimits(document, adding: layer.nodes, additionalLayerID: layer.id)
}

private func validateLayerRemoval(_ document: EditorDocument, layerID: ObjectID, at index: Int) throws {
    guard document.layers.indices.contains(index), document.layers[index].id == layerID else {
        throw StructuralCommandError.layerNotFound
    }
}

private func validateInsertionPositions(_ document: EditorDocument, slots: [SceneNodeSlot]) throws {
    var resultingCounts: [SceneParent: Int] = [:]
    for slot in slots {
        let count: Int
        if let prior = resultingCounts[slot.parent] {
            count = prior
        } else {
            count = try children(of: slot.parent, in: document).count
        }
        guard slot.childIndex >= 0, slot.childIndex <= count else {
            throw StructuralCommandError.invalidIndex
        }
        resultingCounts[slot.parent] = count + 1
    }
}

private func validateRemoval(_ document: EditorDocument, slots: [SceneNodeSlot]) throws {
    for slot in slots {
        let children = try children(of: slot.parent, in: document)
        guard children.indices.contains(slot.childIndex), children[slot.childIndex].id == slot.node.id else {
            throw StructuralCommandError.nodeNotFound
        }
    }
}

private func validateAdditiveLimits(
    _ document: EditorDocument, adding nodes: [SceneNode], additionalLayerID: ObjectID?
) throws {
    var current = SceneStatistics()
    for id in document.layers.map(\.id) + document.swatches.map(\.id) + document.gradients.map(\.id) {
        current.ids.insert(id)
    }
    for layer in document.layers {
        for node in layer.nodes { try collect(node, into: &current, requireUnique: false) }
    }
    if let additionalLayerID, !current.ids.insert(additionalLayerID).inserted {
        throw DocumentValidationError.duplicateID
    }

    var added = SceneStatistics(ids: current.ids)
    for node in nodes { try collect(node, into: &added, requireUnique: true) }
    let nodeTotal = current.nodeCount.addingReportingOverflow(added.nodeCount)
    guard !nodeTotal.overflow, nodeTotal.partialValue <= DocumentLimits.maximumNodes else {
        throw DocumentValidationError.nodeCount
    }
    let segmentTotal = current.segmentCount.addingReportingOverflow(added.segmentCount)
    guard !segmentTotal.overflow, segmentTotal.partialValue <= DocumentLimits.maximumSegments else {
        throw DocumentValidationError.segmentCount
    }
    _ = try DocumentLimits.checkedAggregateAssetBytes(current: current.assetBytes, adding: added.assetBytes)
}

private func collect(
    _ node: SceneNode, into statistics: inout SceneStatistics, requireUnique: Bool
) throws {
    statistics.nodeCount += 1
    if requireUnique, !statistics.ids.insert(node.id).inserted { throw DocumentValidationError.duplicateID }
    if !requireUnique { statistics.ids.insert(node.id) }
    switch node {
    case .path(let path):
        for subpath in path.path.subpaths { statistics.segmentCount += subpath.segments.count }
    case .image(let image):
        if case .embedded(let data) = image.storage {
            statistics.assetBytes = try DocumentLimits.checkedAggregateAssetBytes(
                current: statistics.assetBytes, adding: data.count)
        }
    case .group(let group):
        for child in group.children { try collect(child, into: &statistics, requireUnique: requireUnique) }
    case .text: break
    }
}

private func locate(nodeID: ObjectID, in document: EditorDocument) throws -> (slot: SceneNodeSlot, depth: Int) {
    for layer in document.layers {
        if let found = locate(nodeID: nodeID, in: layer.nodes, parent: .layer(layer.id), depth: 0) { return found }
    }
    throw StructuralCommandError.nodeNotFound
}

private func locate(
    nodeID: ObjectID, in nodes: [SceneNode], parent: SceneParent, depth: Int
) -> (slot: SceneNodeSlot, depth: Int)? {
    for (index, node) in nodes.enumerated() {
        if node.id == nodeID { return (SceneNodeSlot(parent: parent, childIndex: index, node: node), depth) }
        if case .group(let group) = node,
            let found = locate(nodeID: nodeID, in: group.children, parent: .group(group.id), depth: depth + 1)
        {
            return found
        }
    }
    return nil
}

private func containsSelectedDescendant(_ node: SceneNode, selected: Set<ObjectID>) -> Bool {
    guard case .group(let group) = node else { return false }
    return group.children.contains { selected.contains($0.id) || containsSelectedDescendant($0, selected: selected) }
}

private func parentSortKey(_ parent: SceneParent) -> String {
    switch parent {
    case .layer(let id): return "L\(id.rawValue.uuidString)"
    case .group(let id): return "G\(id.rawValue.uuidString)"
    }
}

private func insertExact(_ slot: SceneNodeSlot, into document: inout EditorDocument) throws {
    try mutateChildren(of: slot.parent, in: &document) { children in
        guard slot.childIndex >= 0, slot.childIndex <= children.count else {
            throw StructuralCommandError.invalidIndex
        }
        children.insert(slot.node, at: slot.childIndex)
    }
}

@discardableResult private func removeExact(
    _ slot: SceneNodeSlot, from document: inout EditorDocument
) throws -> SceneNode {
    var removed: SceneNode?
    try mutateChildren(of: slot.parent, in: &document) { children in
        guard children.indices.contains(slot.childIndex), children[slot.childIndex].id == slot.node.id else {
            throw StructuralCommandError.nodeNotFound
        }
        removed = children.remove(at: slot.childIndex)
    }
    guard let removed else { throw StructuralCommandError.nodeNotFound }
    return removed
}

private func moveNode(
    _ nodeID: ObjectID, from: NodePosition, to: NodePosition, in document: inout EditorDocument
) throws {
    let placeholder = SceneNodeSlot(
        parent: from.parent, childIndex: from.childIndex,
        node: try locate(nodeID: nodeID, in: document).slot.node)
    let node = try removeExact(placeholder, from: &document)
    try insertExact(SceneNodeSlot(parent: to.parent, childIndex: to.childIndex, node: node), into: &document)
}

private func moveLayer(_ layerID: ObjectID, from: Int, to: Int, in document: inout EditorDocument) throws {
    guard document.layers.indices.contains(from), document.layers[from].id == layerID else {
        throw StructuralCommandError.layerNotFound
    }
    let layer = document.layers.remove(at: from)
    guard to >= 0, to <= document.layers.count else { throw StructuralCommandError.invalidIndex }
    document.layers.insert(layer, at: to)
}

private func children(of parent: SceneParent, in document: EditorDocument) throws -> [SceneNode] {
    switch parent {
    case .layer(let layerID):
        guard let layer = document.layers.first(where: { $0.id == layerID }) else {
            throw StructuralCommandError.layerNotFound
        }
        return layer.nodes
    case .group(let groupID):
        for layer in document.layers {
            if let children = groupChildren(groupID: groupID, in: layer.nodes) { return children }
        }
        throw StructuralCommandError.parentNotFound
    }
}

private func groupChildren(groupID: ObjectID, in nodes: [SceneNode]) -> [SceneNode]? {
    for node in nodes {
        guard case .group(let group) = node else { continue }
        if group.id == groupID { return group.children }
        if let found = groupChildren(groupID: groupID, in: group.children) { return found }
    }
    return nil
}

private func mutateChildren(
    of parent: SceneParent, in document: inout EditorDocument,
    mutation: (inout [SceneNode]) throws -> Void
) throws {
    switch parent {
    case .layer(let layerID):
        guard let index = document.layers.firstIndex(where: { $0.id == layerID }) else {
            throw StructuralCommandError.layerNotFound
        }
        try mutation(&document.layers[index].nodes)
    case .group(let groupID):
        guard try mutateGroupChildren(groupID: groupID, in: &document.layers, mutation: mutation) else {
            throw StructuralCommandError.parentNotFound
        }
    }
}

private func mutateGroupChildren(
    groupID: ObjectID, in layers: inout [Layer], mutation: (inout [SceneNode]) throws -> Void
) throws -> Bool {
    for index in layers.indices {
        if try mutateGroupChildren(groupID: groupID, in: &layers[index].nodes, mutation: mutation) { return true }
    }
    return false
}

private func mutateGroupChildren(
    groupID: ObjectID, in nodes: inout [SceneNode], mutation: (inout [SceneNode]) throws -> Void
) throws -> Bool {
    for index in nodes.indices {
        guard case .group(var group) = nodes[index] else { continue }
        if group.id == groupID {
            try mutation(&group.children)
            nodes[index] = .group(group)
            return true
        }
        if try mutateGroupChildren(groupID: groupID, in: &group.children, mutation: mutation) {
            nodes[index] = .group(group)
            return true
        }
    }
    return false
}

private func assetPins(
    for nodes: [SceneNode], assetStore: ApprovedAssetStore?
) throws -> [HistoryAssetPin] {
    let data = nodes.flatMap(embeddedAssetData)
    guard data.isEmpty || assetStore != nil else { throw StructuralCommandError.assetStoreRequired }
    var descriptors: [String: ApprovedAssetDescriptor] = [:]
    for bytes in data {
        let assetID = ApprovedAssetStore.assetID(for: bytes)
        guard assetStore!.byteCount(assetID: assetID) == bytes.count else {
            throw StructuralCommandError.assetNotApproved
        }
        let descriptor = ApprovedAssetDescriptor(assetID: assetID, byteCount: bytes.count)
        descriptors[descriptor.assetID] = descriptor
    }
    return try descriptors.values.sorted { $0.assetID < $1.assetID }.map { try HistoryAssetPin(approvedAsset: $0) }
}

private func embeddedAssetData(in node: SceneNode) -> [Data] {
    switch node {
    case .image(let image):
        if case .embedded(let data) = image.storage { return [data] }
        return []
    case .group(let group): return group.children.flatMap(embeddedAssetData)
    default: return []
    }
}

private func structuralCost(for nodes: [SceneNode], base: Int) -> Int {
    base + nodes.reduce(0) { $0 + structuralCost(for: $1) }
}

private func structuralCost(for node: SceneNode) -> Int {
    switch node {
    case .path(let path):
        return 512 + path.path.subpaths.reduce(0) { $0 + $1.segments.count * 128 }
            + path.style.dash.count * MemoryLayout<Double>.size
    case .text(let text): return 384 + text.text.utf8.count + text.fontName.utf8.count
    case .image(let image):
        if case .linked(let path) = image.storage { return 256 + path.utf8.count }
        return 256
    case .group(let group):
        return 384 + group.name.utf8.count + group.children.reduce(0) { $0 + structuralCost(for: $1) }
    }
}
