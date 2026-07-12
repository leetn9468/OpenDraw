import Foundation

public struct ObjectID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init(rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

public enum MeasurementUnit: String, Codable, Sendable, CaseIterable {
    case points, millimeters, inches, pixels
}

public struct SRGBColor: Hashable, Codable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red.clamped(to: 0...1)
        self.green = green.clamped(to: 0...1)
        self.blue = blue.clamped(to: 0...1)
        self.alpha = alpha.clamped(to: 0...1)
    }

    public static let black = Self(red: 0, green: 0, blue: 0)
    public static let white = Self(red: 1, green: 1, blue: 1)
}

public enum EditorError: Error, Equatable, Sendable {
    case invalidValue(String)
    case invariantViolation(String)
    case unsupported(String)
    case corruptInput(String)
}

extension Comparable {
    fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
