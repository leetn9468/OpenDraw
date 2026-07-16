import DocumentModel
import EditorCommands
import EditorCore
import Foundation
import Geometry
import Testing

private enum P3FixtureError: Error { case forward, inverse }

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testP3CompositeCleanRollbackRecordsNothing() throws {
    let original = try EditorDocument(width: 100, height: 100)
    let first = try p3WidthCommand(old: 100, new: 101)
    let failing = try DocumentCommand(
        name: "Fail forward", damageBounds: .none, costInBytes: 1,
        oldPayload: Data([0]), newPayload: Data([1]),
        apply: { _ in throw P3FixtureError.forward }, unapply: { _ in })
    let composite = try CompositeCommands.ordered(name: "Clean rollback", children: [first, failing])
    var history = try DeltaCommandHistory(document: original, featureFlag: .environment())
    do {
        _ = try history.commit(composite)
        Issue.record("Composite unexpectedly committed")
    } catch let error as CompositeCommandError {
        guard case .childFailed(index: 1, _) = error else {
            Issue.record("Unexpected composite error: \(error)")
            return
        }
    }
    #expect(history.document == original)
    #expect(history.undoDepth == 0)
    #expect(history.globalCommandCounter == 0)
    #expect(history.lastDiagnostic == nil)
}

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testP3CompositeUnwindFailureEngagesCheckpointContainment() throws {
    let original = try EditorDocument(width: 100, height: 100)
    let inverseFailing = try DocumentCommand(
        name: "Inverse fails", damageBounds: .rect(Rect(minX: 0, minY: 0, maxX: 1, maxY: 1)),
        costInBytes: 7, oldPayload: Data([0]), newPayload: Data([1]),
        apply: { $0.width = 101 }, unapply: { _ in throw P3FixtureError.inverse })
    let forwardFailing = try DocumentCommand(
        name: "Forward fails", damageBounds: .rect(Rect(minX: 2, minY: 2, maxX: 3, maxY: 3)),
        costInBytes: 11, oldPayload: Data([0]), newPayload: Data([1]),
        apply: { _ in throw P3FixtureError.forward }, unapply: { _ in })
    let composite = try CompositeCommands.ordered(
        name: "Containment fixture", children: [inverseFailing, forwardFailing])
    #expect(composite.costInBytes == 128 + 7 + 11)
    #expect(
        composite.damageBounds
            == .rect(Rect(minX: 0, minY: 0, maxX: 3, maxY: 3)))
    var directDocument = original
    #expect(throws: CompositeCommandError.self) { try composite.apply(to: &directDocument) }
    #expect(directDocument == original)

    var history = try DeltaCommandHistory(document: original, featureFlag: .environment())
    #expect(throws: CompositeCommandError.self) { try history.commit(composite) }
    #expect(history.document == original)
    #expect(history.undoDepth == 0)
    #expect(history.globalCommandCounter == 0)
    #expect(history.lastDiagnostic?.operation == .commit)
    #expect(history.lastDiagnostic?.recoverySucceeded == true)
    #expect(history.lastDiagnostic?.restoredCheckpointCounter == 0)
}

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testP3CompositeAllIdentityChildrenElideAtCompositeGranularity() throws {
    let document = try EditorDocument(width: 100, height: 100)
    let identity = try p3WidthCommand(old: 100, new: 100)
    let composite = try CompositeCommands.ordered(name: "Identity composite", children: [identity])
    var history = try DeltaCommandHistory(document: document, featureFlag: .environment())
    #expect(composite.isIdentity)
    #expect(try history.commit(composite) == .identityElided)
    #expect(history.globalCommandCounter == 0)
}

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testVerify025UngroupCompositeFrozenExamplesAndReverseRestoration() throws {
    let n1 = PathObject(
        id: p3ID(1), segments: [p3Line()], transform: Geometry.AffineTransform(tx: 1, ty: 1))
    let n2 = PathObject(
        id: p3ID(2), segments: [p3Line()],
        transform: Geometry.AffineTransform(a: 0, b: 1, c: -1, d: 0))
    let n3 = PathObject(
        id: p3ID(3), segments: [p3Line()], transform: Geometry.AffineTransform(a: 0.5, d: 0.5))
    let group = GroupNode(
        id: p3ID(4), transform: Geometry.AffineTransform(a: 2, d: 2, tx: 5),
        children: [.path(n1), .path(n2), .path(n3)])
    let original = try EditorDocument(
        width: 100, height: 100,
        layers: [Layer(id: p3ID(5), name: "L", nodes: [.group(group)])])
    #expect(original.documentPoint(pathID: n1.id, localPoint: Point(x: 1, y: 0)) == Point(x: 9, y: 2))
    #expect(original.documentPoint(pathID: n2.id, localPoint: Point(x: 1, y: 0)) == Point(x: 5, y: 2))
    #expect(original.documentPoint(pathID: n3.id, localPoint: Point(x: 1, y: 0)) == Point(x: 6, y: 0))
    #expect(original.documentPoint(pathID: n1.id, localPoint: Point(x: 0, y: 0)) == Point(x: 7, y: 2))

    var history = try DeltaCommandHistory(document: original, featureFlag: .environment())
    try history.commit(CompositeSceneCommands.ungroup(in: history.document, groupID: group.id))
    #expect(history.undoDepth == 1)
    #expect(history.document.documentPoint(pathID: n1.id, localPoint: Point(x: 1, y: 0)) == Point(x: 9, y: 2))
    #expect(history.document.documentPoint(pathID: n2.id, localPoint: Point(x: 1, y: 0)) == Point(x: 5, y: 2))
    #expect(history.document.documentPoint(pathID: n3.id, localPoint: Point(x: 1, y: 0)) == Point(x: 6, y: 0))
    try history.undo()
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
    #expect(history.document.documentPoint(pathID: n1.id, localPoint: Point(x: 0, y: 0)) == Point(x: 7, y: 2))
}

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testVerify025SingleChildCompositeInverseReducesDirectly() throws {
    let document = try EditorDocument(width: 100, height: 100)
    let child = try p3WidthCommand(old: 100, new: 125)
    let composite = try CompositeCommands.ordered(name: "Single", children: [child])
    var history = try DeltaCommandHistory(document: document, featureFlag: .environment())
    try history.commit(composite)
    #expect(history.document.width == 125)
    try history.undo()
    #expect(history.document == document)
}

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testP3GroupUngroupAndCompoundRoundTripsRestoreCanonicalDocument() throws {
    let layerID = p3ID(10)
    let a = PathObject(id: p3ID(11), segments: [p3Line()], transform: Geometry.AffineTransform(tx: 2))
    let b = PathObject(id: p3ID(12), segments: [p3Line()], transform: Geometry.AffineTransform(tx: 8))
    let original = try EditorDocument(
        width: 100, height: 100, layers: [Layer(id: layerID, name: "L", nodes: [.path(a), .path(b)])])
    var history = try DeltaCommandHistory(document: original, featureFlag: .environment())
    let groupID = p3ID(13)
    try history.commit(
        CompositeSceneCommands.group(in: history.document, nodeIDs: [a.id, b.id], groupID: groupID))
    try history.commit(CompositeSceneCommands.ungroup(in: history.document, groupID: groupID))
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
    #expect(history.document.visualBounds(for: a.id) == original.visualBounds(for: a.id))
    #expect(history.document.visualBounds(for: b.id) == original.visualBounds(for: b.id))

    var compoundHistory = try DeltaCommandHistory(document: original, featureFlag: .environment())
    // Compound membership requires common style/transform; normalize B with a
    // stored transform before exercising make/release.
    try compoundHistory.commit(
        ValueSwapCommands.transform(in: compoundHistory.document, nodeID: b.id, newValue: a.transform))
    let normalized = compoundHistory.document
    try compoundHistory.commit(
        CompositeSceneCommands.makeCompound(in: compoundHistory.document, pathIDs: [a.id, b.id]))
    #expect(compoundHistory.document.path(id: a.id)?.path.subpaths.count == 2)
    try compoundHistory.commit(
        CompositeSceneCommands.releaseCompound(
            in: compoundHistory.document, pathID: a.id, releasedIDs: [a.id, b.id]))
    #expect(try CanonicalDocumentEquality.equals(compoundHistory.document, normalized))
    try compoundHistory.undo()
    try compoundHistory.undo()
    #expect(try CanonicalDocumentEquality.equals(compoundHistory.document, normalized))
}

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testP3UngroupRotatedGroupPreservesExactVisualBounds() throws {
    let child = PathObject(
        id: p3ID(14), segments: [p3Line()], transform: Geometry.AffineTransform(tx: 3, ty: 4))
    let group = GroupNode(
        id: p3ID(15), transform: Geometry.AffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 20, ty: 10),
        children: [.path(child)])
    let original = try EditorDocument(
        width: 100, height: 100,
        layers: [Layer(id: p3ID(16), name: "L", nodes: [.group(group)])])
    let originalBounds = original.visualBounds(for: child.id)
    var history = try DeltaCommandHistory(document: original, featureFlag: .environment())
    try history.commit(CompositeSceneCommands.ungroup(in: history.document, groupID: group.id))
    #expect(history.document.visualBounds(for: child.id) == originalBounds)
    try history.undo()
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
}

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testP3AlignmentIsOneCompositeAndUndoableOnDeltaPath() throws {
    let layerID = p3ID(20)
    let a = PathObject(id: p3ID(21), segments: [p3Line()], transform: Geometry.AffineTransform(tx: 2))
    let b = PathObject(id: p3ID(22), segments: [p3Line()], transform: Geometry.AffineTransform(tx: 9))
    let original = try EditorDocument(
        width: 100, height: 100, layers: [Layer(id: layerID, name: "L", nodes: [.path(a), .path(b)])])
    var history = try DeltaCommandHistory(document: original, featureFlag: .environment())
    try history.commit(
        CompositeSceneCommands.align(in: history.document, nodeIDs: [a.id, b.id], axis: .left))
    #expect(history.undoDepth == 1)
    #expect(history.document.visualBounds(for: a.id)?.minX == history.document.visualBounds(for: b.id)?.minX)
    try history.undo()
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
}

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testVerify026SmoothAnchorSliceFrozenTripleAndExactInverse() throws {
    let pathID = p3ID(30)
    let original = try p3AnchorDocument(pathID: pathID)
    let location = PathAnchorLocation(pathID: pathID, anchorIndex: 1)
    let old = try AnchorGeometryCommands.slice(in: original, at: location)
    #expect(old.anchor == Point(x: 100, y: 100))
    #expect(old.incoming == Point(x: 90, y: 95))
    #expect(old.outgoing == Point(x: 110, y: 105))
    #expect(Point(x: 2 * old.anchor.x - old.incoming!.x, y: 2 * old.anchor.y - old.incoming!.y) == old.outgoing)
    var history = try DeltaCommandHistory(document: original, featureFlag: .environment())
    try history.commit(
        AnchorGeometryCommands.moveAnchor(in: history.document, at: location, dx: 20, dy: 10))
    let moved = try AnchorGeometryCommands.slice(in: history.document, at: location)
    #expect(moved.anchor == Point(x: 120, y: 110))
    #expect(moved.incoming == Point(x: 110, y: 105))
    #expect(moved.outgoing == Point(x: 130, y: 115))
    #expect(
        Point(x: 2 * moved.anchor.x - moved.incoming!.x, y: 2 * moved.anchor.y - moved.incoming!.y) == moved.outgoing)
    try history.undo()
    #expect(try AnchorGeometryCommands.slice(in: history.document, at: location) == old)
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
}

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testVerify026CornerUntouchedHandleIsBitwiseStable() throws {
    let pathID = p3ID(31)
    let document = try p3AnchorDocument(pathID: pathID)
    let location = PathAnchorLocation(pathID: pathID, anchorIndex: 1)
    let old = try AnchorGeometryCommands.slice(in: document, at: location)
    var history = try DeltaCommandHistory(document: document, featureFlag: .environment())
    try history.commit(
        AnchorGeometryCommands.moveHandle(
            in: history.document, at: location, side: .incoming,
            to: Point(x: 77, y: 88), smooth: false))
    let edited = try AnchorGeometryCommands.slice(in: history.document, at: location)
    #expect(edited.incoming == Point(x: 77, y: 88))
    #expect(edited.outgoing!.x.bitPattern == old.outgoing!.x.bitPattern)
    #expect(edited.outgoing!.y.bitPattern == old.outgoing!.y.bitPattern)
    try history.undo()
    #expect(try AnchorGeometryCommands.slice(in: history.document, at: location) == old)
}

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testVerify026OpenEndpointNilIsRestoredNotSynthesized() throws {
    let pathID = p3ID(32)
    let original = try p3AnchorDocument(pathID: pathID)
    let location = PathAnchorLocation(pathID: pathID, anchorIndex: 0)
    let old = try AnchorGeometryCommands.slice(in: original, at: location)
    #expect(old.incoming == nil)
    var history = try DeltaCommandHistory(document: original, featureFlag: .environment())
    try history.commit(
        AnchorGeometryCommands.moveAnchor(in: history.document, at: location, dx: 5, dy: -3))
    #expect(try AnchorGeometryCommands.slice(in: history.document, at: location).incoming == nil)
    try history.undo()
    let restored = try AnchorGeometryCommands.slice(in: history.document, at: location)
    #expect(restored == old)
    #expect(restored.incoming == nil)
}

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testP3AnchorStructuralSliceAddDeleteRoundTrip() throws {
    let pathID = p3ID(33)
    let original = try p3AnchorDocument(pathID: pathID)
    let segment = original.path(id: pathID)!.path.subpaths[0].segments[0]
    let split = segment.split()
    var history = try DeltaCommandHistory(document: original, featureFlag: .environment())
    try history.commit(
        AnchorGeometryCommands.replaceSegments(
            in: history.document, pathID: pathID, range: 0..<1, with: [split.0, split.1]))
    #expect(history.document.path(id: pathID)?.path.subpaths[0].segments.count == 3)
    let added = history.document
    try history.commit(
        AnchorGeometryCommands.replaceSegments(
            in: history.document, pathID: pathID, range: 0..<2, with: [segment]))
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
    try history.undo()
    #expect(try CanonicalDocumentEquality.equals(history.document, added))
    try history.undo()
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
}

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testP3RealGestureCoalescingCommitsOneCommandAndCancelPreservesRedo() throws {
    let pathID = p3ID(40)
    let original = try p3AnchorDocument(pathID: pathID)
    var history = try DeltaCommandHistory(document: original, featureFlag: .environment())
    try history.commit(
        ValueSwapCommands.transform(
            in: history.document, nodeID: pathID, newValue: Geometry.AffineTransform(tx: 3)))
    try history.undo()
    let redoDepth = history.redoDepth
    let counter = history.globalCommandCounter
    let cancelled = try history.beginTransformGesture(nodeID: pathID)
    try history.updateTransformGesture(cancelled, newValue: Geometry.AffineTransform(tx: 7))
    try history.updateTransformGesture(cancelled, newValue: Geometry.AffineTransform(tx: 9))
    #expect(history.undoDepth == 0)
    #expect(history.globalCommandCounter == counter)
    try history.cancelDeltaGesture(cancelled)
    #expect(history.redoDepth == redoDepth)
    #expect(history.globalCommandCounter == counter)
    #expect(try CanonicalDocumentEquality.equals(history.document, original))

    try history.redo()
    let gesture = try history.beginTransformGesture(nodeID: pathID)
    try history.updateTransformGesture(gesture, newValue: Geometry.AffineTransform(tx: 11))
    try history.updateTransformGesture(gesture, newValue: Geometry.AffineTransform(tx: 13))
    #expect(try history.endGesture(gesture) == .committed)
    #expect(history.undoDepth == 2)
    #expect(history.globalCommandCounter == counter + 1)
    try history.undo()
    #expect(history.document.path(id: pathID)?.transform == Geometry.AffineTransform(tx: 3))
}

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testP3AnchorGestureCoalescesAndFailedFirstGestureDoesNotCorruptLaterCoalescing() throws {
    let pathID = p3ID(41)
    let original = try p3AnchorDocument(pathID: pathID)
    let location = PathAnchorLocation(pathID: pathID, anchorIndex: 1)
    var history = try DeltaCommandHistory(document: original, featureFlag: .environment())
    let failed = try history.beginAnchorGesture(at: location)
    var invalid = try AnchorGeometryCommands.slice(in: history.document, at: location)
    invalid.anchor.x = .nan
    #expect(throws: AnchorGeometryCommandError.invalidCoordinate) {
        try history.updateAnchorGesture(failed, newValue: invalid)
    }
    try history.cancelDeltaGesture(failed)
    #expect(history.activeGestureCount == 0)
    #expect(history.globalCommandCounter == 0)

    let valid = try history.beginAnchorGesture(at: location)
    let start = try AnchorGeometryCommands.slice(in: history.document, at: location)
    try history.updateAnchorGesture(valid, newValue: start.translated(dx: 5, dy: 2))
    try history.updateAnchorGesture(valid, newValue: start.translated(dx: 8, dy: 4))
    #expect(try history.endGesture(valid) == .committed)
    #expect(history.undoDepth == 1)
    #expect(history.globalCommandCounter == 1)
    try history.undo()
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
}

@Test(.enabled(if: DeltaHistoryFeatureFlag.environment().isEnabled))
func testP3SeededMixedCorpusCompositesAnchorsCrossEvictionAndCheckpoints() throws {
    let layerID = p3ID(50)
    let aID = p3ID(51)
    let bID = p3ID(52)
    let a = p3AnchorPath(id: aID, transform: .identity)
    let b = p3AnchorPath(id: bID, transform: Geometry.AffineTransform(tx: 10))
    let initial = try EditorDocument(
        width: 200, height: 200,
        layers: [Layer(id: layerID, name: "L", nodes: [.path(a), .path(b)])])
    var history = try DeltaCommandHistory(document: initial, featureFlag: .environment())
    var states = [initial]
    let location = PathAnchorLocation(pathID: aID, anchorIndex: 1)
    var rng = P3LCG(state: 0x0000_0000_A110_F00D)
    var pendingAnchorDelta = 1.0
    for index in 0..<204 {
        let command: DocumentCommand
        switch index % 6 {
        case 0:
            command = try CompositeSceneCommands.group(
                in: history.document, nodeIDs: [aID, bID], groupID: p3ID(1_000 + index / 6))
        case 1:
            command = try CompositeSceneCommands.ungroup(
                in: history.document, groupID: p3ID(1_000 + index / 6))
        case 2:
            command = try CompositeSceneCommands.align(
                in: history.document, nodeIDs: [aID, bID], axis: .left)
        case 3:
            command = try ValueSwapCommands.transform(
                in: history.document, nodeID: bID, newValue: Geometry.AffineTransform(tx: 10))
        case 4:
            pendingAnchorDelta = Double((rng.next() % 3) + 1)
            command = try AnchorGeometryCommands.moveAnchor(
                in: history.document, at: location, dx: pendingAnchorDelta, dy: 0)
        default:
            command = try AnchorGeometryCommands.moveAnchor(
                in: history.document, at: location, dx: -pendingAnchorDelta, dy: 0)
        }
        #expect(try history.commit(command) == .committed)
        states.append(history.document)
        if !(try CanonicalDocumentEquality.equals(history.document, states.last!)) {
            print("CORPUS_FAILURE kind=delta-history-p3 index=\(index) seed=0x00000000A110F00D phase=record")
            Issue.record("P3 corpus record mismatch")
        }
    }
    #expect(history.evictionCount == 4)
    #expect(history.undoDepth == 200)
    #expect(history.checkpointCount <= 9)
    for index in stride(from: 203, through: 4, by: -1) {
        try history.undo()
        if !(try CanonicalDocumentEquality.equals(history.document, states[index])) {
            print("CORPUS_FAILURE kind=delta-history-p3 index=\(index) seed=0x00000000A110F00D phase=unwind")
            Issue.record("P3 corpus unwind mismatch")
        }
    }
    #expect(try CanonicalDocumentEquality.equals(history.document, initial))
    for index in 5...204 {
        try history.redo()
        if !(try CanonicalDocumentEquality.equals(history.document, states[index])) {
            print("CORPUS_FAILURE kind=delta-history-p3 index=\(index) seed=0x00000000A110F00D phase=replay")
            Issue.record("P3 corpus replay mismatch")
        }
    }
    #expect(try CanonicalDocumentEquality.equals(history.document, states[204]))
}

private struct P3LCG {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

private func p3WidthCommand(old: Double, new: Double) throws -> DocumentCommand {
    try DocumentCommand(
        name: "Width", damageBounds: .none, costInBytes: 8,
        oldPayload: try p3Bytes(old), newPayload: try p3Bytes(new),
        apply: { $0.width = new }, unapply: { $0.width = old })
}

private func p3Bytes<Value: Encodable>(_ value: Value) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(value)
}

private func p3AnchorDocument(pathID: ObjectID) throws -> EditorDocument {
    try EditorDocument(
        width: 200, height: 200,
        layers: [Layer(id: p3ID(900), name: "L", nodes: [.path(p3AnchorPath(id: pathID))])])
}

private func p3AnchorPath(
    id: ObjectID, transform: Geometry.AffineTransform = .identity
) -> PathObject {
    PathObject(
        id: id,
        segments: [
            CubicBezier(
                start: Point(x: 0, y: 0), control1: Point(x: 10, y: 10),
                control2: Point(x: 90, y: 95), end: Point(x: 100, y: 100)),
            CubicBezier(
                start: Point(x: 100, y: 100), control1: Point(x: 110, y: 105),
                control2: Point(x: 140, y: 140), end: Point(x: 150, y: 150)),
        ], transform: transform)
}

private func p3Line() -> CubicBezier {
    CubicBezier(
        start: Point(x: 0, y: 0), control1: Point(x: 0, y: 0),
        control2: Point(x: 1, y: 0), end: Point(x: 1, y: 0))
}

private func p3ID(_ value: Int) -> ObjectID {
    ObjectID(
        rawValue: UUID(uuidString: String(format: "00000000-0000-0000-0003-%012X", value))!)
}
