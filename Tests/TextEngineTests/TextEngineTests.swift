import Testing
import TextEngine

@Test func representativeUnicodeShapes() throws {
    let samples = ["Vector", "العربية", "देवनागरी", "漢字", "e\u{301}", "👩🏽‍💻"]
    for sample in samples {
        let metrics = try TextShaper().measure(sample)
        #expect(metrics.glyphCount > 0)
        #expect(metrics.width > 0)
    }
}
