import DocumentModel
import EditorCore
import Geometry

public enum AlignmentAxis: Sendable { case left, horizontalCenter, right, top, verticalCenter, bottom }
public enum AlignmentCommands {
    public static func align(pathIDs: Set<ObjectID>, axis: AlignmentAxis) -> DocumentCommand {
        DocumentCommand(name: "Align objects") { document in
            let selected = document.layers.flatMap(\.paths).filter { pathIDs.contains($0.id) }
            guard selected.count >= 2 else { return }
            let bounds = selected.compactMap(\.bounds)
            guard bounds.count == selected.count else { return }
            let target: Double
            switch axis {
            case .left: target = bounds.map(\.minX).min()!
            case .right: target = bounds.map(\.maxX).max()!
            case .horizontalCenter: target = bounds.map(\.center.x).reduce(0, +) / Double(bounds.count)
            case .top: target = bounds.map(\.minY).min()!
            case .bottom: target = bounds.map(\.maxY).max()!
            case .verticalCenter: target = bounds.map(\.center.y).reduce(0, +) / Double(bounds.count)
            }
            for layerIndex in document.layers.indices {
                for pathIndex in document.layers[layerIndex].paths.indices
                where pathIDs.contains(document.layers[layerIndex].paths[pathIndex].id) {
                    guard let b = document.layers[layerIndex].paths[pathIndex].bounds else { continue }
                    switch axis {
                    case .left: document.layers[layerIndex].paths[pathIndex].transform.tx += target - b.minX
                    case .right: document.layers[layerIndex].paths[pathIndex].transform.tx += target - b.maxX
                    case .horizontalCenter:
                        document.layers[layerIndex].paths[pathIndex].transform.tx += target - b.center.x
                    case .top: document.layers[layerIndex].paths[pathIndex].transform.ty += target - b.minY
                    case .bottom: document.layers[layerIndex].paths[pathIndex].transform.ty += target - b.maxY
                    case .verticalCenter:
                        document.layers[layerIndex].paths[pathIndex].transform.ty += target - b.center.y
                    }
                }
            }
        }
    }
}
