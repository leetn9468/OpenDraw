import DocumentModel
import EditorCore
import Foundation

public struct GestureID: Hashable, Sendable {
    public let rawValue: UUID
    public init(rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

public struct DocumentChange: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case command(String)
        case undo(String)
        case redo(String)
        case saved
    }
    public let revision: UInt64
    public let kind: Kind
    public init(revision: UInt64, kind: Kind) {
        self.revision = revision
        self.kind = kind
    }
}

private final class ChangeBroadcaster: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<DocumentChange>.Continuation] = [:]
    func stream() -> AsyncStream<DocumentChange> {
        let id = UUID()
        return AsyncStream { continuation in
            lock.withLock { continuations[id] = continuation }
            continuation.onTermination = { [weak self] _ in self?.lock.withLock { self?.continuations[id] = nil } }
        }
    }
    func publish(_ change: DocumentChange) {
        let targets = lock.withLock { Array(continuations.values) }
        for target in targets {
            target.yield(change)
        }
    }
}

public struct DocumentCommand: Sendable {
    public let name: String
    private let mutation: @Sendable (inout EditorDocument) throws -> Void
    public init(name: String, mutation: @escaping @Sendable (inout EditorDocument) throws -> Void) {
        self.name = name
        self.mutation = mutation
    }
    public func apply(to document: inout EditorDocument) throws { try mutation(&document) }
}

public struct CommandHistory: Sendable {
    private struct Entry: Sendable {
        var name: String
        var document: EditorDocument
        var gestureID: GestureID?
    }
    public private(set) var document: EditorDocument
    private var undoStack: [Entry] = []
    private var redoStack: [Entry] = []
    public private(set) var currentRevision: UInt64 = 0
    public private(set) var savedRevision: UInt64 = 0
    private let broadcaster = ChangeBroadcaster()
    public let maximumEntries: Int
    public let maximumEstimatedBytes: Int
    public init(
        document: EditorDocument, maximumEntries: Int = 30,
        maximumEstimatedBytes: Int = DocumentLimits.maximumHistoryEstimatedBytes
    ) {
        self.document = document
        self.maximumEntries = min(30, max(1, maximumEntries))
        self.maximumEstimatedBytes = max(1, maximumEstimatedBytes)
    }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var undoName: String? { undoStack.last?.name }
    public var redoName: String? { redoStack.last?.name }
    public var undoDepth: Int { undoStack.count }
    public var estimatedMemoryBytes: Int {
        embeddedAssetBytes(in: document) + estimatedSnapshotBytes(document)
            + undoStack.reduce(0) { $0 + estimatedSnapshotBytes($1.document) }
            + redoStack.reduce(0) { $0 + estimatedSnapshotBytes($1.document) }
    }
    public var isDirty: Bool { currentRevision != savedRevision }
    public func changes() -> AsyncStream<DocumentChange> { broadcaster.stream() }
    public mutating func perform(_ command: DocumentCommand, gestureID: GestureID? = nil) throws {
        var candidate = document
        try command.apply(to: &candidate)
        try candidate.validate()
        undoStack.append(Entry(name: command.name, document: document, gestureID: gestureID))
        document = candidate
        redoStack.removeAll()
        trimUndoStack()
        advance(.command(command.name))
    }
    public mutating func coalesce(_ command: DocumentCommand, gestureID: GestureID) throws {
        guard let top = undoStack.last, top.gestureID == gestureID, top.name == command.name else {
            try perform(command, gestureID: gestureID)
            return
        }
        var candidate = document
        try command.apply(to: &candidate)
        try candidate.validate()
        document = candidate
        redoStack.removeAll()
        advance(.command(command.name))
    }
    public mutating func coalesce(_ command: DocumentCommand) throws { try perform(command) }
    public mutating func markSaved() {
        savedRevision = currentRevision
        broadcaster.publish(DocumentChange(revision: currentRevision, kind: .saved))
    }
    public mutating func undo() {
        guard let prior = undoStack.popLast() else { return }
        redoStack.append(Entry(name: prior.name, document: document, gestureID: prior.gestureID))
        document = prior.document
        advance(.undo(prior.name))
    }
    public mutating func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(Entry(name: next.name, document: document, gestureID: next.gestureID))
        document = next.document
        trimUndoStack()
        advance(.redo(next.name))
    }
    private mutating func advance(_ kind: DocumentChange.Kind) {
        currentRevision &+= 1
        broadcaster.publish(DocumentChange(revision: currentRevision, kind: kind))
    }
    private mutating func trimUndoStack() {
        if undoStack.count > maximumEntries { undoStack.removeFirst(undoStack.count - maximumEntries) }
        while undoStack.count > DocumentLimits.minimumHistoryEntriesUnderMemoryPressure,
            estimatedMemoryBytes > maximumEstimatedBytes
        { undoStack.removeFirst() }
    }
}

private func estimatedSnapshotBytes(_ document: EditorDocument) -> Int {
    512
        + document.layers.reduce(0) { total, layer in
            total + 256 + layer.name.utf8.count + layer.nodes.reduce(0) { $0 + estimatedNodeBytes($1) }
        }
}
private func estimatedNodeBytes(_ node: SceneNode) -> Int {
    switch node {
    case .path(let path): return 512 + path.path.subpaths.reduce(0) { $0 + $1.segments.count * 128 }
    case .text(let text): return 384 + text.text.utf8.count + text.fontName.utf8.count
    case .image: return 256
    case .group(let group):
        return 384 + group.name.utf8.count + group.children.reduce(0) { $0 + estimatedNodeBytes($1) }
    }
}
private func embeddedAssetBytes(in document: EditorDocument) -> Int {
    document.layers.reduce(0) { $0 + $1.nodes.reduce(0) { $0 + embeddedAssetBytes(in: $1) } }
}
private func embeddedAssetBytes(in node: SceneNode) -> Int {
    switch node {
    case .image(let image):
        if case .embedded(let data) = image.storage { return data.count }
        return 0
    case .group(let group): return group.children.reduce(0) { $0 + embeddedAssetBytes(in: $1) }
    default: return 0
    }
}

public enum UnsavedResolution: Sendable { case save, discard, cancel }
public struct UnsavedChangesCoordinator: Sendable {
    public init() {}
    public func resolve(
        isDirty: Bool, decision: @Sendable () async -> UnsavedResolution,
        save: @Sendable () async throws -> Void, operation: @Sendable () async throws -> Void
    ) async throws -> Bool {
        guard isDirty else {
            try await operation()
            return true
        }
        switch await decision() {
        case .save:
            try await save()
            try await operation()
            return true
        case .discard:
            try await operation()
            return true
        case .cancel: return false
        }
    }
    public func resolve(
        isDirty: Bool, decision: () -> UnsavedResolution, save: () throws -> Void, operation: () throws -> Void
    ) throws -> Bool {
        guard isDirty else {
            try operation()
            return true
        }
        switch decision() {
        case .save:
            try save()
            try operation()
            return true
        case .discard:
            try operation()
            return true
        case .cancel: return false
        }
    }
}
