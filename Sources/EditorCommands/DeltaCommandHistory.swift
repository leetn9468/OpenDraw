import DocumentModel
import Foundation

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
    public enum Operation: String, Equatable, Sendable { case undo, redo }

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

    public init(
        document: EditorDocument, featureFlag: DeltaHistoryFeatureFlag = .environment()
    ) throws {
        guard featureFlag.isEnabled else { throw DeltaHistoryError.featureDisabled }
        try document.validate()
        self.document = document
        self.featureFlag = featureFlag
        headCheckpoint = Checkpoint(counter: 0, document: document, lineage: [])
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var undoDepth: Int { undoStack.count }
    public var redoDepth: Int { redoStack.count }
    public var checkpointCount: Int { 1 + periodicCheckpoints.count }
    public var headCheckpointCounter: UInt64 { headCheckpoint.counter }
    public var retainedCommandCounters: [UInt64] { undoStack.map(\.counter) }
    public var totalCostInBytes: Int { (try? costBreakdown(for: retainedEntries).total) ?? Int.max }

    @discardableResult public mutating func commit(_ command: DocumentCommand) throws -> DeltaCommitResult {
        guard featureFlag.isEnabled else { throw DeltaHistoryError.featureDisabled }
        guard command.hasCapturedInverse else { throw DeltaHistoryError.inverseRequired }
        if command.isIdentity { return .identityElided }

        var candidate = self
        let result = try candidate.commitInPlace(command)
        self = candidate
        return result
    }

    @discardableResult public mutating func undo() throws -> DeltaHistoryOperationResult {
        guard let entry = undoStack.last else { return .noOperation }
        let original = self
        do {
            try entry.inverse.apply(to: &document)
            undoStack.removeLast()
            redoStack.append(entry)
            lastDiagnostic = nil
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
                return .recoveredFromCheckpoint
            } catch let recoveryError {
                self = original
                lastDiagnostic = DeltaHistoryDiagnostic(
                    operation: .undo, commandID: entry.command.commandID, commandName: entry.command.name,
                    underlyingError: "\(error); recovery: \(recoveryError)", restoredCheckpointCounter: nil,
                    replayedCommandCount: 0, recoverySucceeded: false)
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
                return .recoveredFromCheckpoint
            } catch let recoveryError {
                self = original
                lastDiagnostic = DeltaHistoryDiagnostic(
                    operation: .redo, commandID: entry.command.commandID, commandName: entry.command.name,
                    underlyingError: "\(error); recovery: \(recoveryError)", restoredCheckpointCounter: nil,
                    replayedCommandCount: 0, recoverySucceeded: false)
                throw DeltaHistoryError.recoveryFailed
            }
        }
    }

    public mutating func beginGesture() -> GestureID { GestureID() }

    /// Cancellation has no commit boundary, so redo and the global counter are
    /// deliberately untouched under P-REDOCLEAR.
    public mutating func cancelGesture(_ gestureID: GestureID) { _ = gestureID }

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
                    lineage: undoStack.map { $0.command.commandID }))
        }
        try evictToBudgets()
        enforceCheckpointCeiling()
        lastDiagnostic = nil
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
