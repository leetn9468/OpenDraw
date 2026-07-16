import DocumentModel
import Foundation
import Geometry

/// P-COMPOSITE-ATOMIC failures distinguish a clean child rollback from the
/// exceptional path that must engage delta-history checkpoint containment.
public enum CompositeCommandError: Error, Equatable, Sendable {
    case childFailed(index: Int, underlyingError: String)
    case unwindFailed(childIndex: Int, unwindIndex: Int, underlyingError: String)
    case costOverflow
}

private struct CompositePayload: Codable, Sendable {
    var childIDs: [UUID]
    var isApplied: Bool
}

public enum CompositeCommands {
    public static let framingCostInBytes = 128

    /// Creates one reversible command from an ordered list. Inverse child
    /// commands are captured here, in reverse order; no transform or other
    /// value is recomputed when the inverse later runs.
    public static func ordered(
        name: String, children: [DocumentCommand], commandID: UUID = UUID(),
        timestamp: Date = Date()
    ) throws -> DocumentCommand {
        let inverseChildren = try children.reversed().map { try $0.inverted() }
        let childIDs = children.map(\.commandID)
        let allIdentity = children.allSatisfy(\.isIdentity)
        let oldBytes = try canonicalBytes(CompositePayload(childIDs: childIDs, isApplied: false))
        let newBytes = allIdentity
            ? oldBytes
            : try canonicalBytes(CompositePayload(childIDs: childIDs, isApplied: true))
        var cost = framingCostInBytes
        for child in children {
            let result = cost.addingReportingOverflow(child.costInBytes)
            guard !result.overflow else { throw CompositeCommandError.costOverflow }
            cost = result.partialValue
        }
        return try DocumentCommand(
            commandID: commandID, timestamp: timestamp, name: name,
            damageBounds: unionDamage(children.map(\.damageBounds)), costInBytes: cost,
            pinnedAssets: children.flatMap(\.pinnedAssets), oldPayload: oldBytes,
            newPayload: newBytes,
            validatedApply: { document in try applyAtomically(children, to: &document) },
            validatedUnapply: { document in try applyAtomically(inverseChildren, to: &document) },
            // Every child runs its own frozen preflight immediately before its
            // mutation. A second whole-document validation here would duplicate
            // that proof and make a composite scale with all 1,000 scene nodes.
            applyPreflight: { _ in }, unapplyPreflight: { _ in })
    }
}

private func applyAtomically(
    _ children: [DocumentCommand], to document: inout EditorDocument
) throws {
    let compositePreState = document
    var applied: [DocumentCommand] = []
    for (index, child) in children.enumerated() {
        do {
            try child.apply(to: &document)
            applied.append(child)
        } catch {
            for (rollbackOffset, prior) in applied.reversed().enumerated() {
                do {
                    try prior.inverted().apply(to: &document)
                } catch {
                    // The structured error still engages delta-history
                    // checkpoint containment. Restoring the captured value here
                    // also preserves composite-level atomicity for callers that
                    // apply a command directly rather than through history.
                    document = compositePreState
                    throw CompositeCommandError.unwindFailed(
                        childIndex: index, unwindIndex: index - rollbackOffset - 1,
                        underlyingError: String(describing: error))
                }
            }
            throw CompositeCommandError.childFailed(
                index: index, underlyingError: String(describing: error))
        }
    }
}

private func unionDamage(
    _ values: [DocumentCommandDamageBounds]
) -> DocumentCommandDamageBounds {
    var result: Rect?
    for value in values {
        switch value {
        case .full: return .full
        case .none: continue
        case .rect(let rect): result = result.map { $0.union(rect) } ?? rect
        }
    }
    return result.map(DocumentCommandDamageBounds.rect) ?? .none
}
