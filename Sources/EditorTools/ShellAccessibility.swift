public struct ShellAccessibilityNode: Equatable, Sendable {
    public enum Role: String, Sendable { case window, toolbar, group, button, outline, textField }
    public var role: Role
    public var label: String
    public var children: [ShellAccessibilityNode]

    public init(role: Role, label: String, children: [ShellAccessibilityNode] = []) {
        self.role = role
        self.label = label
        self.children = children
    }
}

/// Testable accessibility contract mirrored by the native AppKit shell.
public enum EditorShellAccessibility {
    public static let structure = ShellAccessibilityNode(
        role: .window, label: "OpenDraw editor",
        children: [
            ShellAccessibilityNode(
                role: .toolbar, label: "Document toolbar",
                children: ["New", "Open", "Save", "Export", "Zoom controls", "Zoom to Fit", "Layers", "Inspector"]
                    .map { ShellAccessibilityNode(role: .button, label: $0) }),
            ShellAccessibilityNode(
                role: .group, label: "Tools",
                children: ["Select", "Direct Select", "Pen", "Rectangle", "Ellipse", "Text", "Place Image"]
                    .map { ShellAccessibilityNode(role: .button, label: $0) }),
            ShellAccessibilityNode(role: .group, label: "Canvas"),
            ShellAccessibilityNode(role: .outline, label: "Layers"),
            ShellAccessibilityNode(
                role: .group, label: "Inspector",
                children: [
                    "Geometry X", "Geometry Y", "Geometry W", "Geometry H", "Geometry ∠", "Stroke width",
                    "Dash pattern", "Opacity", "Text content", "Text font name", "Text font size",
                ]
                .map { ShellAccessibilityNode(role: .textField, label: $0) }
                    + [
                        "Align Left", "Align Center", "Align Right", "Align Top", "Align Middle", "Align Bottom",
                    ].map { ShellAccessibilityNode(role: .button, label: $0) }),
        ])
}
