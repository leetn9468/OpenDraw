import DocumentModel
import Foundation
import Geometry
import Testing

@Test func verify008DocumentLimitsFrozenExamples() throws {
    #expect(
        try EditorDocument(
            width: 640, height: 480,
            layers: [Layer(name: "L", nodes: [.text(TextObject(text: "", origin: .init(x: 999_999_999.5, y: 0)))])]
        ).layers.count == 1)
    #expect(throws: DocumentValidationError.coordinateMagnitude) {
        try EditorDocument(
            width: 640, height: 480,
            layers: [Layer(name: "L", nodes: [.text(TextObject(text: "", origin: .init(x: 1_000_000_001, y: 0)))])])
    }
    #expect(throws: DocumentValidationError.artboardMagnitude) { try EditorDocument(width: 1_000_001, height: 10) }
    #expect(
        try DocumentLimits.checkedAggregateAssetBytes(current: 400 * 1_024 * 1_024, adding: 100 * 1_024 * 1_024) == 500
            * 1_024 * 1_024)
    #expect(throws: DocumentValidationError.aggregateAssetBytes) {
        try DocumentLimits.checkedAggregateAssetBytes(current: 500 * 1_024 * 1_024, adding: 1)
    }
    #expect(throws: DocumentValidationError.assetByteOverflow) {
        try DocumentLimits.checkedAggregateAssetBytes(current: Int.max, adding: 1)
    }
}

@Test func verify008DirectAggregateAssetBoundaryFixtures() throws {
    let mib = 1_024 * 1_024
    let fullSize = 100 * mib
    let magic: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    var full = Data(repeating: 0, count: fullSize)
    full.replaceSubrange(0..<magic.count, with: magic)
    func node(_ data: Data) -> SceneNode {
        .image(
            ImageObject(
                frame: Geometry.Rect(minX: 0, minY: 0, maxX: 1, maxY: 1), storage: .embedded(data), pixelWidth: 1,
                pixelHeight: 1))
    }
    let acceptedNodes = (0..<5).map { _ in node(full) }
    let accepted = try EditorDocument(width: 10, height: 10, layers: [Layer(name: "Assets", nodes: acceptedNodes)])
    #expect(accepted.layers[0].nodes.count == 5)
    var almostFull = full
    almostFull.removeLast(7)
    let oneHeader = Data(magic)
    let overBudget = (0..<4).map { _ in node(full) } + [node(almostFull), node(oneHeader)]
    #expect(throws: DocumentValidationError.aggregateAssetBytes) {
        try EditorDocument(width: 10, height: 10, layers: [Layer(name: "Assets", nodes: overBudget)])
    }
}
