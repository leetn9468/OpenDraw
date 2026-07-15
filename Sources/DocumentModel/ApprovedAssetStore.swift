import CryptoKit
import Foundation

public struct ApprovedAssetDescriptor: Hashable, Sendable {
    public let assetID: String
    public let byteCount: Int

    public init(assetID: String, byteCount: Int) {
        self.assetID = assetID
        self.byteCount = byteCount
    }
}

/// Shared immutable storage for approved embedded-asset bytes.
///
/// Decoded-image caches and history use the same content-addressed records.
/// History and checkpoint pin sets are replaced atomically, so eviction can
/// never observe the gap between an oldest-history-pin removal and transfer to
/// the next retained pin. Checkpoint pins are intentionally tracked outside
/// the delta-history byte budget.
public final class ApprovedAssetStore: @unchecked Sendable {
    private struct Record {
        var data: Data
        var historyPinCount: Int
        var checkpointPinCount: Int
        var accessSequence: UInt64
    }

    private let lock = NSLock()
    private var records: [String: Record] = [:]
    private var sequence: UInt64 = 0

    public init() {}

    public static func assetID(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Registers bytes after the caller's normal document/image approval.
    /// Equal content shares one immutable backing record.
    @discardableResult public func registerApproved(_ data: Data) -> ApprovedAssetDescriptor {
        let assetID = Self.assetID(for: data)
        return lock.withLock {
            sequence &+= 1
            if var existing = records[assetID] {
                precondition(existing.data == data, "SHA-256 collision in approved asset store")
                existing.accessSequence = sequence
                records[assetID] = existing
            } else {
                records[assetID] = Record(
                    data: data, historyPinCount: 0, checkpointPinCount: 0, accessSequence: sequence)
            }
            return ApprovedAssetDescriptor(assetID: assetID, byteCount: data.count)
        }
    }

    public func contains(assetID: String) -> Bool { lock.withLock { records[assetID] != nil } }

    public func data(assetID: String) -> Data? {
        lock.withLock {
            guard var record = records[assetID] else { return nil }
            sequence &+= 1
            record.accessSequence = sequence
            records[assetID] = record
            return record.data
        }
    }

    public func historyPinCount(assetID: String) -> Int {
        lock.withLock { records[assetID]?.historyPinCount ?? 0 }
    }

    public func checkpointPinCount(assetID: String) -> Int {
        lock.withLock { records[assetID]?.checkpointPinCount ?? 0 }
    }

    public func byteCount(assetID: String) -> Int? { lock.withLock { records[assetID]?.data.count } }

    public var totalByteCount: Int { lock.withLock { records.values.reduce(0) { $0 + $1.data.count } } }

    public var pinnedByteCount: Int {
        lock.withLock {
            records.values.reduce(0) {
                $0 + (($1.historyPinCount > 0 || $1.checkpointPinCount > 0) ? $1.data.count : 0)
            }
        }
    }

    /// Replaces both pin domains in one critical section. Unknown IDs are
    /// ignored so P1 metadata-only stub pins remain valid and side-effect free.
    public func replacePins(history: [String: Int], checkpoints: [String: Int]) {
        lock.withLock {
            for assetID in Array(records.keys) {
                records[assetID]?.historyPinCount = max(0, history[assetID] ?? 0)
                records[assetID]?.checkpointPinCount = max(0, checkpoints[assetID] ?? 0)
            }
        }
    }

    /// Evicts least-recently-used unpinned records until the requested budget
    /// is met or only pinned records remain. The returned count is the actual
    /// retained byte total and may exceed the request when pins require it.
    @discardableResult public func evictUnpinned(toMaximumBytes maximumBytes: Int) -> Int {
        lock.withLock {
            let target = max(0, maximumBytes)
            var total = records.values.reduce(0) { $0 + $1.data.count }
            let candidates = records.filter {
                $0.value.historyPinCount == 0 && $0.value.checkpointPinCount == 0
            }.sorted { $0.value.accessSequence < $1.value.accessSequence }
            for candidate in candidates where total > target {
                total -= candidate.value.data.count
                records[candidate.key] = nil
            }
            return total
        }
    }
}
