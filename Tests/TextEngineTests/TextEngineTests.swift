import Geometry
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

@Test func conservativeBoundsUnionsTypographicAndFallbackGlyphInk() throws {
    let shaper = TextShaper()
    for (text, font) in [("Ag", "Helvetica"), ("Fallback 👩🏽‍💻", "OpenDraw-Definitely-Missing-Font")] {
        let origin = Point(x: 20, y: 40)
        let bounds = try shaper.conservativeBounds(text, fontName: font, size: 24, at: origin)
        #expect(bounds.minX <= origin.x)
        #expect(bounds.minY < origin.y)
        #expect(bounds.maxX > origin.x)
        #expect(bounds.maxY > origin.y)
    }
}
