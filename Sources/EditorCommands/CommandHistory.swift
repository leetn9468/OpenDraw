import DocumentModel
import EditorCore
import Foundation
import Geometry

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

public enum DocumentCommandError: Error, Equatable, Sendable {
    case inverseUnavailable
    case invalidCost
}

public enum DocumentCommandDamageBounds: Equatable, Sendable {
    case none
    case rect(Rect)
    case full
}

public enum HistoryAssetPinSource: Hashable, Sendable {
    case metadataOnly
    case approvedAssetStore
}

public struct HistoryAssetPin: Hashable, Sendable {
    public let assetID: String
    public let byteCount: Int
    public let source: HistoryAssetPinSource

    public init(
        assetID: String, byteCount: Int, source: HistoryAssetPinSource = .metadataOnly
    ) throws {
        guard byteCount >= 0 else { throw DocumentCommandError.invalidCost }
        self.assetID = assetID
        self.byteCount = byteCount
        self.source = source
    }

    public init(approvedAsset descriptor: ApprovedAssetDescriptor) throws {
        try self.init(
            assetID: descriptor.assetID, byteCount: descriptor.byteCount, source: .approvedAssetStore)
    }
}

private final class ReversibleCommandStorage: @unchecked Sendable {
    let forward: @Sendable (inout EditorDocument) throws -> Void
    let reverse: (@Sendable (inout EditorDocument) throws -> Void)?
    let forwardPreflight: (@Sendable (EditorDocument) throws -> Void)?
    let reversePreflight: (@Sendable (EditorDocument) throws -> Void)?

    init(
        forward: @escaping @Sendable (inout EditorDocument) throws -> Void,
        reverse: (@Sendable (inout EditorDocument) throws -> Void)?,
        forwardPreflight: (@Sendable (EditorDocument) throws -> Void)? = nil,
        reversePreflight: (@Sendable (EditorDocument) throws -> Void)? = nil
    ) {
        self.forward = forward
        self.reverse = reverse
        self.forwardPreflight = forwardPreflight
        self.reversePreflight = reversePreflight
    }
}

/// Atomic document mutation with immutable metadata and, for delta history,
/// record-time-captured inverse data. The legacy initializer deliberately has
/// no inverse and remains the snapshot history's production command surface.
public struct DocumentCommand: Sendable {
    public let commandID: UUID
    public let timestamp: Date
    public let name: String
    public let damageBounds: DocumentCommandDamageBounds
    public let costInBytes: Int
    public let pinnedAssets: [HistoryAssetPin]
    private let oldPayload: Data?
    private let newPayload: Data?
    private let storage: ReversibleCommandStorage
    private let isForward: Bool

    public init(name: String, mutation: @escaping @Sendable (inout EditorDocument) throws -> Void) {
        commandID = UUID()
        timestamp = Date()
        self.name = name
        damageBounds = .full
        costInBytes = 0
        pinnedAssets = []
        oldPayload = nil
        newPayload = nil
        storage = ReversibleCommandStorage(forward: mutation, reverse: nil)
        isForward = true
    }

    init(
        commandID: UUID, timestamp: Date, name: String, damageBounds: DocumentCommandDamageBounds,
        costInBytes: Int, pinnedAssets: [HistoryAssetPin], oldPayload: Data, newPayload: Data,
        validatedApply: @escaping @Sendable (inout EditorDocument) throws -> Void,
        validatedUnapply: @escaping @Sendable (inout EditorDocument) throws -> Void,
        applyPreflight: @escaping @Sendable (EditorDocument) throws -> Void,
        unapplyPreflight: @escaping @Sendable (EditorDocument) throws -> Void
    ) throws {
        guard costInBytes >= 0 else { throw DocumentCommandError.invalidCost }
        self.commandID = commandID
        self.timestamp = timestamp
        self.name = name
        self.damageBounds = damageBounds
        self.costInBytes = costInBytes
        self.pinnedAssets = pinnedAssets
        self.oldPayload = oldPayload
        self.newPayload = newPayload
        storage = ReversibleCommandStorage(
            forward: validatedApply, reverse: validatedUnapply, forwardPreflight: applyPreflight,
            reversePreflight: unapplyPreflight)
        isForward = true
    }

    public init(
        commandID: UUID = UUID(), timestamp: Date = Date(), name: String,
        damageBounds: DocumentCommandDamageBounds, costInBytes: Int,
        pinnedAssets: [HistoryAssetPin] = [], oldPayload: Data, newPayload: Data,
        apply: @escaping @Sendable (inout EditorDocument) throws -> Void,
        unapply: @escaping @Sendable (inout EditorDocument) throws -> Void
    ) throws {
        guard costInBytes >= 0 else { throw DocumentCommandError.invalidCost }
        self.commandID = commandID
        self.timestamp = timestamp
        self.name = name
        self.damageBounds = damageBounds
        self.costInBytes = costInBytes
        self.pinnedAssets = pinnedAssets
        self.oldPayload = oldPayload
        self.newPayload = newPayload
        storage = ReversibleCommandStorage(forward: apply, reverse: unapply)
        isForward = true
    }

    private init(copying command: DocumentCommand, isForward: Bool) {
        commandID = command.commandID
        timestamp = command.timestamp
        name = command.name
        damageBounds = command.damageBounds
        costInBytes = command.costInBytes
        pinnedAssets = command.pinnedAssets
        oldPayload = command.oldPayload
        newPayload = command.newPayload
        storage = command.storage
        self.isForward = isForward
    }

    public var isIdentity: Bool {
        guard let oldPayload, let newPayload else { return false }
        return oldPayload == newPayload
    }

    public var hasCapturedInverse: Bool { storage.reverse != nil }

    public func inverted() throws -> DocumentCommand {
        guard storage.reverse != nil else { throw DocumentCommandError.inverseUnavailable }
        return DocumentCommand(copying: self, isForward: !isForward)
    }

    /// Applies to a candidate, validates the complete result, then commits the
    /// candidate. A throw therefore cannot leave a partial document mutation.
    public func apply(to document: inout EditorDocument) throws {
        if isForward, let preflight = storage.forwardPreflight {
            try preflight(document)
            try storage.forward(&document)
            return
        }
        if !isForward, let preflight = storage.reversePreflight, let reverse = storage.reverse {
            try preflight(document)
            try reverse(&document)
            return
        }
        var candidate = document
        if isForward {
            try storage.forward(&candidate)
        } else if let reverse = storage.reverse {
            try reverse(&candidate)
        } else {
            throw DocumentCommandError.inverseUnavailable
        }
        try candidate.validate()
        document = candidate
    }
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
