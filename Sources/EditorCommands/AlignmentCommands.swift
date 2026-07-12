import DocumentModel
import EditorCore
import Geometry

public enum AlignmentAxis: Sendable { case left, horizontalCenter, right, top, verticalCenter, bottom }
public enum AlignmentCommands {
    public static func align(pathIDs: Set<ObjectID>, axis: AlignmentAxis) -> DocumentCommand {
        align(nodeIDs: pathIDs, axis: axis)
    }
    public static func align(nodeIDs: Set<ObjectID>, axis: AlignmentAxis) -> DocumentCommand {
        DocumentCommand(name: "Align objects") { document in
            // Alignment uses visual bounds because the user aligns rendered ink.
            let entries = nodeIDs.compactMap { id in document.visualBounds(for: id).map { (id, $0) } }
            guard entries.count >= 2 else { return }
            let target: Double
            switch axis {
            case .left: target = entries.map { $0.1.minX }.min()!
            case .right: target = entries.map { $0.1.maxX }.max()!
            case .horizontalCenter: target = entries.map { $0.1.center.x }.reduce(0, +) / Double(entries.count)
            case .top: target = entries.map { $0.1.minY }.min()!
            case .bottom: target = entries.map { $0.1.maxY }.max()!
            case .verticalCenter: target = entries.map { $0.1.center.y }.reduce(0, +) / Double(entries.count)
            }
            for (id, bounds) in entries {
                let dx: Double
                let dy: Double
                switch axis {
                case .left:
                    dx = target - bounds.minX
                    dy = 0
                case .right:
                    dx = target - bounds.maxX
                    dy = 0
                case .horizontalCenter:
                    dx = target - bounds.center.x
                    dy = 0
                case .top:
                    dx = 0
                    dy = target - bounds.minY
                case .bottom:
                    dx = 0
                    dy = target - bounds.maxY
                case .verticalCenter:
                    dx = 0
                    dy = target - bounds.center.y
                }
                _ = document.translateNode(id: id, documentDX: dx, documentDY: dy)
            }
        }
    }
}
