import Darwin
import DocumentModel
import Foundation

public enum DurableWriteStage: Sendable, Equatable { case afterTemporarySync, afterBackup, afterRename }
public enum DurableWriteError: Error, Equatable {
    case injected(DurableWriteStage)
    case systemCall(String, Int32)
}

public struct DurableFileWriter: Sendable {
    public var fault: (@Sendable (DurableWriteStage) throws -> Void)?
    public init(fault: (@Sendable (DurableWriteStage) throws -> Void)? = nil) { self.fault = fault }
    public func write(_ data: Data, to url: URL, backup: Bool = true) throws {
        let fm = FileManager.default
        let directory = url.deletingLastPathComponent()
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let temporary = directory.appendingPathComponent(".\(url.lastPathComponent).\(UUID().uuidString).tmp")
        let descriptor = open(temporary.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw DurableWriteError.systemCall("open", errno) }
        do {
            try data.withUnsafeBytes { bytes in
                var offset = 0
                while offset < bytes.count {
                    let count = Darwin.write(descriptor, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                    guard count > 0 else { throw DurableWriteError.systemCall("write", errno) }
                    offset += count
                }
            }
            guard fcntl(descriptor, F_FULLFSYNC) == 0 || fsync(descriptor) == 0 else {
                throw DurableWriteError.systemCall("fsync", errno)
            }
            guard close(descriptor) == 0 else { throw DurableWriteError.systemCall("close", errno) }
            try fault?(.afterTemporarySync)
            if backup, fm.fileExists(atPath: url.path) {
                let backupURL = url.appendingPathExtension("bak")
                try? fm.removeItem(at: backupURL)
                try fm.copyItem(at: url, to: backupURL)
                try fault?(.afterBackup)
            }
            if rename(temporary.path, url.path) != 0 { throw DurableWriteError.systemCall("rename", errno) }
            try fault?(.afterRename)
            let directoryFD = open(directory.path, O_RDONLY)
            guard directoryFD >= 0 else { throw DurableWriteError.systemCall("open-directory", errno) }
            defer { close(directoryFD) }
            guard fsync(directoryFD) == 0 else { throw DurableWriteError.systemCall("fsync-directory", errno) }
        } catch {
            close(descriptor)
            try? fm.removeItem(at: temporary)
            throw error
        }
    }
}

public struct RecoverySettings: Sendable, Equatable {
    public enum ValidationError: Error, Equatable { case nonPositive }
    public static let defaultInterval: TimeInterval = 60
    public var interval: TimeInterval
    public init(interval: TimeInterval = Self.defaultInterval) {
        precondition(interval > 0 && interval.isFinite)
        self.interval = interval
    }
    public init(validating interval: TimeInterval) throws {
        guard interval > 0, interval.isFinite else { throw ValidationError.nonPositive }
        self.interval = interval
    }
}

public struct RecoveryStore: Sendable {
    public let directory: URL
    private let writer: DurableFileWriter
    public init(directory: URL, writer: DurableFileWriter = DurableFileWriter()) {
        self.directory = directory
        self.writer = writer
    }
    public static func applicationSupport() throws -> RecoveryStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        return RecoveryStore(directory: base.appendingPathComponent("OpenDraw/Recovery", isDirectory: true))
    }
    public func url(for documentID: String) -> URL {
        directory.appendingPathComponent(
            documentID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "document"
        )
        .appendingPathExtension("odraw-recovery")
    }
    public func save(_ document: EditorDocument, documentID: String) throws {
        try writer.write(try NativeDocumentCodec().encode(document), to: url(for: documentID), backup: false)
    }
    public func recover(documentID: String, newerThan original: URL?) throws -> EditorDocument? {
        let recovery = url(for: documentID)
        guard FileManager.default.fileExists(atPath: recovery.path) else { return nil }
        if let original, FileManager.default.fileExists(atPath: original.path) {
            let recoveryDate =
                try recovery.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                ?? .distantPast
            let originalDate =
                try original.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                ?? .distantFuture
            guard recoveryDate > originalDate else { return nil }
        }
        return try NativeDocumentCodec().load(from: recovery)
    }
    public func discard(documentID: String) throws { try FileManager.default.removeItem(at: url(for: documentID)) }
}
