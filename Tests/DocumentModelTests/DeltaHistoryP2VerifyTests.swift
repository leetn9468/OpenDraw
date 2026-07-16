import DocumentModel
import EditorCommands
import EditorCore
import Foundation
import Geometry
import Testing

@Test
func testP2StructuralInsertClassesRoundTripAndRejectDuplicateWithoutRecording() throws {
    let layerID = p2ID(1)
    let original = try EditorDocument(width: 100, height: 100, layers: [Layer(id: layerID, name: "L")])
    var history = try DeltaCommandHistory(document: original)
    let path = PathObject(id: p2ID(2), segments: [p2Line()])
    let text = TextObject(id: p2ID(3), text: "P2", origin: Point(x: 2, y: 3))
    let image = ImageObject(
        id: p2ID(4), frame: Rect(minX: 0, minY: 0, maxX: 4, maxY: 4),
        storage: .linked(relativePath: "approved.png"), pixelWidth: 4, pixelHeight: 4)
    let pasted = [
        SceneNode.path(PathObject(id: p2ID(5), segments: [p2Line()])),
        SceneNode.text(TextObject(id: p2ID(6), text: "paste", origin: Point(x: 0, y: 0))),
    ]
    try history.commit(
        StructuralCommands.createShape(path, in: history.document, parent: .layer(layerID), at: 0))
    try history.commit(
        StructuralCommands.createText(text, in: history.document, parent: .layer(layerID), at: 1))
    try history.commit(
        StructuralCommands.createImage(image, in: history.document, parent: .layer(layerID), at: 2))
    try history.commit(
        StructuralCommands.paste(pasted, in: history.document, parent: .layer(layerID), at: 3))
    #expect(history.document.layers[0].nodes.map(\.id) == [p2ID(2), p2ID(3), p2ID(4), p2ID(5), p2ID(6)])
    while history.canUndo { try history.undo() }
    #expect(try CanonicalDocumentEquality.equals(history.document, original))

    let one = SceneNode.path(path)
    var duplicateHistory = try DeltaCommandHistory(
        document: EditorDocument(width: 100, height: 100, layers: [Layer(id: layerID, name: "L", nodes: [one])]))
    let before = try CanonicalDocumentEquality.bytes(for: duplicateHistory.document)
    let duplicate = try StructuralCommands.createShape(
        path, in: duplicateHistory.document, parent: .layer(layerID), at: 1)
    #expect(throws: DocumentValidationError.duplicateID) { try duplicateHistory.commit(duplicate) }
    #expect(duplicateHistory.globalCommandCounter == 0)
    #expect(try CanonicalDocumentEquality.bytes(for: duplicateHistory.document) == before)

    let unapprovedBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    let unapprovedStore = ApprovedAssetStore()
    #expect(throws: StructuralCommandError.assetNotApproved) {
        _ = try StructuralCommands.createImage(
            ImageObject(
                id: p2ID(7), frame: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1),
                storage: .embedded(unapprovedBytes), pixelWidth: 1, pixelHeight: 1),
            in: duplicateHistory.document, parent: .layer(layerID), at: 1, assetStore: unapprovedStore)
    }
    #expect(!unapprovedStore.contains(assetID: ApprovedAssetStore.assetID(for: unapprovedBytes)))
}

@Test
func testP2StructuralInsertPreflightsNodeAndLayerCeilingsBeforeMutation() throws {
    let layerID = p2ID(20)
    let nodes = (0..<DocumentLimits.maximumNodes).map {
        SceneNode.text(TextObject(id: p2ID(100_000 + $0), text: "", origin: Point(x: 0, y: 0)))
    }
    let maximumNodeDocument = try EditorDocument(
        width: 100, height: 100, layers: [Layer(id: layerID, name: "L", nodes: nodes)])
    var nodeHistory = try DeltaCommandHistory(document: maximumNodeDocument)
    let nodeOverflow = try StructuralCommands.createText(
        TextObject(id: p2ID(300_000), text: "overflow", origin: Point(x: 0, y: 0)), in: nodeHistory.document,
        parent: .layer(layerID), at: nodes.count)
    #expect(throws: DocumentValidationError.nodeCount) { try nodeHistory.commit(nodeOverflow) }
    #expect(nodeHistory.globalCommandCounter == 0)
    #expect(nodeHistory.document.layers[0].nodes.count == DocumentLimits.maximumNodes)

    let layers = (0..<DocumentLimits.maximumLayers).map { Layer(id: p2ID(400_000 + $0), name: "L\($0)") }
    let maximumLayerDocument = try EditorDocument(width: 100, height: 100, layers: layers)
    var layerHistory = try DeltaCommandHistory(document: maximumLayerDocument)
    let layerOverflow = try StructuralCommands.insertLayer(
        Layer(id: p2ID(500_000), name: "overflow"), in: layerHistory.document, at: layers.count)
    #expect(throws: DocumentValidationError.layerCount) { try layerHistory.commit(layerOverflow) }
    #expect(layerHistory.globalCommandCounter == 0)
    #expect(layerHistory.document.layers.count == DocumentLimits.maximumLayers)
}

@Test
func testVerify024ABCExactIndexAndPayloadRestoration() throws {
    let layerID = p2ID(30)
    let nodes = [31, 32, 33].map { SceneNode.path(PathObject(id: p2ID($0), segments: [p2Line()])) }
    let original = try EditorDocument(
        width: 100, height: 100, layers: [Layer(id: layerID, name: "L", nodes: nodes)])
    var history = try DeltaCommandHistory(document: original)
    try history.commit(StructuralCommands.delete(nodeIDs: [p2ID(32)], in: history.document))
    #expect(history.document.layers[0].nodes.map(\.id) == [p2ID(31), p2ID(33)])
    try history.undo()
    #expect(history.document.layers[0].nodes.map(\.id) == [p2ID(31), p2ID(32), p2ID(33)])
    #expect(history.document.layers[0].nodes[1] == nodes[1])
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
}

@Test
func testP2MultiDeleteIsOneCommandAndRestoresReverseRemovalOrder() throws {
    let layerID = p2ID(40)
    let nodes = [41, 42, 43, 44, 45].map { SceneNode.path(PathObject(id: p2ID($0), segments: [p2Line()])) }
    let original = try EditorDocument(
        width: 100, height: 100, layers: [Layer(id: layerID, name: "L", nodes: nodes)])
    var history = try DeltaCommandHistory(document: original)
    try history.commit(
        StructuralCommands.cut(nodeIDs: [p2ID(42), p2ID(44)], in: history.document))
    #expect(history.undoDepth == 1)
    #expect(history.document.layers[0].nodes.map(\.id) == [p2ID(41), p2ID(43), p2ID(45)])
    try history.undo()
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
}

@Test
func testVerify024EmptyGroupPersistsAndInverseRestoresIndexZero() throws {
    let child = SceneNode.path(PathObject(id: p2ID(51), segments: [p2Line()]))
    let group = GroupNode(id: p2ID(52), name: "G", children: [child])
    let original = try EditorDocument(
        width: 100, height: 100, layers: [Layer(id: p2ID(53), name: "L", nodes: [.group(group)])])
    var history = try DeltaCommandHistory(document: original)
    try history.commit(StructuralCommands.delete(nodeIDs: [p2ID(51)], in: history.document))
    guard case .group(let empty) = history.document.layers[0].nodes[0] else {
        Issue.record("Group was removed with its last child")
        return
    }
    #expect(empty.id == group.id)
    #expect(empty.children.isEmpty)
    try history.undo()
    guard case .group(let restored) = history.document.layers[0].nodes[0] else {
        Issue.record("Group was not restored")
        return
    }
    #expect(restored.children[0] == child)
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
}

@Test
func testVerify024ThreeMiBAssetSurvivesPressurePinnedAndSHA256RoundTrip() throws {
    let bytes = p2ThreeMiBPNG()
    #expect(bytes.count == 3 * 1_024 * 1_024)
    let store = ApprovedAssetStore()
    let descriptor = store.registerApproved(bytes)
    let image = ImageObject(
        id: p2ID(60), frame: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1),
        storage: .embedded(bytes), pixelWidth: 1, pixelHeight: 1)
    let layerID = p2ID(61)
    let original = try EditorDocument(
        width: 10, height: 10, layers: [Layer(id: layerID, name: "L", nodes: [.image(image)])])
    var history = try DeltaCommandHistory(
        document: original, assetStore: store)
    let deletion = try StructuralCommands.delete(
        nodeIDs: [image.id], in: history.document, assetStore: store)
    try history.commit(deletion)
    #expect(history.totalCostInBytes == deletion.costInBytes + bytes.count)
    #expect(store.historyPinCount(assetID: descriptor.assetID) == 1)
    #expect(store.evictUnpinned(toMaximumBytes: 0) == bytes.count)
    #expect(store.contains(assetID: descriptor.assetID))
    try history.undo()
    guard case .image(let restored) = history.document.layers[0].nodes[0],
        case .embedded(let restoredBytes) = restored.storage
    else {
        Issue.record("Embedded image was not restored")
        return
    }
    #expect(ApprovedAssetStore.assetID(for: restoredBytes) == descriptor.assetID)
    #expect(restoredBytes == bytes)
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
}

@Test
func testP2RealAssetChargeTransfersWhenOldestPinIsEvicted() throws {
    let bytes = p2ThreeMiBPNG()
    let store = ApprovedAssetStore()
    let descriptor = store.registerApproved(bytes)
    let image = ImageObject(
        id: p2ID(70), frame: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1),
        storage: .embedded(bytes), pixelWidth: 1, pixelHeight: 1)
    let layerID = p2ID(71)
    var history = try DeltaCommandHistory(
        document: EditorDocument(
            width: 100, height: 100, layers: [Layer(id: layerID, name: "L", nodes: [.image(image)])]), assetStore: store
    )
    let firstID = p2UUID(72)
    let laterID = p2UUID(73)
    try history.commit(
        StructuralCommands.delete(
            nodeIDs: [image.id], in: history.document, assetStore: store, commandID: firstID))
    try history.commit(
        StructuralCommands.insert(
            .image(image), in: history.document, parent: .layer(layerID), at: 0,
            assetStore: store, commandID: laterID))
    for index in 1...199 {
        try history.commit(try p2WidthCommand(from: Double(99 + index), to: Double(100 + index), cost: 1))
    }
    #expect(history.evictionCount == 1)
    #expect(history.assetCharge(for: firstID) == 0)
    #expect(history.assetCharge(for: laterID) == bytes.count)
    #expect(store.historyPinCount(assetID: descriptor.assetID) == 1)
    #expect(store.contains(assetID: descriptor.assetID))
}

@Test
func testP2LastRealPinReleaseAllowsEvictionAndCheckpointOnlyPinsStayOutsideB() throws {
    let bytes = p2ThreeMiBPNG()
    let store = ApprovedAssetStore()
    let descriptor = store.registerApproved(bytes)
    let image = ImageObject(
        id: p2ID(80), frame: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1),
        storage: .embedded(bytes), pixelWidth: 1, pixelHeight: 1)
    let layerID = p2ID(81)
    let original = try EditorDocument(
        width: 100, height: 100, layers: [Layer(id: layerID, name: "L", nodes: [.image(image)])])

    var checkpointOnly = try DeltaCommandHistory(
        document: original, assetStore: store)
    #expect(checkpointOnly.totalCostInBytes == 0)
    #expect(checkpointOnly.checkpointOnlyPinnedAssetBytes == bytes.count)
    #expect(store.checkpointPinCount(assetID: descriptor.assetID) == 1)
    #expect(store.evictUnpinned(toMaximumBytes: 0) == bytes.count)
    _ = checkpointOnly.applyMemorySafetyNet()

    var history = try DeltaCommandHistory(document: original, assetStore: store)
    try history.commit(
        StructuralCommands.delete(nodeIDs: [image.id], in: history.document, assetStore: store))
    for index in 1...200 {
        try history.commit(try p2WidthCommand(from: Double(99 + index), to: Double(100 + index), cost: 1))
    }
    #expect(history.evictionCount == 1)
    #expect(store.historyPinCount(assetID: descriptor.assetID) == 0)
    #expect(store.checkpointPinCount(assetID: descriptor.assetID) == 0)
    #expect(store.evictUnpinned(toMaximumBytes: 0) == 0)
    #expect(!store.contains(assetID: descriptor.assetID))
}

@Test
func testP2SafetyNetDropsPeriodicCheckpointsButPreservesFloorPins() throws {
    #expect(DocumentLimits.maximumRetainedBitmapPixels == 67_108_864)
    let bytes = Data(p2ThreeMiBPNG().prefix(1_024))
    let store = ApprovedAssetStore()
    let descriptor = store.registerApproved(bytes)
    let realPin = try HistoryAssetPin(approvedAsset: descriptor)
    var history = try DeltaCommandHistory(
        document: EditorDocument(width: 100, height: 100), assetStore: store)
    for index in 1...24 {
        try history.commit(try p2WidthCommand(from: Double(99 + index), to: Double(100 + index), cost: 1_000))
    }
    try history.commit(
        try p2WidthCommand(from: 124, to: 125, cost: 70_000_000, pins: [realPin]))
    #expect(history.undoDepth == 10)
    #expect(history.totalCostInBytes > DeltaHistoryLimits.maximumCostInBytes)
    #expect(history.periodicCheckpointCount > 0)
    #expect(store.historyPinCount(assetID: descriptor.assetID) == 1)
    #expect(history.applyMemorySafetyNet() > 0)
    #expect(history.periodicCheckpointCount == 0)
    #expect(history.undoDepth == DeltaHistoryLimits.minimumRetainedCommands)
    #expect(store.historyPinCount(assetID: descriptor.assetID) == 1)
    #expect(store.evictUnpinned(toMaximumBytes: 0) == bytes.count)
}

@Test
func testP2NodeLayerAndCrossParentReorderRoundTripAndIdentityElision() throws {
    let a = SceneNode.path(PathObject(id: p2ID(91), segments: [p2Line()]))
    let b = SceneNode.path(PathObject(id: p2ID(92), segments: [p2Line()]))
    let group = GroupNode(id: p2ID(93), name: "G", children: [a, b])
    let firstLayer = Layer(id: p2ID(94), name: "First", nodes: [.group(group)])
    let secondLayer = Layer(id: p2ID(95), name: "Second")
    let original = try EditorDocument(width: 100, height: 100, layers: [firstLayer, secondLayer])
    var history = try DeltaCommandHistory(document: original)
    try history.commit(
        StructuralCommands.reorderNode(
            in: history.document, nodeID: a.id, to: .group(group.id), at: 1))
    guard case .group(let reordered) = history.document.layers[0].nodes[0] else {
        Issue.record("Group missing after z-order change")
        return
    }
    #expect(reordered.children.map(\.id) == [b.id, a.id])
    try history.undo()
    let redoDepth = history.redoDepth
    let counter = history.globalCommandCounter
    let identity = try StructuralCommands.reorderNode(
        in: history.document, nodeID: a.id, to: .group(group.id), at: 0)
    #expect(try history.commit(identity) == .identityElided)
    #expect(history.redoDepth == redoDepth)
    #expect(history.globalCommandCounter == counter)
    try history.redo()
    try history.undo()

    try history.commit(
        StructuralCommands.reorderNode(
            in: history.document, nodeID: b.id, to: .layer(secondLayer.id), at: 0))
    #expect(history.document.layers[1].nodes.map(\.id) == [b.id])
    try history.undo()
    #expect(try CanonicalDocumentEquality.equals(history.document, original))
    try history.redo()
    try history.commit(
        StructuralCommands.reorderLayer(in: history.document, layerID: firstLayer.id, to: 1))
    #expect(history.document.layers.map(\.id) == [secondLayer.id, firstLayer.id])
    try history.undo()
    #expect(history.document.layers.map(\.id) == [firstLayer.id, secondLayer.id])
}

@Test
func testP2SeededMixedCorpusCrossesEvictionAndCheckpointsWithExactUnwindReplay() throws {
    let seed: UInt64 = 0x0000_0000_A110_F00D
    let layerID = p2ID(600)
    let path = SceneNode.path(PathObject(id: p2ID(601), segments: [p2Line()]))
    let textID = p2ID(602)
    let text = SceneNode.text(TextObject(id: textID, text: "seed", origin: Point(x: 0, y: 0)))
    let initial = try EditorDocument(
        width: 640, height: 480, layers: [Layer(id: layerID, name: "L", nodes: [path, text])])
    var history = try DeltaCommandHistory(document: initial)

    for pair in 0..<20 {
        let node = SceneNode.path(PathObject(id: p2ID(700 + pair), segments: [p2Line()]))
        try history.commit(
            StructuralCommands.insert(node, in: history.document, parent: .layer(layerID), at: 2))
        try history.commit(StructuralCommands.delete(nodeIDs: [node.id], in: history.document))
    }
    #expect(try CanonicalDocumentEquality.equals(history.document, initial))

    var states = [initial]
    var rng = P2LCG(state: seed)
    var temporaryID: ObjectID?
    for index in 0..<200 {
        let command: DocumentCommand
        switch index % 4 {
        case 0:
            command = try ValueSwapCommands.textContent(
                in: history.document, nodeID: textID, newValue: "mixed-\(rng.next())")
        case 1:
            let nodeID = p2ID(10_000 + index)
            temporaryID = nodeID
            let node = SceneNode.path(PathObject(id: nodeID, segments: [p2Line()]))
            command = try StructuralCommands.insert(
                node, in: history.document, parent: .layer(layerID), at: history.document.layers[0].nodes.count)
        case 2:
            command = try StructuralCommands.reorderNode(
                in: history.document, nodeID: temporaryID!, to: .layer(layerID), at: 0)
        default:
            command = try StructuralCommands.delete(nodeIDs: [temporaryID!], in: history.document)
        }
        #expect(try history.commit(command) == .committed)
        states.append(history.document)
        if !(try CanonicalDocumentEquality.equals(history.document, states.last!)) {
            print("CORPUS_FAILURE kind=delta-history-p2 index=\(index) seed=0x00000000A110F00D phase=record")
            Issue.record("P2 mixed corpus record mismatch")
        }
    }
    #expect(history.evictionCount == 40)
    #expect(history.undoDepth == DeltaHistoryLimits.maximumCommandCount)
    #expect(history.checkpointCount == DeltaHistoryLimits.maximumCheckpointCount)
    for index in stride(from: states.count - 2, through: 0, by: -1) {
        try history.undo()
        if !(try CanonicalDocumentEquality.equals(history.document, states[index])) {
            print("CORPUS_FAILURE kind=delta-history-p2 index=\(index) seed=0x00000000A110F00D phase=unwind")
            Issue.record("P2 mixed corpus unwind mismatch")
        }
    }
    #expect(try CanonicalDocumentEquality.equals(history.document, initial))
    for index in 1..<states.count {
        try history.redo()
        if !(try CanonicalDocumentEquality.equals(history.document, states[index])) {
            print("CORPUS_FAILURE kind=delta-history-p2 index=\(index) seed=0x00000000A110F00D phase=replay")
            Issue.record("P2 mixed corpus replay mismatch")
        }
    }
    #expect(try CanonicalDocumentEquality.equals(history.document, states.last!))
}

private struct P2LCG {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

private func p2WidthCommand(
    from oldValue: Double, to newValue: Double, cost: Int, pins: [HistoryAssetPin] = []
) throws -> DocumentCommand {
    try DocumentCommand(
        name: "P2 width", damageBounds: .full, costInBytes: cost, pinnedAssets: pins,
        oldPayload: p2Payload(oldValue), newPayload: p2Payload(newValue),
        apply: { $0.width = newValue }, unapply: { $0.width = oldValue })
}

private func p2Payload<Value: Encodable>(_ value: Value) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(value)
}

private func p2ThreeMiBPNG() -> Data {
    var data = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )!
    data.append(Data(count: 3 * 1_024 * 1_024 - data.count))
    return data
}

private func p2Line() -> CubicBezier {
    CubicBezier(
        start: Point(x: 0, y: 0), control1: Point(x: 0, y: 0),
        control2: Point(x: 1, y: 0), end: Point(x: 1, y: 0))
}

private func p2ID(_ value: Int) -> ObjectID { ObjectID(rawValue: p2UUID(value)) }

private func p2UUID(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0001-%012X", value))!
}
