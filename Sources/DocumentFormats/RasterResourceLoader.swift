import DocumentModel
import EditorCore
import Foundation
import Geometry
import ImageIO

public struct RasterResourceLoader: Sendable {
    public static let maximumPixels = 50_000_000
    public static let maximumBytes = 50 * 1_024 * 1_024
    public init() {}
    public func embedded(data: Data, frame: Geometry.Rect) throws -> ImageObject {
        guard data.count <= Self.maximumBytes, let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { throw EditorError.corruptInput("Unsafe or unsupported raster image") }
        _ = try EmbeddedImageValidator().decode(data)
        return ImageObject(frame: frame, storage: .embedded(data), pixelWidth: width, pixelHeight: height)
    }
    public func linked(relativePath: String, frame: Geometry.Rect, pixelWidth: Int, pixelHeight: Int) throws
        -> ImageObject
    {
        let components = NSString(string: relativePath).pathComponents
        guard !relativePath.hasPrefix("/"), !components.contains("..") else {
            throw EditorError.corruptInput("Unsafe linked image path")
        }
        do { _ = try DocumentLimits.checkedPixelCount(width: Int64(pixelWidth), height: Int64(pixelHeight)) } catch {
            throw EditorError.corruptInput("Unsafe linked image")
        }
        return ImageObject(
            frame: frame, storage: .linked(relativePath: relativePath), pixelWidth: pixelWidth, pixelHeight: pixelHeight
        )
    }
}
