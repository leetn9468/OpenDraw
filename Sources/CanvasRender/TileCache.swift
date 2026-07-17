import Foundation

public final class TileCache<Payload> {
    public static var defaultByteBudget: Int { 134_217_728 }

    private struct Entry {
        var payload: Payload
        var byteCount: Int
        var lastUse: UInt64
    }

    private let lock = NSLock()
    private var entries: [TileCoordinate: Entry] = [:]
    private var useCounter: UInt64 = 0
    private var currentGeneration: UInt64 = 0
    private var currentByteCount = 0
    private var currentEvictionCount = 0

    public let byteBudget: Int

    public init(byteBudget: Int = TileCache.defaultByteBudget) {
        self.byteBudget = max(0, byteBudget)
    }

    public var isEnabled: Bool { byteBudget >= TileGrid.fullTileByteCount }
    public var generation: UInt64 { lock.withLock { currentGeneration } }
    public var count: Int { lock.withLock { entries.count } }
    public var totalByteCount: Int { lock.withLock { currentByteCount } }
    public var evictionCount: Int { lock.withLock { currentEvictionCount } }
    public var coordinates: Set<TileCoordinate> { lock.withLock { Set(entries.keys) } }

    public func value(for coordinate: TileCoordinate) -> Payload? {
        lock.withLock {
            guard var entry = entries[coordinate] else { return nil }
            entry.lastUse = nextUse()
            entries[coordinate] = entry
            return entry.payload
        }
    }

    @discardableResult
    public func insert(_ payload: Payload, geometry: TileGeometry) -> Bool {
        guard isEnabled, geometry.byteCount <= byteBudget else { return false }
        return lock.withLock {
            if let replaced = entries.removeValue(forKey: geometry.coordinate) {
                currentByteCount -= replaced.byteCount
            }
            let addition = currentByteCount.addingReportingOverflow(geometry.byteCount)
            guard !addition.overflow else { return false }
            currentByteCount = addition.partialValue
            entries[geometry.coordinate] = Entry(
                payload: payload, byteCount: geometry.byteCount, lastUse: nextUse())
            evictUntilWithinBudget()
            return entries[geometry.coordinate] != nil
        }
    }

    public func removeAll() {
        lock.withLock {
            entries.removeAll()
            currentByteCount = 0
        }
    }

    public func bumpGeneration() {
        lock.withLock {
            currentGeneration &+= 1
            entries.removeAll()
            currentByteCount = 0
        }
    }

    private func nextUse() -> UInt64 {
        if useCounter == .max {
            let ordered = entries.sorted { $0.value.lastUse < $1.value.lastUse }
            for (offset, element) in ordered.enumerated() {
                var entry = element.value
                entry.lastUse = UInt64(offset)
                entries[element.key] = entry
            }
            useCounter = UInt64(ordered.count)
        } else {
            useCounter += 1
        }
        return useCounter
    }

    private func evictUntilWithinBudget() {
        while currentByteCount > byteBudget,
            let victim = entries.min(by: { $0.value.lastUse < $1.value.lastUse })
        {
            entries.removeValue(forKey: victim.key)
            currentByteCount -= victim.value.byteCount
            currentEvictionCount += 1
        }
    }
}
