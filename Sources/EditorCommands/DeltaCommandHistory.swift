import DocumentModel
import EditorCore
import Foundation
import Geometry

public enum DeltaHistoryLimits {
    public static let maximumCommandCount = 200
    public static let maximumCostInBytes = 67_108_864
    public static let minimumRetainedCommands = 10
    public static let checkpointInterval: UInt64 = 25
    public static let maximumCheckpointCount = 9
}

public enum DeltaHistoryError: Error, Equatable, Sendable {
    case featureDisabled
    case inverseRequired
    case costOverflow
    case counterOverflow
    case conflictingAssetPin(String)
    case recoveryFailed
}

public enum DeltaGestureError: Error, Equatable, Sendable {
    case gestureNotFound
    case gestureKindMismatch
}

public enum DeltaCommitResult: Equatable, Sendable {
    case committed
    case identityElided
}

public enum DeltaHistoryOperationResult: Equatable, Sendable {
    case applied
    case recoveredFromCheckpoint
    case noOperation
}

public struct DeltaHistoryDiagnostic: Equatable, Sendable {
    public enum Operation: String, Equatable, Sendable { case commit, undo, redo }

    public let operation: Operation
    public let commandID: UUID
    public let commandName: String
    public let underlyingError: String
    public let restoredCheckpointCounter: UInt64?
    public let replayedCommandCount: Int
    public let recoverySucceeded: Bool
}

public struct DeltaCommandHistory: Sendable {
    private struct Entry: Sendable {
        var command: DocumentCommand
        var inverse: DocumentCommand
        var counter: UInt64
    }

    private struct Checkpoint: Sendable {
        var counter: UInt64
        var document: EditorDocument
        var lineage: [UUID]
        var assetIDs: Set<String>
    }

    private enum ActiveGesture: Sendable {
        case transform(nodeID: ObjectID, preState: Geometry.AffineTransform)
        case anchor(location: PathAnchorLocation, preState: PathAnchorSlice)
    }

    public private(set) var document: EditorDocument
    public private(set) var globalCommandCounter: UInt64 = 0
    public private(set) var evictionCount = 0
    public private(set) var lastDiagnostic: DeltaHistoryDiagnostic?

    private let featureFlag: DeltaHistoryFeatureFlag
    private var undoStack: [Entry] = []
    private var redoStack: [Entry] = []
    private var headCheckpoint: Checkpoint
    private var periodicCheckpoints: [Checkpoint] = []
    private var activeGestures: [GestureID: ActiveGesture] = [:]
    private let assetStore: ApprovedAssetStore?

    public init(
        document: EditorDocument, featureFlag: DeltaHistoryFeatureFlag = .environment(),
        assetStore: ApprovedAssetStore? = nil
    ) throws {
        guard featureFlag.isEnabled else { throw DeltaHistoryError.featureDisabled }
        try document.validate()
        self.document = document
        self.featureFlag = featureFlag
        self.assetStore = assetStore
        headCheckpoint = Checkpoint(
            counter: 0, document: document, lineage: [],
            assetIDs: checkpointAssetIDs(in: document, assetStore: assetStore))
        syncAssetStore()
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var undoDepth: Int { undoStack.count }
    public var redoDepth: Int { redoStack.count }
    public var checkpointCount: Int { 1 + periodicCheckpoints.count }
    public var headCheckpointCounter: UInt64 { headCheckpoint.counter }
    public var retainedCommandCounters: [UInt64] { undoStack.map(\.counter) }
    public var totalCostInBytes: Int { (try? costBreakdown(for: retainedEntries).total) ?? Int.max }
    public var periodicCheckpointCount: Int { periodicCheckpoints.count }
    public var activeGestureCount: Int { activeGestures.count }
    public var checkpointOnlyPinnedAssetBytes: Int {
        guard let assetStore else { return 0 }
        let historyIDs = Set(
            retainedEntries.flatMap { entry in
                entry.command.pinnedAssets.filter { $0.source == .approvedAssetStore }.map(\.assetID)
            })
        let checkpointIDs = checkpointAssetPinCounts().keys.filter { !historyIDs.contains($0) }
        return checkpointIDs.reduce(0) { $0 + (assetStore.byteCount(assetID: $1) ?? 0) }
    }

    @discardableResult public mutating func commit(_ command: DocumentCommand) throws -> DeltaCommitResult {
        guard featureFlag.isEnabled else { throw DeltaHistoryError.featureDisabled }
        guard command.hasCapturedInverse else { throw DeltaHistoryError.inverseRequired }
        if command.isIdentity { return .identityElided }

        var candidate = self
        do {
            let result = try candidate.commitInPlace(command)
            self = candidate
            return result
        } catch let compositeError as CompositeCommandError {
            guard case .unwindFailed = compositeError else { throw compositeError }
            let original = self
            do {
                let recovery = try recoverDocument(for: undoStack)
                document = recovery.document
                lastDiagnostic = DeltaHistoryDiagnostic(
                    operation: .commit, commandID: command.commandID, commandName: command.name,
                    underlyingError: String(describing: compositeError),
                    restoredCheckpointCounter: recovery.checkpointCounter,
                    replayedCommandCount: recovery.replayCount, recoverySucceeded: true)
                syncAssetStore()
            } catch let recoveryError {
                self = original
                lastDiagnostic = DeltaHistoryDiagnostic(
                    operation: .commit, commandID: command.commandID, commandName: command.name,
                    underlyingError: "\(compositeError); recovery: \(recoveryError)",
                    restoredCheckpointCounter: nil, replayedCommandCount: 0,
                    recoverySucceeded: false)
                syncAssetStore()
                throw DeltaHistoryError.recoveryFailed
            }
            throw compositeError
        }
    }

    @discardableResult public mutating func undo() throws -> DeltaHistoryOperationResult {
        guard let entry = undoStack.last else { return .noOperation }
        let original = self
        do {
            try entry.inverse.apply(to: &document)
            undoStack.removeLast()
            redoStack.append(entry)
            lastDiagnostic = nil
            syncAssetStore()
            return .applied
        } catch {
            do {
                let target = Array(undoStack.dropLast())
                let recovery = try recoverDocument(for: target)
                document = recovery.document
                undoStack.removeLast()
                redoStack.append(entry)
                lastDiagnostic = DeltaHistoryDiagnostic(
                    operation: .undo, commandID: entry.command.commandID, commandName: entry.command.name,
                    underlyingError: String(describing: error), restoredCheckpointCounter: recovery.checkpointCounter,
                    replayedCommandCount: recovery.replayCount, recoverySucceeded: true)
                syncAssetStore()
                return .recoveredFromCheckpoint
            } catch let recoveryError {
                self = original
                lastDiagnostic = DeltaHistoryDiagnostic(
                    operation: .undo, commandID: entry.command.commandID, commandName: entry.command.name,
                    underlyingError: "\(error); recovery: \(recoveryError)", restoredCheckpointCounter: nil,
                    replayedCommandCount: 0, recoverySucceeded: false)
                syncAssetStore()
                throw DeltaHistoryError.recoveryFailed
            }
        }
    }

    @discardableResult public mutating func redo() throws -> DeltaHistoryOperationResult {
        guard let entry = redoStack.last else { return .noOperation }
        let original = self
        do {
            try entry.command.apply(to: &document)
            redoStack.removeLast()
            undoStack.append(entry)
            lastDiagnostic = nil
            syncAssetStore()
            return .applied
        } catch {
            do {
                let target = undoStack + [entry]
                let recovery = try recoverDocument(for: target)
                document = recovery.document
                redoStack.removeLast()
                undoStack.append(entry)
                lastDiagnostic = DeltaHistoryDiagnostic(
                    operation: .redo, commandID: entry.command.commandID, commandName: entry.command.name,
                    underlyingError: String(describing: error), restoredCheckpointCounter: recovery.checkpointCounter,
                    replayedCommandCount: recovery.replayCount, recoverySucceeded: true)
                syncAssetStore()
                return .recoveredFromCheckpoint
            } catch let recoveryError {
                self = original
                lastDiagnostic = DeltaHistoryDiagnostic(
                    operation: .redo, commandID: entry.command.commandID, commandName: entry.command.name,
                    underlyingError: "\(error); recovery: \(recoveryError)", restoredCheckpointCounter: nil,
                    replayedCommandCount: 0, recoverySucceeded: false)
                syncAssetStore()
                throw DeltaHistoryError.recoveryFailed
            }
        }
    }

    public mutating func beginGesture() -> GestureID { GestureID() }

    /// Cancellation has no commit boundary, so redo and the global counter are
    /// deliberately untouched under P-REDOCLEAR.
    public mutating func cancelGesture(_ gestureID: GestureID) { _ = gestureID }

    public mutating func beginTransformGesture(nodeID: ObjectID) throws -> GestureID {
        let slot = try StructuralCommands.slot(for: nodeID, in: document)
        let gestureID = GestureID()
        activeGestures[gestureID] = .transform(nodeID: nodeID, preState: deltaTransform(slot.node))
        return gestureID
    }

    public mutating func updateTransformGesture(
        _ gestureID: GestureID, newValue: Geometry.AffineTransform
    ) throws {
        guard case .transform(let nodeID, _)? = activeGestures[gestureID] else {
            throw activeGestures[gestureID] == nil
                ? DeltaGestureError.gestureNotFound : DeltaGestureError.gestureKindMismatch
        }
        let current = deltaTransform(try StructuralCommands.slot(for: nodeID, in: document).node)
        let command = try ValueSwapCommands.transform(
            in: document, nodeID: nodeID, oldValue: current, newValue: newValue)
        try command.apply(to: &document)
    }

    public mutating func beginAnchorGesture(at location: PathAnchorLocation) throws -> GestureID {
        let gestureID = GestureID()
        activeGestures[gestureID] = .anchor(
            location: location, preState: try AnchorGeometryCommands.slice(in: document, at: location))
        return gestureID
    }

    public mutating func updateAnchorGesture(
        _ gestureID: GestureID, newValue: PathAnchorSlice
    ) throws {
        guard case .anchor(let location, _)? = activeGestures[gestureID] else {
            throw activeGestures[gestureID] == nil
                ? DeltaGestureError.gestureNotFound : DeltaGestureError.gestureKindMismatch
        }
        let current = try AnchorGeometryCommands.slice(in: document, at: location)
        let command = try AnchorGeometryCommands.setSlice(
            in: document, at: location, oldValue: current, newValue: newValue)
        try command.apply(to: &document)
    }

    /// Commits the first and last gesture states as one command. Intermediate
    /// rendered frames never enter either history stack or increment the
    /// global command counter.
    @discardableResult public mutating func endGesture(
        _ gestureID: GestureID
    ) throws -> DeltaCommitResult {
        guard let gesture = activeGestures[gestureID] else {
            throw DeltaGestureError.gestureNotFound
        }
        let command: DocumentCommand
        switch gesture {
        case .transform(let nodeID, let preState):
            let postState = deltaTransform(try StructuralCommands.slot(for: nodeID, in: document).node)
            command = try ValueSwapCommands.transform(
                in: document, nodeID: nodeID, oldValue: preState, newValue: postState)
        case .anchor(let location, let preState):
            let postState = try AnchorGeometryCommands.slice(in: document, at: location)
            command = try AnchorGeometryCommands.setSlice(
                in: document, at: location, oldValue: preState, newValue: postState)
        }
        let result = try commit(command)
        activeGestures.removeValue(forKey: gestureID)
        return result
    }

    /// Restores the pre-state without crossing a commit boundary. Redo and the
    /// monotone command counter therefore remain unchanged under P-REDOCLEAR.
    public mutating func cancelDeltaGesture(_ gestureID: GestureID) throws {
        guard let gesture = activeGestures[gestureID] else {
            throw DeltaGestureError.gestureNotFound
        }
        switch gesture {
        case .transform(let nodeID, let preState):
            let current = deltaTransform(try StructuralCommands.slot(for: nodeID, in: document).node)
            let command = try ValueSwapCommands.transform(
                in: document, nodeID: nodeID, oldValue: current, newValue: preState)
            try command.apply(to: &document)
        case .anchor(let location, let preState):
            let current = try AnchorGeometryCommands.slice(in: document, at: location)
            let command = try AnchorGeometryCommands.setSlice(
                in: document, at: location, oldValue: current, newValue: preState)
            try command.apply(to: &document)
        }
        activeGestures.removeValue(forKey: gestureID)
    }

    /// The Phase 5 emergency path preserves every retained command (including
    /// the M-floor entries and their real asset pins) while dropping periodic
    /// checkpoints. The head checkpoint remains the recovery boundary.
    @discardableResult public mutating func applyMemorySafetyNet() -> Int {
        let dropped = periodicCheckpoints.count
        periodicCheckpoints.removeAll()
        syncAssetStore()
        return dropped
    }

    public func assetCharge(for commandID: UUID) -> Int {
        guard let breakdown = try? costBreakdown(for: retainedEntries) else { return 0 }
        return breakdown.charges[commandID] ?? 0
    }

    public func recoveryReplayCount(afterCommand counter: UInt64) -> Int? {
        let target = undoStack.filter { $0.counter <= counter }
        return try? recoveryPlan(for: target).replay.count
    }

    private mutating func commitInPlace(_ command: DocumentCommand) throws -> DeltaCommitResult {
        let inverse = try command.inverted()
        let nextCounter = globalCommandCounter.addingReportingOverflow(1)
        guard !nextCounter.overflow else { throw DeltaHistoryError.counterOverflow }
        try command.apply(to: &document)
        globalCommandCounter = nextCounter.partialValue
        redoStack.removeAll()
        undoStack.append(Entry(command: command, inverse: inverse, counter: globalCommandCounter))
        pruneCheckpointsToCurrentLineage()
        if globalCommandCounter.isMultiple(of: DeltaHistoryLimits.checkpointInterval) {
            periodicCheckpoints.append(
                Checkpoint(
                    counter: globalCommandCounter, document: document,
                    lineage: undoStack.map { $0.command.commandID },
                    assetIDs: checkpointAssetIDs(in: document, assetStore: assetStore)))
        }
        try evictToBudgets()
        enforceCheckpointCeiling()
        lastDiagnostic = nil
        syncAssetStore()
        return .committed
    }

    private var retainedEntries: [Entry] { undoStack + redoStack.reversed() }

    private mutating func evictToBudgets() throws {
        while true {
            let breakdown = try costBreakdown(for: undoStack)
            let overCount = undoStack.count > DeltaHistoryLimits.maximumCommandCount
            let overBytes = breakdown.total > DeltaHistoryLimits.maximumCostInBytes
            guard overCount || overBytes, undoStack.count > DeltaHistoryLimits.minimumRetainedCommands else { return }
            let evicted = undoStack.removeFirst()
            try evicted.command.apply(to: &headCheckpoint.document)
            headCheckpoint.counter = evicted.counter
            headCheckpoint.assetIDs = checkpointAssetIDs(in: headCheckpoint.document, assetStore: assetStore)
            evictionCount += 1
            rebaseCheckpoints(afterEvicting: evicted.command.commandID)
            _ = try costBreakdown(for: undoStack)
        }
    }

    private mutating func rebaseCheckpoints(afterEvicting commandID: UUID) {
        periodicCheckpoints = periodicCheckpoints.compactMap { checkpoint in
            guard checkpoint.lineage.first == commandID else { return nil }
            var rebased = checkpoint
            rebased.lineage.removeFirst()
            guard rebased.counter > headCheckpoint.counter, !rebased.lineage.isEmpty else { return nil }
            return rebased
        }
    }

    private mutating func pruneCheckpointsToCurrentLineage() {
        let current = undoStack.map { $0.command.commandID }
        periodicCheckpoints.removeAll { !isPrefix($0.lineage, of: current) }
    }

    private mutating func enforceCheckpointCeiling() {
        periodicCheckpoints.removeAll { $0.counter <= headCheckpoint.counter || $0.lineage.isEmpty }
        let periodicLimit = DeltaHistoryLimits.maximumCheckpointCount - 1
        if periodicCheckpoints.count > periodicLimit {
            periodicCheckpoints.removeFirst(periodicCheckpoints.count - periodicLimit)
        }
    }

    private func costBreakdown(for entries: [Entry]) throws -> (total: Int, charges: [UUID: Int]) {
        var total = 0
        var charges: [UUID: Int] = [:]
        var chargedAssets: [String: Int] = [:]
        for entry in entries {
            total = try checkedAdd(total, entry.command.costInBytes)
            for pin in entry.command.pinnedAssets {
                if let existing = chargedAssets[pin.assetID] {
                    guard existing == pin.byteCount else { throw DeltaHistoryError.conflictingAssetPin(pin.assetID) }
                    continue
                }
                chargedAssets[pin.assetID] = pin.byteCount
                total = try checkedAdd(total, pin.byteCount)
                charges[entry.command.commandID, default: 0] = try checkedAdd(
                    charges[entry.command.commandID, default: 0], pin.byteCount)
            }
        }
        return (total, charges)
    }

    private func recoverDocument(for target: [Entry]) throws -> (
        document: EditorDocument, checkpointCounter: UInt64, replayCount: Int
    ) {
        let plan = try recoveryPlan(for: target)
        var recovered = plan.checkpoint.document
        for entry in plan.replay { try entry.command.apply(to: &recovered) }
        return (recovered, plan.checkpoint.counter, plan.replay.count)
    }

    private func recoveryPlan(for target: [Entry]) throws -> (checkpoint: Checkpoint, replay: [Entry]) {
        let targetLineage = target.map { $0.command.commandID }
        let candidates = [headCheckpoint] + periodicCheckpoints
        guard
            let checkpoint = candidates.filter({ isPrefix($0.lineage, of: targetLineage) }).max(by: {
                $0.lineage.count < $1.lineage.count
            })
        else { throw DeltaHistoryError.recoveryFailed }
        return (checkpoint, Array(target.dropFirst(checkpoint.lineage.count)))
    }

    private func syncAssetStore() {
        guard let assetStore else { return }
        var history: [String: Int] = [:]
        for entry in retainedEntries {
            for pin in entry.command.pinnedAssets where pin.source == .approvedAssetStore {
                history[pin.assetID, default: 0] += 1
            }
        }
        assetStore.replacePins(history: history, checkpoints: checkpointAssetPinCounts())
    }

    private func checkpointAssetPinCounts() -> [String: Int] {
        guard let assetStore else { return [:] }
        var result: [String: Int] = [:]
        for checkpoint in [headCheckpoint] + periodicCheckpoints {
            for assetID in checkpoint.assetIDs where assetStore.contains(assetID: assetID) {
                result[assetID, default: 0] += 1
            }
        }
        return result
    }
}

private func isPrefix(_ prefix: [UUID], of values: [UUID]) -> Bool {
    guard prefix.count <= values.count else { return false }
    return zip(prefix, values).allSatisfy(==)
}

private func checkedAdd(_ lhs: Int, _ rhs: Int) throws -> Int {
    let result = lhs.addingReportingOverflow(rhs)
    guard !result.overflow else { throw DeltaHistoryError.costOverflow }
    return result.partialValue
}

private func deltaTransform(_ node: SceneNode) -> Geometry.AffineTransform {
    switch node {
    case .path(let value): return value.transform
    case .text(let value): return value.transform
    case .image(let value): return value.transform
    case .group(let value): return value.transform
    }
}

private func embeddedAssetData(in document: EditorDocument) -> [Data] {
    document.layers.flatMap { $0.nodes.flatMap(embeddedAssetData) }
}

private func checkpointAssetIDs(
    in document: EditorDocument, assetStore: ApprovedAssetStore?
) -> Set<String> {
    guard let assetStore else { return [] }
    return Set(
        embeddedAssetData(in: document).compactMap {
            let assetID = ApprovedAssetStore.assetID(for: $0)
            return assetStore.contains(assetID: assetID) ? assetID : nil
        })
}

private func embeddedAssetData(in node: SceneNode) -> [Data] {
    switch node {
    case .image(let image):
        if case .embedded(let data) = image.storage { return [data] }
        return []
    case .group(let group): return group.children.flatMap(embeddedAssetData)
    default: return []
    }
}
