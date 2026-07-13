import DocumentFormats
import DocumentModel
import Foundation
import Testing

private func mutations(of seed: Data, count: Int) -> [Data] {
    var state: UInt64 = 0xA110_F00D
    return (0..<count).map { index in
        var bytes = [UInt8](seed)
        let edits = 1 + index % 8
        for _ in 0..<edits where !bytes.isEmpty {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let position = Int(state % UInt64(bytes.count))
            bytes[position] ^= UInt8(truncatingIfNeeded: state >> 24)
        }
        return Data(bytes)
    }
}

private func checkMutation(
    kind: String, index: Int, operation: () async throws -> Void
) async {
    let start = ContinuousClock.now
    _ = try? await operation()
    let elapsed = start.duration(to: .now)
    if elapsed >= .seconds(3) {
        print("CORPUS_FAILURE kind=\(kind) index=\(index) seed=0x00000000A110F00D")
    }
    #expect(elapsed < .seconds(3))
}

@Test func deterministicNativeAndSVGMutationCorpusMeetsDeadline() async throws {
    let native = try NativeDocumentCodec().encode(try EditorDocument.sample())
    let svg = Data("<svg xmlns=\"http://www.w3.org/2000/svg\"><rect width=\"10\" height=\"10\"/></svg>".utf8)
    let harness = AdversarialParserHarness()
    let start = ContinuousClock.now
    for (index, input) in mutations(of: native, count: 256).enumerated() {
        await checkMutation(kind: "native", index: index) { _ = try await harness.decodeNative(input) }
    }
    for (index, input) in mutations(of: svg, count: 256).enumerated() {
        await checkMutation(kind: "svg", index: index) { _ = try await harness.importSVG(input) }
    }
    #expect(start.duration(to: .now) < .seconds(10))
}

@Test func fixedAdversarialClassesFailSafely() async throws {
    let harness = AdversarialParserHarness()
    let cases = [
        Data([0xFF, 0xFE, 0xFD]),
        Data("{\"formatVersion\":4".utf8),
        Data(String(repeating: "[", count: 129).utf8),
        Data("{\"formatVersion\":4,\"width\":1e999,\"height\":1}".utf8),
    ]
    for input in cases { await #expect(throws: (any Error).self) { try await harness.decodeNative(input) } }
    let entity = Data(
        "<!DOCTYPE svg [<!ENTITY a \"x\"><!ENTITY b \"&a;&a;\">]><svg xmlns=\"http://www.w3.org/2000/svg\">&b;</svg>"
            .utf8)
    await #expect(throws: (any Error).self) { try await harness.importSVG(entity) }
    let cancelled = Task { try await harness.importSVG(Data()) }
    cancelled.cancel()
    await #expect(throws: CancellationError.self) { try await cancelled.value }
    #expect(throws: ImageApprovalError.pathEscape) {
        try LinkedResourceResolver(root: URL(fileURLWithPath: "/tmp/safe-root")).resolve("../../etc/passwd")
    }
}
