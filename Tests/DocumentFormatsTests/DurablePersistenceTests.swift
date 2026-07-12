import DocumentFormats
import DocumentModel
import Foundation
import Testing

@Test func durableSaveKeepsBackupAndInterruptedPreRenameSaveKeepsOriginal() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("drawing.odraw")
    let codec = NativeDocumentCodec()
    var original = try EditorDocument.sample()
    original.width = 100
    var changed = original
    changed.width = 200
    try codec.saveAtomically(original, to: url)
    #expect(throws: DurableWriteError.self) {
        try codec.saveAtomically(
            changed, to: url,
            writer: DurableFileWriter { stage in
                if stage == .afterBackup { throw DurableWriteError.injected(stage) }
            })
    }
    #expect(try codec.load(from: url).width == 100)
    #expect(try codec.load(from: url.appendingPathExtension("bak")).width == 100)
    try codec.saveAtomically(changed, to: url)
    #expect(try codec.load(from: url).width == 200)
    #expect(try codec.load(from: url.appendingPathExtension("bak")).width == 100)
}

@Test func verify012AutosaveAndRecoveryPolicy() throws {
    #expect(RecoverySettings.defaultInterval == 60)
    #expect(RecoverySettings().interval > 0)
    #expect(throws: RecoverySettings.ValidationError.nonPositive) { try RecoverySettings(validating: 0) }
    #expect(throws: RecoverySettings.ValidationError.nonPositive) { try RecoverySettings(validating: -1) }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = RecoveryStore(directory: directory)
    var document = try EditorDocument.sample()
    document.width = 321
    try store.save(document, documentID: "untitled-1")
    #expect(try store.recover(documentID: "untitled-1", newerThan: nil)?.width == 321)
    try store.discard(documentID: "untitled-1")
    #expect(try store.recover(documentID: "untitled-1", newerThan: nil) == nil)
}
