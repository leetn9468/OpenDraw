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
    public init(paths: [PathObject], cellSize: Double = 128) {
        self.cellSize = max(1, cellSize)
        for path in paths {
            guard let b = path.bounds else { continue }
            for x in Int(floor(b.minX / self.cellSize))...Int(floor(b.maxX / self.cellSize)) {
                for y in Int(floor(b.minY / self.cellSize))...Int(floor(b.maxY / self.cellSize)) {
                    cells[Cell(x: x, y: y), default: []].insert(path.id)
                }
            }
        }
    }
    public func candidates(at point: Point) -> Set<ObjectID> {
        cells[Cell(x: Int(floor(point.x / cellSize)), y: Int(floor(point.y / cellSize)))] ?? []
    }
}
