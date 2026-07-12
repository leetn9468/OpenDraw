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
    try history.perform(DocumentCommand(name: "Draw rectangle") { $0.layers[0].nodes.append(.path(path)) })
    try history.perform(
        DocumentCommand(name: "Style") { document in
            _ = document.mutatePath(id: path.id) {
                $0.style.fill = SRGBColor(red: 0.2, green: 0.4, blue: 0.8)
                $0.style.strokeWidth = 4
                $0.style.opacity = 0.75
            }
        })
    try history.perform(
        DocumentCommand(name: "Transform") { document in
            _ = document.applyDocumentTransform(
                id: path.id, transform: TransformInteractions.rotation(about: Point(x: 70, y: 55), radians: .pi / 12))
        })
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
    #expect(svg.warnings.isEmpty)
}
