import DocumentModel
import EditorCore
import Foundation
import Geometry
import Testing

private let validPNG = Data(
    base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!

@Test func strictValidationRejectsGeometryStyleAndReferences() throws {
    let badSegment = CubicBezier(
        start: Point(x: .nan, y: 0), control1: Point(x: 0, y: 0), control2: Point(x: 1, y: 1), end: Point(x: 1, y: 1))
    #expect(throws: DocumentValidationError.coordinateMagnitude) {
        try EditorDocument(
            width: 100, height: 100, layers: [Layer(name: "L", nodes: [.path(PathObject(segments: [badSegment]))])])
    }
    let dangling = ObjectID()
    let path = PathObject(segments: [], style: PathStyle(fillSwatchID: dangling))
    #expect(throws: DocumentValidationError.danglingResource) {
        try EditorDocument(width: 100, height: 100, layers: [Layer(name: "L", nodes: [.path(path)])])
    }
    let dashed = PathObject(segments: [], style: PathStyle(dash: [0, 0]))
    #expect(throws: DocumentValidationError.invalidStyle) {
        try EditorDocument(width: 100, height: 100, layers: [Layer(name: "L", nodes: [.path(dashed)])])
    }
    let gradient = GradientResource(
        name: "Bad", kind: .linear, start: Point(x: 0, y: 0), end: Point(x: 1, y: 1),
        stops: [ColorStop(offset: 1, color: .white), ColorStop(offset: 0, color: .black)])
    #expect(throws: DocumentValidationError.invalidGradient) {
        try EditorDocument(width: 100, height: 100, gradients: [gradient])
    }
}

@Test func strictValidationEnforcesGlobalIDsAndImageStructure() throws {
    let duplicate = ObjectID()
    let path = PathObject(id: duplicate, segments: [])
    let layer = Layer(id: duplicate, name: "L", nodes: [.path(path)])
    #expect(throws: DocumentValidationError.duplicateID) {
        try EditorDocument(width: 100, height: 100, layers: [layer])
    }
    let malformed = ImageObject(
        frame: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1), storage: .embedded(Data([1, 2, 3])), pixelWidth: 1,
        pixelHeight: 1)
    #expect(throws: DocumentValidationError.invalidImage) {
        try EditorDocument(width: 100, height: 100, layers: [Layer(name: "L", nodes: [.image(malformed)])])
    }
    let valid = ImageObject(
        frame: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1), storage: .embedded(validPNG), pixelWidth: 1, pixelHeight: 1)
    #expect(
        try EditorDocument(width: 100, height: 100, layers: [Layer(name: "L", nodes: [.image(valid)])]).layers.count
            == 1)
}

@Test func strictValidationPinsNodeCountCeiling() throws {
    let nodes = (0..<DocumentLimits.maximumNodes).map {
        SceneNode.text(TextObject(text: "", origin: Point(x: Double($0 % 100), y: 0)))
    }
    #expect(
        try EditorDocument(width: 100, height: 100, layers: [Layer(name: "L", nodes: nodes)]).layers[0].nodes.count
            == 100_000)
    var tooMany = nodes
    tooMany.append(.text(TextObject(text: "", origin: Point(x: 0, y: 0))))
    #expect(throws: DocumentValidationError.nodeCount) {
        try EditorDocument(width: 100, height: 100, layers: [Layer(name: "L", nodes: tooMany)])
    }
}
