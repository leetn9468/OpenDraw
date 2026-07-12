import DocumentModel
import Foundation

public enum ParserHarnessError: Error, Equatable, Sendable { case deadlineExceeded }

public struct AdversarialParserHarness: Sendable {
    public init() {}
    public func decodeNative(_ data: Data, timeout: Duration = .seconds(2)) async throws -> EditorDocument {
        try Task.checkCancellation()
        return try await race(timeout: timeout) { try NativeDocumentCodec().decode(data) }
    }
    public func importSVG(_ data: Data, timeout: Duration = .seconds(2)) async throws -> ImportResult {
        try Task.checkCancellation()
        return try await race(timeout: timeout) { try SVGImporter().importData(data) }
    }
    private func race<T: Sendable>(timeout: Duration, operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try operation() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw ParserHarnessError.deadlineExceeded
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
}
