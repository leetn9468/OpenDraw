import EditorCommands

public enum TileMemoryPressureStage: Equatable, Sendable {
    case tileCacheCleared(
        removed: TileCacheRemoval, remainingCount: Int,
        checkpointCounts: [Int], undoDepths: [Int])
    case historyCheckpointsDropped(historyIndex: Int, dropped: Int)
}

public struct TileMemoryPressureResult: Equatable, Sendable {
    public let stages: [TileMemoryPressureStage]
    public let checkpointCountsAfter: [Int]
    public let undoDepthsAfter: [Int]
}

/// The Phase 5 safety-net ordering is intentionally explicit: derived tile
/// bitmaps are discarded before any delta-history recovery checkpoint.
public enum TileCacheMemoryPressure {
    public static func apply<Payload>(
        cache: TileCache<Payload>, histories: inout [DeltaCommandHistory]
    ) -> TileMemoryPressureResult {
        var stages: [TileMemoryPressureStage] = []
        let checkpointCounts = histories.map(\.checkpointCount)
        let undoDepths = histories.map(\.undoDepth)
        let removal = cache.removeAll()
        stages.append(
            .tileCacheCleared(
                removed: removal, remainingCount: cache.count,
                checkpointCounts: checkpointCounts, undoDepths: undoDepths))
        for index in histories.indices {
            let dropped = histories[index].applyMemorySafetyNet()
            stages.append(.historyCheckpointsDropped(historyIndex: index, dropped: dropped))
        }
        return TileMemoryPressureResult(
            stages: stages, checkpointCountsAfter: histories.map(\.checkpointCount),
            undoDepthsAfter: histories.map(\.undoDepth))
    }
}
