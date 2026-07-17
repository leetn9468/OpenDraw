import CanvasRender
import CoreGraphics
import DocumentModel
import Testing

@Suite
struct TileCompositeVerifyTests {
    @Test func verify031DisabledCacheRemainsCompositeCorrect() throws {
        let document = try EditorDocument(
            width: 100, height: 80,
            layers: [Layer(name: "Small", nodes: [.path(rectanglePath(minX: 8, minY: 8, maxX: 92, maxY: 72))])])
        let renderer = TileCompositeRenderer(byteBudget: 200_000)
        let direct = try directImage(document, width: 100, height: 80)
        let first = try compositeImage(document, renderer: renderer, width: 100, height: 80)
        let second = try compositeImage(document, renderer: renderer, width: 100, height: 80)
        #expect(!renderer.cache.isEnabled)
        #expect(renderer.cache.count == 0)
        #expect(first.1.renderedTiles.count == 1)
        #expect(second.1.renderedTiles.count == 1)
        #expect(first.1.hitTiles.isEmpty)
        #expect(second.1.hitTiles.isEmpty)
        let firstDifference = try compare(first.0, direct)
        let secondDifference = try compare(second.0, direct)
        #expect(firstDifference.passesFrozenInstrument)
        #expect(secondDifference.passesFrozenInstrument)
        #expect(firstDifference.differingPixels == 0)
        #expect(secondDifference.differingPixels == 0)
    }

    @Test func verify032MixedSceneColdAndWarmCompositeEqualDirect() throws {
        let document = try mixedTileDocument()
        let direct = try directImage(document, width: 800, height: 500)
        let renderer = TileCompositeRenderer()
        let cold = try compositeImage(document, renderer: renderer, width: 800, height: 500)
        let warm = try compositeImage(document, renderer: renderer, width: 800, height: 500)
        #expect(cold.1.renderedTiles.count == 8)
        #expect(cold.1.hitTiles.isEmpty)
        #expect(warm.1.renderedTiles.isEmpty)
        #expect(warm.1.hitTiles.count == 8)
        let coldDifference = try compare(cold.0, direct)
        let warmDifference = try compare(warm.0, direct)
        #expect(coldDifference.allowedDifferingPixels == 4_000)
        #expect(coldDifference.passesFrozenInstrument)
        #expect(warmDifference.passesFrozenInstrument)
        #expect(coldDifference.differingPixels == 0)
        #expect(warmDifference.differingPixels == 0)
        #expect(throws: TileTestError.pixelCountOverflow) {
            try frozenDifferingPixelLimit(width: Int.max, height: 2)
        }
    }

    @Test func verify032CornerStraddleColdAndWarmCompositeEqualDirect() throws {
        let document = try cornerStraddleDocument()
        let direct = try directImage(document, width: 512, height: 512)
        let renderer = TileCompositeRenderer()
        let cold = try compositeImage(document, renderer: renderer, width: 512, height: 512)
        let warm = try compositeImage(document, renderer: renderer, width: 512, height: 512)
        #expect(cold.1.renderedTiles.count == 4)
        #expect(warm.1.hitTiles.count == 4)
        let coldDifference = try compare(cold.0, direct)
        let warmDifference = try compare(warm.0, direct)
        #expect(coldDifference.allowedDifferingPixels == 2_621)
        #expect(coldDifference.passesFrozenInstrument)
        #expect(warmDifference.passesFrozenInstrument)
        #expect(coldDifference.differingPixels == 0)
        #expect(warmDifference.differingPixels == 0)
    }

    @Test func verify032EmptyColdAndWarmCompositeEqualDirect() throws {
        let document = try EditorDocument(
            width: 256, height: 256, layers: [Layer(name: "Empty")])
        let direct = try directImage(document, width: 256, height: 256)
        let renderer = TileCompositeRenderer()
        let cold = try compositeImage(document, renderer: renderer, width: 256, height: 256)
        let warm = try compositeImage(document, renderer: renderer, width: 256, height: 256)
        #expect(cold.1.renderedTiles.count == 1)
        #expect(warm.1.hitTiles.count == 1)
        let coldDifference = try compare(cold.0, direct)
        let warmDifference = try compare(warm.0, direct)
        #expect(coldDifference.allowedDifferingPixels == 655)
        #expect(coldDifference.passesFrozenInstrument)
        #expect(warmDifference.passesFrozenInstrument)
        #expect(coldDifference.differingPixels == 0)
        #expect(warmDifference.differingPixels == 0)
    }

    @Test func productionDocumentCoordinateCompositeEqualsDirect() throws {
        let document = try cornerStraddleDocument()
        let directBitmap = try TileTestBitmap(width: 512, height: 512)
        CoreGraphicsRenderer().render(document, in: directBitmap.context)
        let direct = try #require(directBitmap.context.makeImage())

        let productionBitmap = try TileTestBitmap(width: 512, height: 512)
        let renderer = TileCompositeRenderer()
        let cold = try renderer.compositeDocumentCoordinates(
            document, in: productionBitmap.context)
        let production = try #require(productionBitmap.context.makeImage())
        #expect(Set(cold.renderedTiles) == Set(cold.visibleCoordinates))
        let difference = try compare(production, direct)
        #expect(difference.differingPixels == 0)
    }

    @Test func bench2bExposureCorridorRendersExactIndices() throws {
        #expect(TileExposureCorridor.documentWidth == 46_480)
        #expect(TileExposureCorridor.documentHeight == 250)
        #expect(TileExposureCorridor.deviceWidth == 92_960)
        #expect(TileExposureCorridor.deviceHeight == 500)
        #expect(TileExposureCorridor.nodeCount == 9_100)
        #expect(TileExposureCorridor.warmupCount == 60)
        #expect(TileExposureCorridor.measuredCount == 300)

        let document = try TileExposureCorridor.document()
        #expect(document.layers.flatMap(\.nodes).count == 9_100)
        let renderer = TileCompositeRenderer()
        let bitmap = try TileTestBitmap(
            width: TileExposureCorridor.viewportWidth,
            height: TileExposureCorridor.viewportHeight)
        let setup = try renderer.composite(
            document, in: bitmap.context, zoom: TileExposureCorridor.zoom,
            backingScale: TileExposureCorridor.backingScale,
            visibleDeviceRect: TileExposureCorridor.setupVisibleRect)
        #expect(Set(setup.renderedTiles) == TileExposureCorridor.expectedSetupTiles())
        #expect(setup.hitTiles.isEmpty)

        var renderedRegions = Set(setup.renderedTiles)
        for frame in 1...TileExposureCorridor.advanceCount {
            let expected = TileExposureCorridor.expectedRenderedTiles(frame: frame)
            #expect(expected.isDisjoint(with: renderedRegions))
            let result = try renderer.composite(
                document, in: bitmap.context, zoom: TileExposureCorridor.zoom,
                backingScale: TileExposureCorridor.backingScale,
                visibleDeviceRect: TileExposureCorridor.visibleRect(frame: frame))
            #expect(Set(result.renderedTiles) == expected, "frame \(frame)")
            #expect(!result.renderedTiles.isEmpty, "frame \(frame)")
            #expect(Set(result.hitTiles).isSubset(of: renderedRegions), "frame \(frame)")
            #expect(Set(result.hitTiles).isDisjoint(with: expected), "frame \(frame)")
            renderedRegions.formUnion(result.renderedTiles)
        }
        #expect(renderedRegions.count == 728)
    }
}
