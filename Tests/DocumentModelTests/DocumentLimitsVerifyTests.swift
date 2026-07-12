import DocumentModel
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
