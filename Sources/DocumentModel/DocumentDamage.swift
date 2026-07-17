import Geometry

/// Typed conservative document-space damage shared by mutation publishers and
/// render caches. Absence at a call site is distinct from `.none` and is
/// classified as unknown/full by the consumer.
public enum DocumentDamage: Hashable, Sendable {
    case none
    case rects([Rect])
    case full
}

extension SceneNode {
    /// Returns a bound only when every contributing ink bound is trustworthy.
    /// In particular, a group never drops an unknown child from its union.
    public var conservativeInkBounds: Rect? {
        switch self {
        case .path(let path):
            return path.visualBounds
        case .text(let text):
            return text.conservativeInkBounds?.transformed(by: text.transform)
        case .image(let image):
            return image.frame.transformed(by: image.transform)
        case .group(let group):
            guard let first = group.children.first,
                var result = first.conservativeInkBounds
            else { return nil }
            for child in group.children.dropFirst() {
                guard let childBounds = child.conservativeInkBounds else { return nil }
                result = result.union(childBounds)
            }
            return result.transformed(by: group.transform)
        }
    }
}
