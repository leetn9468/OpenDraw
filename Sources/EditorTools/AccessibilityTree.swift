import DocumentModel
import EditorCore
import Geometry

public struct AccessibilityNode: Equatable, Sendable {
    public enum Role: String, Sendable { case document, layer, object }
    public var role: Role
    public var label: String
    public var frame: Rect?
    public var children: [AccessibilityNode]
    public init(role: Role, label: String, frame: Rect? = nil, children: [AccessibilityNode] = []) {
        self.role = role
        self.label = label
        self.frame = frame
        self.children = children
    }
}

public enum AccessibilityTree {
    public static func build(document: EditorDocument, selectedIDs: Set<ObjectID> = []) -> AccessibilityNode {
        AccessibilityNode(
            role: .document, label: "OpenDraw document",
            children: document.layers.map { layer in
                AccessibilityNode(
                    role: .layer, label: "\(layer.name)\(layer.isLocked ? ", locked" : "")",
                    children: layer.nodes.map { node in
                        AccessibilityNode(
                            role: .object, label: "\(label(node))\(selectedIDs.contains(node.id) ? ", selected" : "")",
                            frame: node.visualBounds)
                    })
            })
    }
    private static func label(_ node: SceneNode) -> String {
        switch node {
        case .path: "Path"
        case .text(let value): "Text: \(value.text)"
        case .image: "Image"
        case .group(let value): "Group: \(value.name)"
        }
    }
}
