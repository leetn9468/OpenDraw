import Darwin
import DocumentFormats
import DocumentModel
import Foundation
import Testing

private final class DescriptorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var descriptor: Int32 = -1

    func store(_ value: Int32) {
        lock.lock()
        descriptor = value
        lock.unlock()
    }

    func load() -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        return descriptor
    }
}

@Test func cleanupAfterPostCloseFaultDoesNotCloseReusedDescriptor() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let target = directory.appendingPathComponent("drawing.odraw")
    let sentinel = directory.appendingPathComponent("sentinel")
    #expect(FileManager.default.createFile(atPath: sentinel.path, contents: Data()))
    let box = DescriptorBox()

    #expect(throws: DurableWriteError.injected(.afterTemporarySync)) {
        try DurableFileWriter { stage in
            guard stage == .afterTemporarySync else { return }
            let descriptor = open(sentinel.path, O_WRONLY | O_APPEND)
            guard descriptor >= 0 else { throw DurableWriteError.systemCall("open-sentinel", errno) }
            box.store(descriptor)
            throw DurableWriteError.injected(stage)
        }.write(Data("payload".utf8), to: target, backup: false)
    }

    let descriptor = box.load()
    #expect(descriptor >= 0)
    defer { close(descriptor) }
    var byte: UInt8 = 0x5A
    #expect(Darwin.write(descriptor, &byte, 1) == 1)
}

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
