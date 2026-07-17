import CanvasRender
import DocumentModel
import EditorCommands
import Geometry
import Testing

@Suite(.enabled(if: tileCacheT1TestsEnabled))
struct TileInvalidationT2VerifyTests {
    @Test func verifyT2TypedChangesUseOneInvalidationChokePoint() throws {
        let path = rectanglePath(minX: 240, minY: 240, maxX: 270, maxY: 270)
        let original = try EditorDocument(
            width: 512, height: 512,
            layers: [Layer(name: "Invalidation", nodes: [.path(path)])])
        var history = try DeltaCommandHistory(document: original)
        let renderer = TileCompositeRenderer()
        renderer.subscribe(to: history)

        let cold = try compositeImage(history.document, renderer: renderer, width: 512, height: 512)
        #expect(cold.1.renderedTiles.count == 4)

        let transform = try ValueSwapCommands.transform(
            in: history.document, nodeID: path.id,
            newValue: Geometry.AffineTransform(tx: 20, ty: 10))
        let grid = cold.1.grid
        let mappedTransform = TileDamageMapper.map(transform.damageBounds.documentDamage, in: grid)
            .resolvedCoordinates(in: grid)
        try history.commit(transform)
        let afterCommit = try compositeImage(
            history.document, renderer: renderer, width: 512, height: 512)
        #expect(Set(afterCommit.1.renderedTiles) == mappedTransform)
        #expect(renderer.invalidationRecords.last?.reason == .documentChange(.command("Transform")))
        #expect(renderer.invalidationRecords.last?.invalidatedCoordinates == mappedTransform)

        try history.undo()
        let afterUndo = try compositeImage(history.document, renderer: renderer, width: 512, height: 512)
        #expect(Set(afterUndo.1.renderedTiles) == mappedTransform)
        #expect(renderer.invalidationRecords.last?.reason == .documentChange(.undo("Transform")))

        try history.redo()
        let afterRedo = try compositeImage(history.document, renderer: renderer, width: 512, height: 512)
        #expect(Set(afterRedo.1.renderedTiles) == mappedTransform)
        #expect(renderer.invalidationRecords.last?.reason == .documentChange(.redo("Transform")))

        let noDamage = try ValueSwapCommands.layerName(
            in: history.document, layerID: history.document.layers[0].id,
            newValue: "Metadata only")
        try history.commit(noDamage)
        let afterNone = try compositeImage(history.document, renderer: renderer, width: 512, height: 512)
        #expect(afterNone.1.renderedTiles.isEmpty)
        #expect(afterNone.1.hitTiles.count == 4)
        #expect(renderer.invalidationRecords.last?.damage == DocumentDamage.none)
        #expect(renderer.invalidationRecords.last?.invalidatedCoordinates.isEmpty == true)

        let fullDamage = try ValueSwapCommands.layerVisibilityAndLock(
            in: history.document, layerID: history.document.layers[0].id,
            newValue: LayerVisibilityAndLock(isVisible: false, isLocked: false))
        let generationBeforeFull = renderer.cache.generation
        try history.commit(fullDamage)
        #expect(renderer.cache.generation == generationBeforeFull + 1)
        #expect(renderer.cache.count == 0)
        #expect(renderer.invalidationRecords.last?.didBumpGeneration == true)
        let afterFull = try compositeImage(history.document, renderer: renderer, width: 512, height: 512)
        #expect(afterFull.1.renderedTiles.count == 4)

        let frameGesture = try history.beginTransformGesture(nodeID: path.id)
        try history.updateTransformGesture(
            frameGesture, newValue: Geometry.AffineTransform(tx: 30, ty: 10))
        let frameRecord = try #require(renderer.invalidationRecords.last)
        #expect(frameRecord.reason == .documentChange(.gestureFrame))
        #expect(!frameRecord.invalidatedCoordinates.isEmpty)
        try history.cancelDeltaGesture(frameGesture)
        #expect(renderer.invalidationRecords.last?.reason == .documentChange(.gestureCancelled))

        _ = try compositeImage(history.document, renderer: renderer, width: 512, height: 512)
        renderer.clearInvalidationRecords()
        let sameScale = try compositeImage(
            history.document, renderer: renderer, width: 512, height: 512, zoom: 1)
        #expect(sameScale.1.renderedTiles.isEmpty)
        #expect(renderer.invalidationRecords.isEmpty)

        let generationBeforeZoom = renderer.cache.generation
        let zoomed = try compositeImage(
            history.document, renderer: renderer, width: 768, height: 768, zoom: 1.5)
        #expect(renderer.cache.generation == generationBeforeZoom + 1)
        #expect(zoomed.1.renderedTiles.count == 9)
        #expect(renderer.invalidationRecords.last?.reason == .deviceScaleChange)
        #expect(renderer.invalidationRecords.last?.didBumpGeneration == true)

        renderer.clearInvalidationRecords()
        let sameZoom = try compositeImage(
            history.document, renderer: renderer, width: 768, height: 768, zoom: 1.5)
        #expect(sameZoom.1.renderedTiles.isEmpty)
        #expect(sameZoom.1.hitTiles.count == 9)
        #expect(renderer.invalidationRecords.isEmpty)

        let generationBeforeBackingScale = renderer.cache.generation
        _ = try compositeImage(
            history.document, renderer: renderer, width: 512, height: 512,
            zoom: 1, backingScale: 1)
        #expect(renderer.cache.generation == generationBeforeBackingScale + 1)
        #expect(renderer.invalidationRecords.last?.reason == .deviceScaleChange)
    }
}
