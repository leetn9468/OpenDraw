import DocumentModel

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
    public private(set) var document: EditorDocument
    private var undoStack: [(String, EditorDocument)] = []
    private var redoStack: [(String, EditorDocument)] = []
    private var savePoint: EditorDocument
    public var maximumEntries: Int
    public init(document: EditorDocument, maximumEntries: Int = 100) {
        self.document = document
        savePoint = document
        self.maximumEntries = max(1, maximumEntries)
    }
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var isDirty: Bool { document != savePoint }
    public mutating func perform(_ command: DocumentCommand) throws {
        var candidate = document
        try command.apply(to: &candidate)
        try candidate.validate()
        undoStack.append((command.name, document))
        document = candidate
        redoStack.removeAll()
        if undoStack.count > maximumEntries { undoStack.removeFirst(undoStack.count - maximumEntries) }
    }
    public mutating func coalesce(_ command: DocumentCommand) throws {
        let earlier = undoStack.popLast()
        do {
            try perform(command)
            if let earlier { undoStack[undoStack.count - 1] = earlier }
        } catch {
            if let earlier { undoStack.append(earlier) }
            throw error
        }
    }
    public mutating func markSaved() { savePoint = document }
    public mutating func undo() {
        guard let prior = undoStack.popLast() else { return }
        redoStack.append((prior.0, document))
        document = prior.1
    }
    public mutating func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append((next.0, document))
        document = next.1
    }
}
