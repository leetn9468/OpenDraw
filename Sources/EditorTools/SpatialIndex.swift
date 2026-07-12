import DocumentModel
import EditorCore
import Foundation
import Geometry

public struct SpatialIndex: Sendable {
    private var cells: [Cell: Set<ObjectID>] = [:]
    private let cellSize: Double
    private struct Cell: Hashable, Sendable {
        var x: Int
        var y: Int
    }
    public init(document: EditorDocument, cellSize: Double = 128) {
        self.cellSize = max(1, cellSize)
        for id in document.layers.flatMap({ $0.nodes.flatMap(\.recursiveIDs) }) {
            if let bounds = document.visualBounds(for: id) { insert(id: id, bounds: bounds) }
        }
    }
    public init(paths: [PathObject], cellSize: Double = 128) {
        self.cellSize = max(1, cellSize)
        for path in paths { if let bounds = path.visualBounds { insert(id: path.id, bounds: bounds) } }
    }
    private mutating func insert(id: ObjectID, bounds: Rect) {
        for x in Int(floor(bounds.minX / cellSize))...Int(floor(bounds.maxX / cellSize)) {
            for y in Int(floor(bounds.minY / cellSize))...Int(floor(bounds.maxY / cellSize)) {
                cells[Cell(x: x, y: y), default: []].insert(id)
            }
        }
    }
    public func candidates(at point: Point) -> Set<ObjectID> {
        cells[Cell(x: Int(floor(point.x / cellSize)), y: Int(floor(point.y / cellSize)))] ?? []
    }
}

extension SceneNode {
    fileprivate var recursiveIDs: [ObjectID] {
        switch self {
        case .group(let group): return [id] + group.children.flatMap(\.recursiveIDs)
        default: return [id]
        }
    }
}
