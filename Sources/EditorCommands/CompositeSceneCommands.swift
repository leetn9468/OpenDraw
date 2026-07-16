import DocumentModel
import EditorCore
import Foundation
import Geometry

public enum CompositeSceneCommandError: Error, Equatable, Sendable {
    case selectionTooSmall
    case parentsDiffer
    case wrongNodeKind
    case incompatiblePaths
    case identifierCount
}

/// Delta-path scene actions assembled from P1 value swaps and P2 structural
/// commands. Builders stage every child before constructing the next one so
/// each inverse captures the exact intermediate parent/index/value state.
public enum CompositeSceneCommands {
    public static func group(
        in document: EditorDocument, nodeIDs: [ObjectID], groupID: ObjectID = ObjectID(),
        name: String = "Group"
    ) throws -> DocumentCommand {
        guard !nodeIDs.isEmpty else { throw CompositeSceneCommandError.selectionTooSmall }
        let originalSlots = try nodeIDs.map { try StructuralCommands.slot(for: $0, in: document) }
        guard let parent = originalSlots.first?.parent,
            originalSlots.allSatisfy({ $0.parent == parent })
        else { throw CompositeSceneCommandError.parentsDiffer }
        let insertionIndex = originalSlots.map(\.childIndex).min()!
        var staged = document
        var children: [DocumentCommand] = []
        try append(
            StructuralCommands.insert(
                .group(GroupNode(id: groupID, name: name, children: [])), in: staged,
                parent: parent, at: insertionIndex, name: "Insert group"),
            to: &children, staging: &staged)
        for nodeID in originalSlots.sorted(by: { $0.childIndex < $1.childIndex }).map({ $0.node.id }) {
            let destination = try StructuralCommands.childCount(of: .group(groupID), in: staged)
            try append(
                StructuralCommands.reorderNode(
                    in: staged, nodeID: nodeID, to: .group(groupID), at: destination),
                to: &children, staging: &staged)
        }
        return try CompositeCommands.ordered(name: "Group", children: children)
    }

    public static func ungroup(
        in document: EditorDocument, groupID: ObjectID
    ) throws -> DocumentCommand {
        let slot = try StructuralCommands.slot(for: groupID, in: document)
        guard case .group(let group) = slot.node else { throw CompositeSceneCommandError.wrongNodeKind }
        var staged = document
        var children: [DocumentCommand] = []
        for child in group.children {
            let value = sceneTransform(child).concatenating(group.transform)
            try append(
                ValueSwapCommands.transform(in: staged, nodeID: child.id, newValue: value),
                to: &children, staging: &staged)
        }
        for (offset, child) in group.children.enumerated() {
            try append(
                StructuralCommands.reorderNode(
                    in: staged, nodeID: child.id, to: slot.parent,
                    at: slot.childIndex + 1 + offset),
                to: &children, staging: &staged)
        }
        try append(
            StructuralCommands.delete(nodeIDs: [groupID], in: staged),
            to: &children, staging: &staged)
        return try CompositeCommands.ordered(name: "Ungroup", children: children)
    }

    public static func makeCompound(
        in document: EditorDocument, pathIDs: [ObjectID]
    ) throws -> DocumentCommand {
        guard pathIDs.count >= 2 else { throw CompositeSceneCommandError.selectionTooSmall }
        let slots = try pathIDs.map { try StructuralCommands.slot(for: $0, in: document) }
        guard let parent = slots.first?.parent, slots.allSatisfy({ $0.parent == parent }) else {
            throw CompositeSceneCommandError.parentsDiffer
        }
        let paths: [PathObject] = try slots.map {
            guard case .path(let path) = $0.node else { throw CompositeSceneCommandError.wrongNodeKind }
            return path
        }
        guard let first = paths.first,
            paths.dropFirst().allSatisfy({ $0.transform == first.transform && $0.style == first.style })
        else { throw CompositeSceneCommandError.incompatiblePaths }
        var compound = first
        compound.path.subpaths = paths.flatMap { $0.path.subpaths }
        let insertionIndex = slots.map(\.childIndex).min()!
        var staged = document
        var children: [DocumentCommand] = []
        try append(
            StructuralCommands.delete(nodeIDs: pathIDs, in: staged),
            to: &children, staging: &staged)
        try append(
            StructuralCommands.insert(
                .path(compound), in: staged, parent: parent, at: insertionIndex,
                name: "Insert compound path"),
            to: &children, staging: &staged)
        return try CompositeCommands.ordered(name: "Make compound path", children: children)
    }

    public static func releaseCompound(
        in document: EditorDocument, pathID: ObjectID, releasedIDs: [ObjectID]
    ) throws -> DocumentCommand {
        let slot = try StructuralCommands.slot(for: pathID, in: document)
        guard case .path(let path) = slot.node else { throw CompositeSceneCommandError.wrongNodeKind }
        guard path.path.subpaths.count > 1, releasedIDs.count == path.path.subpaths.count else {
            throw CompositeSceneCommandError.identifierCount
        }
        let released = zip(path.path.subpaths, releasedIDs).map { subpath, id in
            SceneNode.path(
                PathObject(
                    id: id, path: CompoundPath(subpaths: [subpath], fillRule: path.path.fillRule),
                    style: path.style, transform: path.transform))
        }
        var staged = document
        var children: [DocumentCommand] = []
        try append(
            StructuralCommands.delete(nodeIDs: [pathID], in: staged),
            to: &children, staging: &staged)
        try append(
            StructuralCommands.paste(released, in: staged, parent: slot.parent, at: slot.childIndex),
            to: &children, staging: &staged)
        return try CompositeCommands.ordered(name: "Release compound path", children: children)
    }

    public static func align(
        in document: EditorDocument, nodeIDs: Set<ObjectID>, axis: AlignmentAxis
    ) throws -> DocumentCommand {
        let entries = nodeIDs.compactMap { id in document.visualBounds(for: id).map { (id, $0) } }
            .sorted { $0.0.rawValue.uuidString < $1.0.rawValue.uuidString }
        guard entries.count >= 2 else { throw CompositeSceneCommandError.selectionTooSmall }
        let target: Double
        switch axis {
        case .left: target = entries.map { $0.1.minX }.min()!
        case .right: target = entries.map { $0.1.maxX }.max()!
        case .horizontalCenter: target = entries.map { $0.1.center.x }.reduce(0, +) / Double(entries.count)
        case .top: target = entries.map { $0.1.minY }.min()!
        case .bottom: target = entries.map { $0.1.maxY }.max()!
        case .verticalCenter: target = entries.map { $0.1.center.y }.reduce(0, +) / Double(entries.count)
        }
        var staged = document
        var children: [DocumentCommand] = []
        for (id, bounds) in entries {
            let delta: (Double, Double)
            switch axis {
            case .left: delta = (target - bounds.minX, 0)
            case .right: delta = (target - bounds.maxX, 0)
            case .horizontalCenter: delta = (target - bounds.center.x, 0)
            case .top: delta = (0, target - bounds.minY)
            case .bottom: delta = (0, target - bounds.maxY)
            case .verticalCenter: delta = (0, target - bounds.center.y)
            }
            var planned = staged
            guard planned.translateNode(id: id, documentDX: delta.0, documentDY: delta.1),
                let transformed = try? StructuralCommands.slot(for: id, in: planned)
            else { throw ValueSwapCommandError.nodeNotFound }
            let command = try ValueSwapCommands.transform(
                in: staged, nodeID: id, newValue: sceneTransform(transformed.node))
            try append(command, to: &children, staging: &staged)
        }
        return try CompositeCommands.ordered(name: "Align objects", children: children)
    }
}

private func append(
    _ command: DocumentCommand, to commands: inout [DocumentCommand],
    staging document: inout EditorDocument
) throws {
    try command.apply(to: &document)
    commands.append(command)
}

private func sceneTransform(_ node: SceneNode) -> Geometry.AffineTransform {
    switch node {
    case .path(let value): return value.transform
    case .text(let value): return value.transform
    case .image(let value): return value.transform
    case .group(let value): return value.transform
    }
}
