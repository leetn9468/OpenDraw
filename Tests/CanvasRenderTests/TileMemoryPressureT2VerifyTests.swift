import CanvasRender
import DocumentModel
import EditorCommands
import Foundation
import Testing

@Suite(.enabled(if: tileCacheT1TestsEnabled))
struct TileMemoryPressureT2VerifyTests {
    @Test func verifyT2PressureDropsFullTileCacheBeforeCheckpointsAndPreservesFloorPins() throws {
        let grid = try TileGrid(documentWidth: 512 * 256, documentHeight: 256)
        let cache = TileCache<Int>()
        for column in 0..<512 {
            let geometry = try #require(
                grid.geometry(at: TileCoordinate(column: column, row: 0)))
            #expect(cache.insert(column, geometry: geometry))
        }
        #expect(cache.count == 512)
        #expect(cache.totalByteCount == 134_217_728)

        let document = try EditorDocument(width: 100, height: 100)
        let store = ApprovedAssetStore()
        let pinnedData = Data(repeating: 0xA5, count: 1_024)
        let descriptor = store.registerApproved(pinnedData)
        let pin = try HistoryAssetPin(approvedAsset: descriptor)
        var floorHistory = try DeltaCommandHistory(document: document, assetStore: store)
        for sequence in 1...9 {
            try floorHistory.commit(try pressureCommand(sequence: sequence))
        }
        try floorHistory.commit(try pressureCommand(sequence: 10, pins: [pin]))
        var checkpointHistory = try DeltaCommandHistory(document: document)
        for sequence in 1...50 {
            try checkpointHistory.commit(try pressureCommand(sequence: 100 + sequence))
        }
        #expect(floorHistory.undoDepth == 10)
        #expect(store.historyPinCount(assetID: descriptor.assetID) == 1)
        #expect(checkpointHistory.checkpointCount == 3)

        var histories = [floorHistory, checkpointHistory]
        let result = TileCacheMemoryPressure.apply(cache: cache, histories: &histories)
        let firstStage = try #require(result.stages.first)
        #expect(
            firstStage
                == .tileCacheCleared(
                    removed: TileCacheRemoval(count: 512, byteCount: 134_217_728),
                    remainingCount: 0, checkpointCounts: [1, 3],
                    undoDepths: [10, 50]))
        #expect(cache.count == 0)
        #expect(cache.totalByteCount == 0)
        #expect(
            result.stages.dropFirst()
                == [
                    .historyCheckpointsDropped(historyIndex: 0, dropped: 0),
                    .historyCheckpointsDropped(historyIndex: 1, dropped: 2),
                ])
        #expect(result.checkpointCountsAfter == [1, 1])
        #expect(result.undoDepthsAfter == [10, 50])
        #expect(histories[0].totalCostInBytes == floorHistory.totalCostInBytes)
        #expect(store.historyPinCount(assetID: descriptor.assetID) == 1)
        #expect(store.contains(assetID: descriptor.assetID))
    }
}

private func pressureCommand(
    sequence: Int, pins: [HistoryAssetPin] = []
) throws -> DocumentCommand {
    try DocumentCommand(
        name: "Tile pressure fixture", damageBounds: .none, costInBytes: 1,
        pinnedAssets: pins, oldPayload: Data([UInt8(truncatingIfNeeded: sequence)]),
        newPayload: Data([UInt8(truncatingIfNeeded: sequence + 1)]),
        apply: { _ in }, unapply: { _ in })
}
