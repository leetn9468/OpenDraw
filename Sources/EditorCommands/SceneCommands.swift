import DocumentModel
import EditorCore
import Geometry

public enum SceneCommandError: Error, Equatable { case selectionNotFound, incompatibleSelection }

public enum SceneCommands {
    public static func moveAnchor(pathID: ObjectID, subpath: Int, segment: Int, delta: Point) -> DocumentCommand {
        DocumentCommand(name: "Move anchor") { document in
            guard document.movePathAnchor(id: pathID, subpath: subpath, segment: segment, documentDelta: delta)
            else { throw SceneCommandError.selectionNotFound }
        }
    }
    public static func deleteAnchor(pathID: ObjectID, subpath: Int, segment: Int) -> DocumentCommand {
        DocumentCommand(name: "Delete anchor") { document in
            var deleted = false
            guard
                document.mutatePath(
                    id: pathID,
                    { path in
                        guard path.path.subpaths.indices.contains(subpath),
                            path.path.subpaths[subpath].segments.count > 1,
                            path.path.subpaths[subpath].segments.indices.contains(segment)
                        else { return }
                        path.path.subpaths[subpath].segments.remove(at: segment)
                        deleted = true
                    }), deleted
            else { throw SceneCommandError.incompatibleSelection }
        }
    }
    public static func moveControl(pathID: ObjectID, subpath: Int, segment: Int, control: Int, delta: Point)
        -> DocumentCommand
    {
        DocumentCommand(name: "Move direction handle") { document in
            guard
                document.movePathControl(
                    id: pathID, subpath: subpath, segment: segment, control: control, documentDelta: delta)
            else { throw SceneCommandError.selectionNotFound }
        }
    }
    public static func group(layerID: ObjectID, nodeIDs: Set<ObjectID>) -> DocumentCommand {
        DocumentCommand(name: "Group") { document in
            guard let layerIndex = document.layers.firstIndex(where: { $0.id == layerID }) else {
                throw SceneCommandError.selectionNotFound
            }
            let nodes = document.layers[layerIndex].nodes
            let selected = nodes.enumerated().filter { nodeIDs.contains($0.element.id) }
            guard selected.count >= 2 else { throw SceneCommandError.incompatibleSelection }
            let insertion = selected.map(\.offset).min()!
            document.layers[layerIndex].nodes.removeAll { nodeIDs.contains($0.id) }
            document.layers[layerIndex].nodes.insert(
                .group(GroupNode(children: selected.map(\.element))), at: insertion)
        }
    }
    public static func ungroup(layerID: ObjectID, groupID: ObjectID) -> DocumentCommand {
        DocumentCommand(name: "Ungroup") { document in
            guard let li = document.layers.firstIndex(where: { $0.id == layerID }),
                let ni = document.layers[li].nodes.firstIndex(where: { $0.id == groupID }),
                case .group(let group) = document.layers[li].nodes[ni]
            else { throw SceneCommandError.selectionNotFound }
            let children = group.children.map { applying(group.transform, to: $0) }
            document.layers[li].nodes.remove(at: ni)
            document.layers[li].nodes.insert(contentsOf: children, at: ni)
        }
    }
    public static func makeCompound(layerID: ObjectID, pathIDs: Set<ObjectID>) -> DocumentCommand {
        DocumentCommand(name: "Make compound path") { document in
            guard let li = document.layers.firstIndex(where: { $0.id == layerID }) else {
                throw SceneCommandError.selectionNotFound
            }
            let selected = document.layers[li].nodes.enumerated().compactMap { index, node -> (Int, PathObject)? in
                guard pathIDs.contains(node.id), case .path(let path) = node else { return nil }
                return (index, path)
            }
            guard selected.count >= 2, selected.dropFirst().allSatisfy({ $0.1.transform == selected[0].1.transform })
            else { throw SceneCommandError.incompatibleSelection }
            var combined = selected[0].1
            combined.path = CompoundPath(
                subpaths: selected.flatMap { $0.1.path.subpaths }, fillRule: combined.path.fillRule)
            document.layers[li].nodes.removeAll { pathIDs.contains($0.id) }
            document.layers[li].nodes.insert(.path(combined), at: selected.map(\.0).min()!)
        }
    }
    public static func releaseCompound(layerID: ObjectID, pathID: ObjectID) -> DocumentCommand {
        DocumentCommand(name: "Release compound path") { document in
            guard let li = document.layers.firstIndex(where: { $0.id == layerID }),
                let ni = document.layers[li].nodes.firstIndex(where: { $0.id == pathID }),
                case .path(let compound) = document.layers[li].nodes[ni], compound.path.subpaths.count > 1
            else { throw SceneCommandError.selectionNotFound }
            let released = compound.path.subpaths.enumerated().map { offset, subpath in
                var path = compound
                if offset > 0 { path.id = ObjectID() }
                path.path = CompoundPath(subpaths: [subpath], fillRule: compound.path.fillRule)
                return SceneNode.path(path)
            }
            document.layers[li].nodes.remove(at: ni)
            document.layers[li].nodes.insert(contentsOf: released, at: ni)
        }
    }
}

private func applying(_ transform: AffineTransform, to node: SceneNode) -> SceneNode {
    switch node {
    case .path(var value):
        value.transform = value.transform.concatenating(transform)
        return .path(value)
    case .text(var value):
        value.transform = value.transform.concatenating(transform)
        return .text(value)
    case .image(var value):
        value.transform = value.transform.concatenating(transform)
        return .image(value)
    case .group(var value):
        value.transform = value.transform.concatenating(transform)
        return .group(value)
    }
}
