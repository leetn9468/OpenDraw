import DocumentFormats
import DocumentModel
import Foundation
import Geometry
import Testing

@Test func testP2ApprovedImageCachePublishesValidatedBytesToSharedAssetStore() async throws {
    let png = Data(
        base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )!
    let image = ImageObject(
        frame: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1), storage: .embedded(png),
        pixelWidth: 1, pixelHeight: 1)
    let document = try EditorDocument(
        width: 10, height: 10, layers: [Layer(name: "L", nodes: [.image(image)])])
    let store = ApprovedAssetStore()
    let cache = ApprovedImageCache(assetStore: store)
    try await cache.approve(document)
    let assetID = ApprovedAssetStore.assetID(for: png)
    #expect(store.contains(assetID: assetID))
    #expect(store.data(assetID: assetID) == png)
    #expect(store.historyPinCount(assetID: assetID) == 0)
    #expect(store.checkpointPinCount(assetID: assetID) == 0)
}
