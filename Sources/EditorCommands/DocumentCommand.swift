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

final class ChangeBroadcaster: @unchecked Sendable {
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

/// Atomic document mutation with immutable metadata and record-time-captured
/// inverse data.
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
