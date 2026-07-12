import Geometry
import Testing

@Test func verify001AffineTransformFrozenExamples() throws {
    let rotation = AffineTransform(a: 0, b: 1, c: -1, d: 0)
    #expect(rotation.applying(to: Point(x: 2, y: 3)) == Point(x: -3, y: 2))
    let scale = AffineTransform(a: 2, d: 3)
    let translation = AffineTransform(tx: 5, ty: -1)
    let combined = scale.concatenating(translation)
    #expect(combined == AffineTransform(a: 2, b: 0, c: 0, d: 3, tx: 5, ty: -1))
    #expect(combined.applying(to: Point(x: 1, y: 1)) == Point(x: 7, y: 2))
    let shear = AffineTransform(a: 1, b: 0, c: 2, d: 1)
    #expect(shear.applying(to: Point(x: 3, y: 4)) == Point(x: 11, y: 4))
    #expect(try #require(shear.inverted()).applying(to: Point(x: 11, y: 4)) == Point(x: 3, y: 4))
    #expect(AffineTransform(a: 0, b: 0, c: 0, d: 3, tx: 1, ty: 2).inverted() == nil)
}
