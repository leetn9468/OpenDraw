import DocumentModel
import EditorCore
import Foundation
import Geometry

public struct PathAnchorLocation: Hashable, Codable, Sendable {
    public let pathID: ObjectID
    public let subpathIndex: Int
    public let anchorIndex: Int

    public init(pathID: ObjectID, subpathIndex: Int = 0, anchorIndex: Int) {
        self.pathID = pathID
        self.subpathIndex = subpathIndex
        self.anchorIndex = anchorIndex
    }
}

/// Runtime history view of path topology. Endpoint absence is represented by
/// nil here only; PenAnchor and the v4 serialized cubic representation remain
/// unchanged under P-ENDPOINT.
public struct PathAnchorSlice: Hashable, Codable, Sendable {
    public var anchor: Point
    public var incoming: Point?
    public var outgoing: Point?

    public init(anchor: Point, incoming: Point?, outgoing: Point?) {
        self.anchor = anchor
        self.incoming = incoming
        self.outgoing = outgoing
    }

    public func translated(dx: Double, dy: Double) -> PathAnchorSlice {
        func moved(_ point: Point) -> Point { Point(x: point.x + dx, y: point.y + dy) }
        return PathAnchorSlice(
            anchor: moved(anchor), incoming: incoming.map(moved), outgoing: outgoing.map(moved))
    }
}

public enum PathHandleSide: Sendable { case incoming, outgoing }

public enum AnchorGeometryCommandError: Error, Equatable, Sendable {
    case pathNotFound
    case subpathNotFound
    case anchorNotFound
    case endpointTopologyMismatch
    case handleNotFound
    case invalidCoordinate
    case invalidSegmentRange
    case staleSlice
}

private struct SegmentSlicePayload: Hashable, Codable, Sendable {
    var pathID: ObjectID
    var subpathIndex: Int
    var rangeStart: Int
    var removed: [CubicBezier]
    var inserted: [CubicBezier]
}

public enum AnchorGeometryCommands {
    public static func isSmooth(_ slice: PathAnchorSlice) -> Bool {
        guard let incoming = slice.incoming, let outgoing = slice.outgoing else { return false }
        return outgoing
            == Point(
                x: 2 * slice.anchor.x - incoming.x,
                y: 2 * slice.anchor.y - incoming.y)
    }

    public static func handleDragSlice(
        from old: PathAnchorSlice, side: PathHandleSide, to point: Point,
        breakSmooth: Bool
    ) throws -> PathAnchorSlice {
        var new = old
        let preserveSmooth = isSmooth(old) && !breakSmooth
        switch side {
        case .incoming:
            guard old.incoming != nil else { throw AnchorGeometryCommandError.handleNotFound }
            new.incoming = point
            if preserveSmooth, old.outgoing != nil {
                new.outgoing = Point(x: 2 * old.anchor.x - point.x, y: 2 * old.anchor.y - point.y)
            }
        case .outgoing:
            guard old.outgoing != nil else { throw AnchorGeometryCommandError.handleNotFound }
            new.outgoing = point
            if preserveSmooth, old.incoming != nil {
                new.incoming = Point(x: 2 * old.anchor.x - point.x, y: 2 * old.anchor.y - point.y)
            }
        }
        return new
    }

    public static func slice(
        in document: EditorDocument, at location: PathAnchorLocation
    ) throws -> PathAnchorSlice {
        try readSlice(in: document, at: location)
    }

    public static func setSlice(
        in document: EditorDocument, at location: PathAnchorLocation,
        newValue: PathAnchorSlice, commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        try setSlice(
            in: document, at: location, oldValue: readSlice(in: document, at: location),
            newValue: newValue, commandID: commandID, timestamp: timestamp)
    }

    /// Explicit pre/post form used by coalesced gestures after intermediate
    /// rendering has already placed the document at post-state.
    public static func setSlice(
        in document: EditorDocument, at location: PathAnchorLocation,
        oldValue: PathAnchorSlice, newValue: PathAnchorSlice,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        try validateSlice(newValue)
        let oldBytes = try canonicalBytes(oldValue)
        let newBytes = try canonicalBytes(newValue)
        var beforeDocument = document
        try writeSlice(oldValue, in: &beforeDocument, at: location, requireCurrent: nil)
        let before = beforeDocument.visualBounds(for: location.pathID)
        var afterDocument = document
        try writeSlice(newValue, in: &afterDocument, at: location, requireCurrent: nil)
        let after = afterDocument.visualBounds(for: location.pathID)
        return try DocumentCommand(
            commandID: commandID, timestamp: timestamp, name: "Edit anchor",
            damageBounds: anchorDamage(before, after),
            costInBytes: 160 + oldBytes.count + newBytes.count, pinnedAssets: [],
            oldPayload: oldBytes, newPayload: newBytes,
            validatedApply: {
                try writeSlice(newValue, in: &$0, at: location, requireCurrent: nil)
            },
            validatedUnapply: {
                try writeSlice(oldValue, in: &$0, at: location, requireCurrent: nil)
            },
            applyPreflight: { try validateTopology(in: $0, at: location, for: newValue) },
            unapplyPreflight: { try validateTopology(in: $0, at: location, for: oldValue) })
    }

    public static func moveAnchor(
        in document: EditorDocument, at location: PathAnchorLocation,
        dx: Double, dy: Double
    ) throws -> DocumentCommand {
        let old = try readSlice(in: document, at: location)
        return try setSlice(in: document, at: location, oldValue: old, newValue: old.translated(dx: dx, dy: dy))
    }

    public static func moveHandle(
        in document: EditorDocument, at location: PathAnchorLocation,
        side: PathHandleSide, to point: Point, smooth: Bool
    ) throws -> DocumentCommand {
        let old = try readSlice(in: document, at: location)
        var new = old
        switch side {
        case .incoming:
            guard old.incoming != nil else { throw AnchorGeometryCommandError.handleNotFound }
            new.incoming = point
            if smooth, old.outgoing != nil {
                new.outgoing = Point(x: 2 * old.anchor.x - point.x, y: 2 * old.anchor.y - point.y)
            }
        case .outgoing:
            guard old.outgoing != nil else { throw AnchorGeometryCommandError.handleNotFound }
            new.outgoing = point
            if smooth, old.incoming != nil {
                new.incoming = Point(x: 2 * old.anchor.x - point.x, y: 2 * old.anchor.y - point.y)
            }
        }
        return try setSlice(in: document, at: location, oldValue: old, newValue: new)
    }

    /// Structural control-point-array slice replacement used by anchor add and
    /// delete. The removed range is captured verbatim; inverse swaps the exact
    /// removed/inserted cubic segment arrays.
    public static func replaceSegments(
        in document: EditorDocument, pathID: ObjectID, subpathIndex: Int = 0,
        range: Range<Int>, with inserted: [CubicBezier],
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        let path = try pathObject(in: document, id: pathID)
        guard path.path.subpaths.indices.contains(subpathIndex) else {
            throw AnchorGeometryCommandError.subpathNotFound
        }
        let segments = path.path.subpaths[subpathIndex].segments
        guard range.lowerBound >= 0, range.upperBound <= segments.count else {
            throw AnchorGeometryCommandError.invalidSegmentRange
        }
        let removed = Array(segments[range])
        let oldPayload = SegmentSlicePayload(
            pathID: pathID, subpathIndex: subpathIndex, rangeStart: range.lowerBound,
            removed: removed, inserted: inserted)
        let newPayload = SegmentSlicePayload(
            pathID: pathID, subpathIndex: subpathIndex, rangeStart: range.lowerBound,
            removed: inserted, inserted: removed)
        let oldBytes = try canonicalBytes(oldPayload)
        let newBytes = try canonicalBytes(newPayload)
        let forward: @Sendable (inout EditorDocument) throws -> Void = {
            try replaceSegmentSlice(
                in: &$0, pathID: pathID, subpathIndex: subpathIndex,
                at: range.lowerBound, expected: removed, replacement: inserted)
        }
        let reverse: @Sendable (inout EditorDocument) throws -> Void = {
            try replaceSegmentSlice(
                in: &$0, pathID: pathID, subpathIndex: subpathIndex,
                at: range.lowerBound, expected: inserted, replacement: removed)
        }
        return try DocumentCommand(
            commandID: commandID, timestamp: timestamp, name: "Edit path structure",
            damageBounds: .full, costInBytes: 192 + oldBytes.count + newBytes.count,
            pinnedAssets: [], oldPayload: oldBytes, newPayload: newBytes,
            apply: forward, unapply: reverse)
    }
}

private func anchorDamage(_ before: Rect?, _ after: Rect?) -> DocumentCommandDamageBounds {
    switch (before, after) {
    case (nil, nil): return .none
    case (.some(let rect), nil), (nil, .some(let rect)): return .rect(rect)
    case (.some(let lhs), .some(let rhs)): return .rect(lhs.union(rhs))
    }
}

private func validateSlice(_ slice: PathAnchorSlice) throws {
    for point in [slice.anchor, slice.incoming, slice.outgoing].compactMap({ $0 }) {
        guard point.x.isFinite, point.y.isFinite,
            abs(point.x) <= DocumentLimits.maximumCoordinateMagnitude,
            abs(point.y) <= DocumentLimits.maximumCoordinateMagnitude
        else { throw AnchorGeometryCommandError.invalidCoordinate }
    }
}

private func validateTopology(
    in document: EditorDocument, at location: PathAnchorLocation,
    for proposed: PathAnchorSlice
) throws {
    try validateSlice(proposed)
    let current = try readSlice(in: document, at: location)
    guard (current.incoming == nil) == (proposed.incoming == nil),
        (current.outgoing == nil) == (proposed.outgoing == nil)
    else { throw AnchorGeometryCommandError.endpointTopologyMismatch }
}

private func readSlice(
    in document: EditorDocument, at location: PathAnchorLocation
) throws -> PathAnchorSlice {
    let path = try pathObject(in: document, id: location.pathID)
    guard path.path.subpaths.indices.contains(location.subpathIndex) else {
        throw AnchorGeometryCommandError.subpathNotFound
    }
    let subpath = path.path.subpaths[location.subpathIndex]
    let segments = subpath.segments
    guard !segments.isEmpty else { throw AnchorGeometryCommandError.anchorNotFound }
    if subpath.isClosed {
        guard segments.indices.contains(location.anchorIndex) else {
            throw AnchorGeometryCommandError.anchorNotFound
        }
        let index = location.anchorIndex
        let prior = index == 0 ? segments.count - 1 : index - 1
        return PathAnchorSlice(
            anchor: segments[index].start, incoming: segments[prior].control2,
            outgoing: segments[index].control1)
    }
    guard location.anchorIndex >= 0, location.anchorIndex <= segments.count else {
        throw AnchorGeometryCommandError.anchorNotFound
    }
    if location.anchorIndex == 0 {
        return PathAnchorSlice(anchor: segments[0].start, incoming: nil, outgoing: segments[0].control1)
    }
    if location.anchorIndex == segments.count {
        let last = segments.count - 1
        return PathAnchorSlice(anchor: segments[last].end, incoming: segments[last].control2, outgoing: nil)
    }
    let index = location.anchorIndex
    return PathAnchorSlice(
        anchor: segments[index].start, incoming: segments[index - 1].control2,
        outgoing: segments[index].control1)
}

private func writeSlice(
    _ value: PathAnchorSlice, in document: inout EditorDocument,
    at location: PathAnchorLocation, requireCurrent: PathAnchorSlice?
) throws {
    try validateTopology(in: document, at: location, for: value)
    if let requireCurrent, try readSlice(in: document, at: location) != requireCurrent {
        throw AnchorGeometryCommandError.staleSlice
    }
    guard
        mutatePath(
            in: &document.layers, id: location.pathID,
            mutation: { path in
                guard path.path.subpaths.indices.contains(location.subpathIndex) else { return false }
                var subpath = path.path.subpaths[location.subpathIndex]
                let count = subpath.segments.count
                guard count > 0 else { return false }
                if subpath.isClosed {
                    guard subpath.segments.indices.contains(location.anchorIndex),
                        let incoming = value.incoming, let outgoing = value.outgoing
                    else { return false }
                    let index = location.anchorIndex
                    let prior = index == 0 ? count - 1 : index - 1
                    subpath.segments[index].start = value.anchor
                    subpath.segments[prior].end = value.anchor
                    subpath.segments[prior].control2 = incoming
                    subpath.segments[index].control1 = outgoing
                } else if location.anchorIndex == 0 {
                    guard value.incoming == nil, let outgoing = value.outgoing else { return false }
                    subpath.segments[0].start = value.anchor
                    subpath.segments[0].control1 = outgoing
                } else if location.anchorIndex == count {
                    guard value.outgoing == nil, let incoming = value.incoming else { return false }
                    subpath.segments[count - 1].end = value.anchor
                    subpath.segments[count - 1].control2 = incoming
                } else {
                    guard location.anchorIndex > 0, location.anchorIndex < count,
                        let incoming = value.incoming, let outgoing = value.outgoing
                    else { return false }
                    let index = location.anchorIndex
                    subpath.segments[index - 1].end = value.anchor
                    subpath.segments[index].start = value.anchor
                    subpath.segments[index - 1].control2 = incoming
                    subpath.segments[index].control1 = outgoing
                }
                path.path.subpaths[location.subpathIndex] = subpath
                return true
            })
    else { throw AnchorGeometryCommandError.pathNotFound }
}

private func replaceSegmentSlice(
    in document: inout EditorDocument, pathID: ObjectID, subpathIndex: Int,
    at start: Int, expected: [CubicBezier], replacement: [CubicBezier]
) throws {
    guard
        mutatePath(
            in: &document.layers, id: pathID,
            mutation: { path in
                guard path.path.subpaths.indices.contains(subpathIndex) else { return false }
                var segments = path.path.subpaths[subpathIndex].segments
                let end = start + expected.count
                guard start >= 0, end <= segments.count, Array(segments[start..<end]) == expected else {
                    return false
                }
                segments.replaceSubrange(start..<end, with: replacement)
                path.path.subpaths[subpathIndex].segments = segments
                return true
            })
    else { throw AnchorGeometryCommandError.staleSlice }
}

private func pathObject(in document: EditorDocument, id: ObjectID) throws -> PathObject {
    for layer in document.layers {
        if let path = pathObject(in: layer.nodes, id: id) { return path }
    }
    throw AnchorGeometryCommandError.pathNotFound
}

private func pathObject(in nodes: [SceneNode], id: ObjectID) -> PathObject? {
    for node in nodes {
        if case .path(let path) = node, path.id == id { return path }
        if case .group(let group) = node, let path = pathObject(in: group.children, id: id) {
            return path
        }
    }
    return nil
}

private func mutatePath(
    in layers: inout [Layer], id: ObjectID, mutation: (inout PathObject) -> Bool
) -> Bool {
    for index in layers.indices {
        if mutatePath(in: &layers[index].nodes, id: id, mutation: mutation) { return true }
    }
    return false
}

private func mutatePath(
    in nodes: inout [SceneNode], id: ObjectID, mutation: (inout PathObject) -> Bool
) -> Bool {
    for index in nodes.indices {
        switch nodes[index] {
        case .path(var path) where path.id == id:
            guard mutation(&path) else { return false }
            nodes[index] = .path(path)
            return true
        case .group(var group):
            if mutatePath(in: &group.children, id: id, mutation: mutation) {
                nodes[index] = .group(group)
                return true
            }
        default: continue
        }
    }
    return false
}
