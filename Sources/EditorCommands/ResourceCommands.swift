import DocumentModel
import EditorCore
import Foundation

public enum ResourceCommandError: Error, Equatable, Sendable {
    case duplicateResource
    case resourceNotFound
    case invalidIndex
}

private struct GradientSlot: Hashable, Codable, Sendable {
    var index: Int
    var gradient: GradientResource
}

public enum ResourceCommands {
    public static func insertGradient(
        _ gradient: GradientResource, in document: EditorDocument, at index: Int,
        commandID: UUID = UUID(), timestamp: Date = Date()
    ) throws -> DocumentCommand {
        let slot = GradientSlot(index: index, gradient: gradient)
        let oldBytes = try canonicalBytes([GradientSlot]())
        let newBytes = try canonicalBytes([slot])
        let forward: @Sendable (inout EditorDocument) throws -> Void = {
            guard index >= 0, index <= $0.gradients.count else {
                throw ResourceCommandError.invalidIndex
            }
            $0.gradients.insert(gradient, at: index)
        }
        let reverse: @Sendable (inout EditorDocument) throws -> Void = {
            guard $0.gradients.indices.contains(index),
                $0.gradients[index].id == gradient.id
            else { throw ResourceCommandError.resourceNotFound }
            $0.gradients.remove(at: index)
        }
        return try DocumentCommand(
            commandID: commandID, timestamp: timestamp, name: "Insert gradient",
            damageBounds: .full, costInBytes: 192 + oldBytes.count + newBytes.count,
            pinnedAssets: [], oldPayload: oldBytes, newPayload: newBytes,
            validatedApply: forward, validatedUnapply: reverse,
            applyPreflight: {
                guard !$0.gradients.contains(where: { $0.id == gradient.id }) else {
                    throw ResourceCommandError.duplicateResource
                }
                var candidate = $0
                try forward(&candidate)
                try candidate.validate()
            },
            unapplyPreflight: {
                guard $0.gradients.indices.contains(index),
                    $0.gradients[index].id == gradient.id
                else { throw ResourceCommandError.resourceNotFound }
            })
    }
}
