import DocumentFormats
import Testing

@Test func verify010SVGLengthFrozenExamples() throws {
    let parser = SVGLengthParser()
    #expect(try parser.parse("1in") == 96)
    #expect(abs(try parser.parse("2.54cm") - 96) < 1e-9)
    #expect(abs(try parser.parse("25.4mm") - 96) < 1e-9)
    #expect(abs(try parser.parse("72pt") - 96) < 1e-9)
    #expect(try parser.parse("6pc") == 96)
    #expect(try parser.parse("10PX") == 10)
    #expect(try parser.parse("12.5") == 12.5)
    #expect(try parser.parse("0mm") == 0)
    for invalid in ["10%", "2em", "1q", "nan", "inf"] {
        #expect(throws: (any Error).self) { try parser.parse(invalid) }
    }
}
