import Foundation

public struct DeltaHistoryFeatureFlag: Equatable, Sendable {
    public static let environmentKey = "OPENDRAW_DELTA_HISTORY"
    public static let disabled = Self(isEnabled: false)
    public static let enabled = Self(isEnabled: true)

    public let isEnabled: Bool

    public init(isEnabled: Bool) { self.isEnabled = isEnabled }

    public static func environment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> Self {
        Self(isEnabled: environment[environmentKey] == "1")
    }
}
