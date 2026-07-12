import Foundation

public enum SVGLengthError: Error, Equatable, Sendable { case invalid, unsupportedUnit }
public struct SVGLengthParser: Sendable {
    public init() {}
    public func parse(_ input: String) throws -> Double {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { throw SVGLengthError.invalid }
        let split = value.firstIndex(where: { $0.isLetter || $0 == "%" }) ?? value.endIndex
        let numeric = String(value[..<split])
        let unit = String(value[split...])
        guard let number = Double(numeric), number.isFinite else { throw SVGLengthError.invalid }
        let factor: Double
        switch unit {
        case "", "px": factor = 1
        case "in": factor = 96
        case "cm": factor = 96 / 2.54
        case "mm": factor = 96 / 25.4
        case "pt": factor = 96 / 72
        case "pc": factor = 16
        default: throw SVGLengthError.unsupportedUnit
        }
        return number * factor
    }
}
