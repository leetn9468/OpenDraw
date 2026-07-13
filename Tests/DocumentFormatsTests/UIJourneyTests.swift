import DocumentFormats
import DocumentModel
import EditorCommands
import EditorCore
import EditorTools
import Foundation
import Geometry
import Testing

@Test func headlessUIJourneyCreateStyleTransformSaveReopenAndExport() throws {
    var history = CommandHistory(document: try EditorDocument(width: 640, height: 480))
    let path = try #require(ShapeFactory.rectangle(from: Point(x: 20, y: 20), to: Point(x: 120, y: 90)))
    let second = try #require(ShapeFactory.rectangle(from: Point(x: 180, y: 40), to: Point(x: 260, y: 120)))
    try history.perform(
        DocumentCommand(name: "Draw rectangles") {
            $0.layers[0].nodes.append(contentsOf: [.path(path), .path(second)])
        })
    #expect(SelectionTool().hitTest(history.document, pointer: Point(x: 30, y: 30), zoom: 1) == path.id)
    try history.perform(SceneCommands.moveAnchor(pathID: path.id, subpath: 0, segment: 0, delta: Point(x: 1, y: 1)))
    var pen = SmoothPenToolState()
    pen.addSmooth(Point(x: 300, y: 40), outgoing: Point(x: 310, y: 50))
    pen.addCorner(Point(x: 350, y: 80))
    #expect(pen.preview(to: Point(x: 360, y: 90)) != nil)
    #expect(pen.finish(close: false) != nil)
    #expect(SnapPolicy(gridSpacing: 10).snap(Point(x: 309, y: 41), zoom: 1) == Point(x: 310, y: 40))
    let artworkLayer = history.document.layers[0].id
    try history.perform(SceneCommands.group(layerID: artworkLayer, nodeIDs: [path.id, second.id]))
    let groupID = try #require(history.document.layers[0].nodes.first?.id)
    try history.perform(SceneCommands.ungroup(layerID: artworkLayer, groupID: groupID))
    try history.perform(SceneCommands.makeCompound(layerID: artworkLayer, pathIDs: [path.id, second.id]))
    let compoundID = try #require(history.document.layers[0].nodes.first?.id)
    try history.perform(SceneCommands.releaseCompound(layerID: artworkLayer, pathID: compoundID))
    let gradient = GradientResource(
        name: "Journey gradient", kind: .linear, start: Point(x: 20, y: 20), end: Point(x: 120, y: 90),
        stops: [ColorStop(offset: 0, color: .black), ColorStop(offset: 1, color: .white)])
    try history.perform(
        DocumentCommand(name: "Style") { document in
            document.gradients.append(gradient)
            _ = document.mutatePath(id: path.id) {
                $0.style.fill = SRGBColor(red: 0.2, green: 0.4, blue: 0.8)
                $0.style.fillGradientID = gradient.id
                $0.style.strokeWidth = 4
                $0.style.lineCap = .round
                $0.style.lineJoin = .bevel
                $0.style.miterLimit = 8
                $0.style.dash = [6, 2]
                $0.style.opacity = 0.75
            }
        })
    try history.perform(AlignmentCommands.align(nodeIDs: [path.id, second.id], axis: .left))
    try history.perform(
        DocumentCommand(name: "Transform") { document in
            _ = document.applyDocumentTransform(
                id: path.id, transform: TransformInteractions.rotation(about: Point(x: 70, y: 55), radians: .pi / 12))
        })
    let scaled = try #require(
        TransformInteractions.scale(
            bounds: Rect(minX: 0, minY: 0, maxX: 100, maxY: 100), handle: .bottomRight,
            displacement: Point(x: 20, y: 20), uniform: true, fromCenter: false))
    #expect(scaled.x == scaled.y)
    #expect(
        TransformInteractions.zoomAbout(
            screenPoint: Point(x: 100, y: 80), oldZoom: 1, newZoom: 2, oldPan: Point(x: 10, y: 20))
            == Point(x: -80, y: -40))
    try history.perform(
        DocumentCommand(name: "Layers, text, and images") { document in
            document.layers[0].name = "Artwork"
            document.layers[0].isVisible = true
            document.layers[0].isLocked = false
            document.layers.append(
                Layer(
                    name: "Placed content",
                    nodes: [
                        .text(TextObject(text: "OpenDraw", origin: Point(x: 40, y: 180), fontSize: 24)),
                        .image(
                            ImageObject(
                                frame: Rect(minX: 300, minY: 180, maxX: 380, maxY: 240),
                                storage: .linked(relativePath: "placed.png"), pixelWidth: 80, pixelHeight: 60)),
                    ]))
        })
    #expect(history.document.layers.count == 2)
    #expect(history.document.layers[1].nodes.count == 2)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("journey.odraw")
    try NativeDocumentCodec().saveAtomically(history.document, to: url)
    history.markSaved()
    let reopened = try NativeDocumentCodec().load(from: url)
    #expect(reopened == history.document)
    let svg = try SVGExporter().export(reopened)
    #expect(String(decoding: svg.data, as: UTF8.self).contains("<path"))
    #expect(svg.warnings.map(\.code) == ["SVG-IMAGE-OMITTED"])
}
