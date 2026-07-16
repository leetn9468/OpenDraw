import DocumentModel
import EditorCommands
import EditorCore
import Foundation
import Geometry
import Testing

private enum DeltaFixtureError: Error { case forcedInverseFailure }

@Test
func testVerify022CanonicalDocumentEqualityFrozenExamples() throws {
    let empty = try EditorDocument(width: 100, height: 100)
    #expect(CanonicalDocumentEquality.volatileFields.isEmpty)
    #expect(try CanonicalDocumentEquality.equals(empty, empty))

    let encoded = try CanonicalDocumentEquality.bytes(for: empty)
    let decoded = try JSONDecoder().decode(EditorDocument.self, from: encoded)
    #expect(try CanonicalDocumentEquality.bytes(for: decoded) == encoded)

    let pathID = fixedID(1)
    let path = PathObject(
        id: pathID,
        segments: [
            CubicBezier(
                start: Point(x: 1, y: 2), control1: Point(x: 3, y: 4), control2: Point(x: 5, y: 6),
                end: Point(x: 7, y: 8))
        ])
    let first = try EditorDocument(width: 100, height: 100, layers: [Layer(name: "L", nodes: [.path(path)])])
    var second = first
    _ = second.mutatePath(id: pathID) { $0.path.subpaths[0].segments[0].control1.x = 3.nextUp }
    #expect(try !CanonicalDocumentEquality.equals(first, second))
}

@Test
func testVerify023ValueSwapTransformFrozenExamplesAndSignedZeroIdentity() throws {
    let pathID = fixedID(2)
    let child = PathObject(
        id: pathID, segments: [lineSegment()], transform: Geometry.AffineTransform(tx: 3, ty: 4))
    let inner = GroupNode(
        id: fixedID(3), transform: Geometry.AffineTransform(a: 2, d: 2), children: [.path(child)])
    let outer = GroupNode(
        id: fixedID(4), transform: Geometry.AffineTransform(tx: 10, ty: 20), children: [.group(inner)])
    var history = try DeltaCommandHistory(
        document: EditorDocument(width: 100, height: 100, layers: [Layer(name: "L", nodes: [.group(outer)])]))
    #expect(history.document.documentPoint(pathID: pathID, localPoint: Point(x: 0, y: 0)) == Point(x: 16, y: 28))
    try history.commit(
        ValueSwapCommands.transform(
            in: history.document, nodeID: pathID, newValue: Geometry.AffineTransform(tx: 5, ty: -1)))
    #expect(history.document.documentPoint(pathID: pathID, localPoint: Point(x: 0, y: 0)) == Point(x: 20, y: 18))
    try history.undo()
    #expect(history.document.documentPoint(pathID: pathID, localPoint: Point(x: 0, y: 0)) == Point(x: 16, y: 28))

    let rotatedID = fixedID(5)
    let rotated = PathObject(
        id: rotatedID, segments: [lineSegment()],
        transform: Geometry.AffineTransform(a: 0, b: 1, c: -1, d: 0))
    let scaled = GroupNode(transform: Geometry.AffineTransform(a: 2, d: 3), children: [.path(rotated)])
    var rotationHistory = try DeltaCommandHistory(
        document: EditorDocument(width: 100, height: 100, layers: [Layer(name: "L", nodes: [.group(scaled)])]))
    #expect(
        rotationHistory.document.documentPoint(pathID: rotatedID, localPoint: Point(x: 1, y: 0)) == Point(x: 0, y: 3))
    try rotationHistory.commit(
        ValueSwapCommands.transform(in: rotationHistory.document, nodeID: rotatedID, newValue: .identity))
    #expect(
        rotationHistory.document.documentPoint(pathID: rotatedID, localPoint: Point(x: 1, y: 0)) == Point(x: 2, y: 0))
    try rotationHistory.undo()
    #expect(
        rotationHistory.document.documentPoint(pathID: rotatedID, localPoint: Point(x: 1, y: 0)) == Point(x: 0, y: 3))

    try rotationHistory.redo()
    try rotationHistory.undo()
    let counterBeforeIdentity = rotationHistory.globalCommandCounter
    let redoBeforeIdentity = rotationHistory.redoDepth
    let identity = try ValueSwapCommands.transform(
        in: rotationHistory.document, nodeID: rotatedID,
        newValue: Geometry.AffineTransform(a: 0, b: 1, c: -1, d: 0))
    #expect(try rotationHistory.commit(identity) == .identityElided)
    #expect(rotationHistory.globalCommandCounter == counterBeforeIdentity)
    #expect(rotationHistory.redoDepth == redoBeforeIdentity)

    var signedZero = Geometry.AffineTransform.identity
    signedZero.tx = -0.0
    var zeroHistory = try DeltaCommandHistory(
        document: documentWithPath(id: fixedID(6), transform: signedZero))
    var positiveZero = signedZero
    positiveZero.tx = 0.0
    let signedZeroCommand = try ValueSwapCommands.transform(
        in: zeroHistory.document, nodeID: fixedID(6), newValue: positiveZero)
    #expect(!signedZeroCommand.isIdentity)
    #expect(try zeroHistory.commit(signedZeroCommand) == .committed)
    #expect(zeroHistory.globalCommandCounter == 1)
}

@Test
func testValueSwapClassesApplyStoredOldValuesWithoutMatrixInversion() throws {
    let pathID = fixedID(10)
    let textID = fixedID(11)
    let imageID = fixedID(12)
    let groupID = fixedID(13)
    let layerID = fixedID(14)
    let path = PathObject(id: pathID, segments: [lineSegment()])
    let text = TextObject(id: textID, text: "old", origin: Point(x: 3, y: 4))
    let image = ImageObject(
        id: imageID, frame: Rect(minX: 1, minY: 2, maxX: 4, maxY: 6), storage: .linked(relativePath: "a.png"),
        pixelWidth: 1, pixelHeight: 1)
    let group = GroupNode(id: groupID, name: "old group", children: [.path(path), .text(text), .image(image)])
    let document = try EditorDocument(
        width: 100, height: 100, layers: [Layer(id: layerID, name: "L", nodes: [.group(group)])])
    var history = try DeltaCommandHistory(document: document)

    var style = path.style
    style.strokeWidth = 7
    let commands = [
        try ValueSwapCommands.pathStyle(in: history.document, nodeID: pathID, newValue: style),
        try ValueSwapCommands.nodeProperty(
            in: history.document, nodeID: groupID, newValue: .groupName("new group")),
        try ValueSwapCommands.textContent(in: history.document, nodeID: textID, newValue: "new"),
        try ValueSwapCommands.nodeProperty(
            in: history.document, nodeID: imageID,
            newValue: .imageFrame(Rect(minX: 10, minY: 20, maxX: 40, maxY: 60))),
        try ValueSwapCommands.layerVisibilityAndLock(
            in: history.document, layerID: layerID,
            newValue: LayerVisibilityAndLock(isVisible: false, isLocked: true)),
        try ValueSwapCommands.artboardProperties(
            in: history.document, newValue: ArtboardProperties(width: 200, height: 300, unit: .pixels)),
    ]
    for command in commands { try history.commit(command) }
    while history.canUndo { try history.undo() }
    #expect(try CanonicalDocumentEquality.equals(history.document, document))
}

@Test
func testVerify027CountEvictionAndReplayBoundFrozenExample() throws {
    var history = try DeltaCommandHistory(
        document: EditorDocument(width: 100, height: 100))
    for counter in 1...205 {
        try history.commit(try widthCommand(from: Double(99 + counter), to: Double(100 + counter), cost: 1_000))
    }
    #expect(history.undoDepth == 200)
    #expect(history.retainedCommandCounters == Array(6...205).map(UInt64.init))
    #expect(history.totalCostInBytes == 200_000)
    #expect(history.evictionCount == 5)
    #expect(history.headCheckpointCounter == 5)
    #expect(history.recoveryReplayCount(afterCommand: 17) == 12)
    #expect(history.checkpointCount == 9)
}

@Test
func testVerify027ByteEvictionFrozenExample() throws {
    var history = try DeltaCommandHistory(
        document: EditorDocument(width: 100, height: 100))
    for counter in 1...150 {
        try history.commit(try widthCommand(from: Double(99 + counter), to: Double(100 + counter), cost: 100_000))
    }
    let pin = try HistoryAssetPin(assetID: "image-60MB", byteCount: 60_000_000)
    try history.commit(try widthCommand(from: 250, to: 251, cost: 0, pins: [pin]))
    #expect(history.evictionCount == 79)
    #expect(history.undoDepth == 72)
    #expect(history.retainedCommandCounters == Array(80...151).map(UInt64.init))
    #expect(history.totalCostInBytes == 67_100_000)
    #expect(DeltaHistoryLimits.maximumCostInBytes - history.totalCostInBytes == 8_864)
}

@Test
func testVerify027FloorOutranksByteBudgetFrozenExample() throws {
    var history = try DeltaCommandHistory(
        document: EditorDocument(width: 100, height: 100))
    for counter in 1...9 {
        try history.commit(try widthCommand(from: Double(99 + counter), to: Double(100 + counter), cost: 1_000))
    }
    try history.commit(try widthCommand(from: 109, to: 110, cost: 70_000_000))
    #expect(history.undoDepth == 10)
    #expect(history.evictionCount == 0)
    #expect(history.totalCostInBytes == 70_009_000)
    #expect(history.totalCostInBytes - DeltaHistoryLimits.maximumCostInBytes == 2_900_136)
}

@Test
func testVerify027PinnedAssetChargeTransfersAtomicallyToNextOldestPin() throws {
    var history = try DeltaCommandHistory(
        document: EditorDocument(width: 100, height: 100))
    let pin = try HistoryAssetPin(assetID: "shared", byteCount: 4_096)
    let firstID = fixedUUID(300)
    try history.commit(try widthCommand(from: 100, to: 101, cost: 1, pins: [pin], commandID: firstID))
    for counter in 2...200 {
        try history.commit(try widthCommand(from: Double(99 + counter), to: Double(100 + counter), cost: 1))
    }
    let nextID = fixedUUID(301)
    try history.commit(try widthCommand(from: 300, to: 301, cost: 1, pins: [pin], commandID: nextID))
    #expect(history.assetCharge(for: firstID) == 0)
    #expect(history.assetCharge(for: nextID) == 4_096)
    #expect(history.totalCostInBytes == 4_296)
    try history.undo()
    #expect(history.assetCharge(for: nextID) == 4_096)
    #expect(history.totalCostInBytes == 4_296)
}

@Test
func testVerify028RedoBranchAndCancelledGestureFrozenStateMachine() throws {
    var history = try DeltaCommandHistory(
        document: EditorDocument(width: 100, height: 100))
    try history.commit(try widthCommand(from: 100, to: 101, cost: 1))
    try history.commit(try widthCommand(from: 101, to: 102, cost: 1))
    try history.commit(try widthCommand(from: 102, to: 103, cost: 1))
    try history.undo()
    try history.undo()
    #expect(history.undoDepth == 1)
    #expect(history.redoDepth == 2)
    try history.commit(try widthCommand(from: 101, to: 104, cost: 1))
    #expect(history.undoDepth == 2)
    #expect(history.redoDepth == 0)

    try history.undo()
    try history.undo()
    #expect(history.undoDepth == 0)
    #expect(history.redoDepth == 2)
    try history.redo()
    try history.redo()
    #expect(history.undoDepth == 2)
    #expect(history.redoDepth == 0)
    #expect(history.document.width == 104)

    let gesturePath = PathObject(
        id: fixedID(390), segments: [lineSegment()])
    var cancelled = try DeltaCommandHistory(
        document: EditorDocument(
            width: 100, height: 100,
            layers: [Layer(name: "Gesture", nodes: [.path(gesturePath)])]))
    try cancelled.commit(try widthCommand(from: 100, to: 101, cost: 1))
    try cancelled.commit(try widthCommand(from: 101, to: 102, cost: 1))
    try cancelled.undo()
    let counter = cancelled.globalCommandCounter
    let gesture = try cancelled.beginTransformGesture(nodeID: gesturePath.id)
    try cancelled.updateTransformGesture(
        gesture, newValue: Geometry.AffineTransform(tx: 12, ty: -4))
    try cancelled.cancelDeltaGesture(gesture)
    #expect(cancelled.undoDepth == 1)
    #expect(cancelled.redoDepth == 1)
    #expect(cancelled.globalCommandCounter == counter)
    #expect(cancelled.document.path(id: gesturePath.id)?.transform == .identity)
    try cancelled.redo()
    #expect(cancelled.document.width == 102)
}

@Test
func testDeltaHistoryForcedInverseFailureRestoresNearestCheckpointAndReportsDiagnostic() throws {
    var history = try DeltaCommandHistory(
        document: EditorDocument(width: 100, height: 100))
    let oldBytes = try payloadBytes(100.0)
    let newBytes = try payloadBytes(200.0)
    let command = try DocumentCommand(
        commandID: fixedUUID(400), timestamp: Date(timeIntervalSince1970: 1), name: "Forced inverse failure",
        damageBounds: .full, costInBytes: 128, oldPayload: oldBytes, newPayload: newBytes,
        apply: { $0.width = 200 }, unapply: { _ in throw DeltaFixtureError.forcedInverseFailure })
    try history.commit(command)
    #expect(try history.undo() == .recoveredFromCheckpoint)
    #expect(history.document.width == 100)
    #expect(history.redoDepth == 1)
    #expect(history.lastDiagnostic?.operation == .undo)
    #expect(history.lastDiagnostic?.commandID == fixedUUID(400))
    #expect(history.lastDiagnostic?.restoredCheckpointCounter == 0)
    #expect(history.lastDiagnostic?.replayedCommandCount == 0)
    #expect(history.lastDiagnostic?.recoverySucceeded == true)
    #expect(try history.redo() == .applied)
    #expect(history.document.width == 200)
}

@Test
func testDeltaHistoryAtomicApplyDoesNotPartiallyMutate() throws {
    let document = try EditorDocument(width: 100, height: 100)
    var unchanged = document
    let invalid = try DocumentCommand(
        name: "Invalid atomic fixture", damageBounds: .full, costInBytes: 1,
        oldPayload: payloadBytes(100.0), newPayload: payloadBytes(200.0),
        apply: { $0.width = .nan }, unapply: { $0.width = 100 })
    #expect(throws: (any Error).self) { try invalid.apply(to: &unchanged) }
    #expect(try CanonicalDocumentEquality.equals(unchanged, document))

    var delta = try DeltaCommandHistory(document: document)
    let invalidSwap = try ValueSwapCommands.artboardProperties(
        in: delta.document, newValue: ArtboardProperties(width: 0, height: 100, unit: .points))
    #expect(throws: DocumentValidationError.artboardMagnitude) { try delta.commit(invalidSwap) }
    #expect(try CanonicalDocumentEquality.equals(delta.document, document))
    #expect(delta.globalCommandCounter == 0)
}

@Test
func testDeltaHistorySeededValueSwapRoundTripCorpus() throws {
    let seed: UInt64 = 0x0000_0000_A110_F00D
    let pathID = fixedID(500)
    let textID = fixedID(501)
    let layerID = fixedID(502)
    let path = PathObject(id: pathID, segments: [lineSegment()])
    let text = TextObject(id: textID, text: "seed", origin: Point(x: 10, y: 10))
    let initial = try EditorDocument(
        width: 640, height: 480, layers: [Layer(id: layerID, name: "L", nodes: [.path(path), .text(text)])])
    var history = try DeltaCommandHistory(document: initial)
    var states = [initial]
    var rng = DeltaLCG(state: seed)
    for index in 0..<128 {
        let command: DocumentCommand
        switch rng.next() % 5 {
        case 0:
            command = try ValueSwapCommands.transform(
                in: history.document, nodeID: pathID,
                newValue: Geometry.AffineTransform(tx: Double(rng.next() % 101), ty: Double(rng.next() % 101)))
        case 1:
            var style = history.document.path(id: pathID)!.style
            style.strokeWidth = Double((rng.next() % 20) + 1)
            command = try ValueSwapCommands.pathStyle(in: history.document, nodeID: pathID, newValue: style)
        case 2:
            command = try ValueSwapCommands.textContent(
                in: history.document, nodeID: textID, newValue: "text-\(rng.next())")
        case 3:
            command = try ValueSwapCommands.layerVisibilityAndLock(
                in: history.document, layerID: layerID,
                newValue: LayerVisibilityAndLock(
                    isVisible: rng.next().isMultiple(of: 2), isLocked: rng.next().isMultiple(of: 2)))
        default:
            command = try ValueSwapCommands.artboardProperties(
                in: history.document,
                newValue: ArtboardProperties(
                    width: Double((rng.next() % 900) + 100), height: Double((rng.next() % 900) + 100), unit: .points))
        }
        let result = try history.commit(command)
        if result == .committed { states.append(history.document) }
        if !(try CanonicalDocumentEquality.equals(history.document, states.last!)) {
            print("CORPUS_FAILURE kind=delta-history index=\(index) seed=0x00000000A110F00D phase=record")
            Issue.record("Delta history record mismatch")
        }
    }
    let final = states.last!
    for index in stride(from: states.count - 2, through: 0, by: -1) {
        try history.undo()
        if !(try CanonicalDocumentEquality.equals(history.document, states[index])) {
            print("CORPUS_FAILURE kind=delta-history index=\(index) seed=0x00000000A110F00D phase=unwind")
            Issue.record("Delta history unwind mismatch")
        }
    }
    #expect(try CanonicalDocumentEquality.equals(history.document, initial))
    for index in 1..<states.count {
        try history.redo()
        if !(try CanonicalDocumentEquality.equals(history.document, states[index])) {
            print("CORPUS_FAILURE kind=delta-history index=\(index) seed=0x00000000A110F00D phase=replay")
            Issue.record("Delta history replay mismatch")
        }
    }
    #expect(try CanonicalDocumentEquality.equals(history.document, final))
}

private struct DeltaLCG {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

private func widthCommand(
    from oldValue: Double, to newValue: Double, cost: Int, pins: [HistoryAssetPin] = [],
    commandID: UUID = UUID()
) throws -> DocumentCommand {
    try DocumentCommand(
        commandID: commandID, timestamp: Date(timeIntervalSince1970: Double(newValue)), name: "Width",
        damageBounds: .full, costInBytes: cost, pinnedAssets: pins, oldPayload: payloadBytes(oldValue),
        newPayload: payloadBytes(newValue), apply: { $0.width = newValue }, unapply: { $0.width = oldValue })
}

private func payloadBytes<Value: Encodable>(_ value: Value) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(value)
}

private func fixedID(_ value: Int) -> ObjectID { ObjectID(rawValue: fixedUUID(value)) }

private func fixedUUID(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", value))!
}

private func lineSegment() -> CubicBezier {
    CubicBezier(
        start: Point(x: 0, y: 0), control1: Point(x: 0, y: 0), control2: Point(x: 1, y: 0),
        end: Point(x: 1, y: 0))
}

private func documentWithPath(id: ObjectID, transform: Geometry.AffineTransform) throws -> EditorDocument {
    try EditorDocument(
        width: 100, height: 100,
        layers: [Layer(name: "L", nodes: [.path(PathObject(id: id, segments: [lineSegment()], transform: transform))])])
}
