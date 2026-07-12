import DocumentModel
import EditorCommands
import EditorCore
import Geometry

public struct SelectionState: Equatable, Sendable {
    public var objectIDs: Set<ObjectID> = []
    public init() {}
}

public struct SelectionTool: Sendable {
    public init() {}
    public func hitAnchor(_ anchor: Point, pointer: Point, zoom: Double) -> Bool {
        HitTesting.anchor(at: anchor, query: pointer, screenTolerance: 6, zoom: zoom)
    }
    public func hitTest(_ document: EditorDocument, pointer: Point, zoom: Double) -> ObjectID? {
        guard zoom.isFinite, zoom > 0 else { return nil }
        for layer in document.layers.reversed() where layer.isVisible && !layer.isLocked {
            if let id = hit(nodes: layer.nodes.reversed(), pointer: pointer, zoom: zoom, parent: .identity) {
                return id
            }
        }
        return nil
    }
    private func hit(
        nodes: ReversedCollection<[SceneNode]>, pointer: Point, zoom: Double, parent: AffineTransform
    ) -> ObjectID? {
        for node in nodes {
            switch node {
            case .group(let group):
                if let id = hit(
                    nodes: group.children.reversed(), pointer: pointer, zoom: zoom,
                    parent: parent.concatenating(group.transform))
                {
                    return id
                }
            case .path(let path):
                let transform = parent.concatenating(path.transform)
                guard let local = transform.inverted()?.applying(to: pointer) else { continue }
                if path.style.fill != nil || path.style.fillGradientID != nil, path.path.contains(local) {
                    return path.id
                }
                let tolerance = 6 / zoom + path.style.strokeWidth / 2
                for subpath in path.path.subpaths {
                    if subpath.segments.contains(where: { $0.hitTest(local, tolerance: tolerance) }) { return path.id }
                    if subpath.isClosed, let first = subpath.segments.first?.start,
                        let last = subpath.segments.last?.end,
                        CubicBezier(start: last, control1: last, control2: first, end: first)
                            .hitTest(local, tolerance: tolerance, subdivisions: 1)
                    {
                        return path.id
                    }
                }
            default:
                if node.visualBounds?.contains(pointer, tolerance: 6 / zoom) == true { return node.id }
            }
        }
        return nil
    }
}
