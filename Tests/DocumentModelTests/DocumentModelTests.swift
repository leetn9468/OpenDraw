import DocumentModel
import EditorCommands
import EditorCore
import Foundation
import Geometry
import Testing

@Test func documentInvariants() {
    #expect(throws: (any Error).self) { try EditorDocument(width: 0, height: 10) }
    #expect(throws: (any Error).self) { try EditorDocument(width: 10, height: 10, layers: []) }
}

@Test func deltaRevisionDirtyAndChangeStreamSemantics() async throws {
    var history = try DeltaCommandHistory(
        document: EditorDocument(width: 100, height: 100))
    let stream = history.changes()
    for width in [110.0, 120.0, 130.0] {
        try history.commit(
            ValueSwapCommands.artboardProperties(
                in: history.document,
                newValue: ArtboardProperties(
                    width: width, height: history.document.height,
                    unit: history.document.unit)))
    }
    #expect(history.currentRevision == 3)
    #expect(history.isDirty)
    try history.undo()
    #expect(history.document.width == 120)
    try history.undo()
    #expect(history.document.width == 110)
    #expect(history.currentRevision == 5)
    var iterator = stream.makeAsyncIterator()
    #expect(
        await iterator.next()
            == DocumentChange(revision: 1, kind: .command("Artboard properties")))
    history.markSaved()
    #expect(!history.isDirty)
}

@Test func unsavedCoordinatorsAreIndependentAndCancelPreventsReplacement() throws {
    let first = UnsavedChangesCoordinator()
    let second = UnsavedChangesCoordinator()
    final class State: @unchecked Sendable {
        var operations = 0
        let lock = NSLock()
    }
    let state = State()
    let cancelled = try first.resolve(
        isDirty: true, decision: { .cancel }, save: {},
        operation: {
            state.lock.withLock { state.operations += 1 }
        })
    let completed = try second.resolve(
        isDirty: false, decision: { .cancel }, save: {},
        operation: {
            state.lock.withLock { state.operations += 1 }
        })
    #expect(!cancelled)
    #expect(completed)
    #expect(state.operations == 1)
}

@Test func checkpointHistorySharesEmbeddedAssetsAndHonorsMemorySafetyNet() throws {
    var bytes = Data(repeating: 0, count: 50 * 1_024 * 1_024)
    bytes.replaceSubrange(0..<8, with: [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
    let image = ImageObject(
        frame: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1), storage: .embedded(bytes), pixelWidth: 1,
        pixelHeight: 1)
    let document = try EditorDocument(
        width: 100, height: 100, layers: [Layer(name: "L", nodes: [.image(image)])])
    let originalAddress = bytes.withUnsafeBytes { Int(bitPattern: $0.baseAddress) }
    let store = ApprovedAssetStore()
    store.registerApproved(bytes)
    var history = try DeltaCommandHistory(document: document, assetStore: store)
    for value in 101...130 {
        try history.commit(
            ValueSwapCommands.artboardProperties(
                in: history.document,
                newValue: ArtboardProperties(
                    width: Double(value), height: history.document.height,
                    unit: history.document.unit)))
    }
    guard case .image(let stored) = history.document.layers[0].nodes[0], case .embedded(let storedData) = stored.storage
    else {
        Issue.record("Missing embedded image")
        return
    }
    #expect(storedData.withUnsafeBytes { Int(bitPattern: $0.baseAddress) } == originalAddress)
    #expect(history.undoDepth == 30)
    #expect(history.checkpointCount == 2)
    #expect(history.checkpointOnlyPinnedAssetBytes == 50 * 1_024 * 1_024)
    #expect(history.applyMemorySafetyNet() == 1)
    #expect(history.checkpointCount == 1)
    #expect(history.undoDepth == 30)
    #expect(store.contains(assetID: ApprovedAssetStore.assetID(for: bytes)))
}

@Test func advancedResourceInvariants() throws {
    let swatch = Swatch(name: "Blue", color: SRGBColor(red: 0, green: 0, blue: 1))
    let gradient = GradientResource(
        name: "Fade", kind: .linear, start: Point(x: 0, y: 0), end: Point(x: 10, y: 0),
        stops: [ColorStop(offset: 0, color: .black), ColorStop(offset: 1, color: .white)])
    let document = try EditorDocument(width: 100, height: 100, swatches: [swatch], gradients: [gradient])
    try document.validate()
    #expect(document.gradients[0].stops[0].offset == 0)
}
