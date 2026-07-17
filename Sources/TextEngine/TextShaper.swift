import CoreGraphics
import CoreText
import EditorCore
import Foundation
import Geometry

public struct ShapedTextMetrics: Equatable, Sendable {
    public var glyphCount: Int
    public var width: Double
    public var ascent: Double
    public var descent: Double
}

public struct TextShaper: Sendable {
    public init() {}
    public func measure(_ text: String, fontName: String = "Helvetica", size: Double = 16) throws -> ShapedTextMetrics {
        guard size.isFinite, size > 0 else { throw EditorError.invalidValue("Font size must be positive") }
        let font = CTFontCreateWithName(fontName as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(
            CFAttributedStringCreate(nil, text as CFString, [kCTFontAttributeName: font] as CFDictionary)!)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else {
            throw EditorError.invariantViolation("Core Text returned an unexpected glyph-run representation")
        }
        return ShapedTextMetrics(
            glyphCount: runs.reduce(0) { $0 + CTRunGetGlyphCount($1) }, width: Double(width), ascent: Double(ascent),
            descent: Double(descent))
    }
    public func draw(
        _ text: String, fontName: String, size: Double, at point: Point, color: CGColor, in context: CGContext
    ) throws {
        guard size.isFinite, size > 0 else { throw EditorError.invalidValue("Font size must be positive") }
        let font = CTFontCreateWithName(fontName as CFString, size, nil)
        let attributes = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color] as CFDictionary
        let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, text as CFString, attributes)!)
        context.textPosition = CGPoint(x: point.x, y: point.y)
        CTLineDraw(line, context)
    }

    /// Conservative line ink in document coordinates. Typographic bounds cover
    /// advances/ascent/descent while Core Text image bounds cover glyph overhangs
    /// and fallback runs; callers add their own authoring/layout rectangle.
    public func conservativeBounds(
        _ text: String, fontName: String = "Helvetica", size: Double = 16,
        at point: Point
    ) throws -> Rect {
        guard size.isFinite, size > 0 else { throw EditorError.invalidValue("Font size must be positive") }
        let font = CTFontCreateWithName(fontName as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(
            CFAttributedStringCreate(nil, text as CFString, [kCTFontAttributeName: font] as CFDictionary)!)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        var result = Rect(
            minX: point.x, minY: point.y - Double(descent),
            maxX: point.x + width, maxY: point.y + Double(ascent))
        let image = CTLineGetImageBounds(line, nil)
        if !image.isNull, !image.isInfinite,
            [image.minX, image.minY, image.maxX, image.maxY].allSatisfy(\.isFinite)
        {
            result = result.union(
                Rect(
                    minX: point.x + image.minX, minY: point.y + image.minY,
                    maxX: point.x + image.maxX, maxY: point.y + image.maxY))
        }
        return result
    }
}
