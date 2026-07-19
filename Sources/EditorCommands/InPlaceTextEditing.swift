import DocumentModel
import EditorCore
import Foundation

/// Command boundary shared by the canvas field editor and permanent headless
/// fixtures. Empty new text never creates a structural history entry; existing
/// text always uses the established content value swap.
public enum InPlaceTextEditing {
    public static func createCommand(
        text: TextObject, in document: EditorDocument, parent: SceneParent, at index: Int,
        assetStore: ApprovedAssetStore? = nil
    ) throws -> DocumentCommand? {
        guard !text.text.isEmpty else { return nil }
        return try StructuralCommands.createText(
            text, in: document, parent: parent, at: index, assetStore: assetStore)
    }

    public static func editCommand(
        nodeID: ObjectID, text: String, in document: EditorDocument
    ) throws -> DocumentCommand {
        try ValueSwapCommands.textContent(in: document, nodeID: nodeID, newValue: text)
    }
}
