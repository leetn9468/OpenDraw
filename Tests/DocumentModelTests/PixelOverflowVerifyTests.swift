import DocumentModel
import Testing

@Test func verify007PixelCountFrozenExamples() throws {
    #expect(DocumentLimits.maximumImagePixelCount == 67_108_864)
    #expect(try DocumentLimits.checkedPixelCount(width: 4096, height: 4096) == 16_777_216)
    #expect(throws: PixelCountError.budget) {
        try DocumentLimits.checkedPixelCount(width: 3_037_000_499, height: 3_037_000_499)
    }
    #expect(throws: PixelCountError.overflow) {
        try DocumentLimits.checkedPixelCount(width: 3_037_000_500, height: 3_037_000_500)
    }
    #expect(throws: PixelCountError.nonPositive) { try DocumentLimits.checkedPixelCount(width: 0, height: 10) }
    #expect(throws: PixelCountError.nonPositive) { try DocumentLimits.checkedPixelCount(width: -1, height: 10) }
}
