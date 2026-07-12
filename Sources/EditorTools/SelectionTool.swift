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
}
