import DocumentFormats
import DocumentModel
import EditorCommands
import EditorCore
import EditorTools
import Foundation
import Geometry
import Testing

@Test func headlessUIJourneyCreateStyleTransformSaveReopenAndExport() throws {
    var history = try DeltaCommandHistory(
        document: EditorDocument(width: 640, height: 480))
    let path = try #require(ShapeFactory.rectangle(from: Point(x: 20, y: 20), to: Point(x: 120, y: 90)))
    let second = try #require(ShapeFactory.rectangle(from: Point(x: 180, y: 40), to: Point(x: 260, y: 120)))
    let artworkLayer = history.document.layers[0].id
    try history.commit(
        StructuralCommands.paste(
            [.path(path), .path(second)], in: history.document,
            parent: .layer(artworkLayer), at: 0))
    #expect(SelectionTool().hitTest(history.document, pointer: Point(x: 30, y: 30), zoom: 1) == path.id)
    let anchor = PathAnchorLocation(pathID: path.id, anchorIndex: 0)
    let slice = try AnchorGeometryCommands.slice(in: history.document, at: anchor)
    try history.commit(
        AnchorGeometryCommands.setSlice(
            in: history.document, at: anchor,
            newValue: slice.translated(dx: 1, dy: 1)))
    var pen = SmoothPenToolState()
    pen.addSmooth(Point(x: 300, y: 40), outgoing: Point(x: 310, y: 50))
    pen.addCorner(Point(x: 350, y: 80))
    #expect(pen.preview(to: Point(x: 360, y: 90)) != nil)
    #expect(pen.finish(close: false) != nil)
    #expect(SnapPolicy(gridSpacing: 10).snap(Point(x: 309, y: 41), zoom: 1) == Point(x: 310, y: 40))
    try history.commit(
        CompositeSceneCommands.group(
            in: history.document, nodeIDs: [path.id, second.id]))
    let groupID = try #require(history.document.layers[0].nodes.first?.id)
    try history.commit(
        CompositeSceneCommands.ungroup(
            in: history.document, groupID: groupID))
    try history.commit(
        CompositeSceneCommands.makeCompound(
            in: history.document, pathIDs: [path.id, second.id]))
    let compoundID = try #require(history.document.layers[0].nodes.first?.id)
    try history.commit(
        CompositeSceneCommands.releaseCompound(
            in: history.document, pathID: compoundID,
            releasedIDs: [path.id, second.id]))
    let gradient = GradientResource(
        name: "Journey gradient", kind: .linear, start: Point(x: 20, y: 20), end: Point(x: 120, y: 90),
        stops: [ColorStop(offset: 0, color: .black), ColorStop(offset: 1, color: .white)])
    var styled = history.document
    let insertGradient = try ResourceCommands.insertGradient(
        gradient, in: styled, at: styled.gradients.count)
    try insertGradient.apply(to: &styled)
    var style = try #require(styled.path(id: path.id)?.style)
    style.fill = SRGBColor(red: 0.2, green: 0.4, blue: 0.8)
    style.fillGradientID = gradient.id
    style.strokeWidth = 4
    style.lineCap = .round
    style.lineJoin = .bevel
    style.miterLimit = 8
    style.dash = [6, 2]
    style.opacity = 0.75
    try history.commit(
        CompositeCommands.ordered(
            name: "Style",
            children: [
                insertGradient,
                try ValueSwapCommands.pathStyle(
                    in: styled, nodeID: path.id, newValue: style),
            ]))
    try history.commit(
        CompositeSceneCommands.align(
            in: history.document, nodeIDs: [path.id, second.id],
            axis: .left))
    try history.commit(
        CompositeSceneCommands.documentTransform(
            in: history.document, nodeIDs: [path.id],
            transform: TransformInteractions.rotation(
                about: Point(x: 70, y: 55), radians: .pi / 12)))
    let scaled = try #require(
        TransformInteractions.scale(
            bounds: Rect(minX: 0, minY: 0, maxX: 100, maxY: 100), handle: .bottomRight,
            displacement: Point(x: 20, y: 20), uniform: true, fromCenter: false))
    #expect(scaled.x == scaled.y)
    #expect(
        TransformInteractions.zoomAbout(
            screenPoint: Point(x: 100, y: 80), oldZoom: 1, newZoom: 2, oldPan: Point(x: 10, y: 20))
            == Point(x: -80, y: -40))
    try history.commit(
        ValueSwapCommands.layerName(
            in: history.document, layerID: artworkLayer, newValue: "Artwork"))
    let text = TextObject(
        text: "OpenDraw", origin: Point(x: 40, y: 180), fontSize: 24)
    let image = ImageObject(
        frame: Rect(minX: 300, minY: 180, maxX: 380, maxY: 240),
        storage: .linked(relativePath: "placed.png"), pixelWidth: 80,
        pixelHeight: 60)
    try history.commit(
        StructuralCommands.insertLayer(
            Layer(
                name: "Placed content",
                nodes: [.text(text), .image(image)]),
            in: history.document, at: 1))
    #expect(history.document.layers.count == 2)
    #expect(history.document.layers[1].nodes.count == 2)
    for index in 0..<35 {
        try history.commit(
            ValueSwapCommands.textContent(
                in: history.document, nodeID: text.id,
                newValue: "OpenDraw \(index)"))
    }
    let deepUndoCount = history.undoDepth
    #expect(deepUndoCount > 30)
    for _ in 0..<31 { try history.undo() }
    #expect(history.redoDepth == 31)
    #expect(history.canUndo)
    for _ in 0..<31 { try history.redo() }
    #expect(history.undoDepth == deepUndoCount)
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
