import CanvasRender
import DocumentModel
import Geometry
import Testing

@Suite
struct TileGeometryVerifyTests {
    @Test func verify029FrozenDamageMappingExamples() throws {
        let grid = try TileGrid(documentWidth: 800, documentHeight: 500)
        let first = TileDamageMapper.map(
            .rects([Geometry.Rect(minX: 100, minY: 50, maxX: 300, maxY: 150)]), in: grid)
        #expect(first.resolvedCoordinates(in: grid) == coordinates(columns: 0...1, rows: 0...0))

        let zoomed = try TileGrid(documentWidth: 800, documentHeight: 500, zoom: 2)
        let second = TileDamageMapper.map(
            .rects([Geometry.Rect(minX: 100, minY: 50, maxX: 300, maxY: 150)]), in: zoomed)
        #expect(second.resolvedCoordinates(in: zoomed) == coordinates(columns: 0...2, rows: 0...1))

        let boundary = TileDamageMapper.map(
            .rects([Geometry.Rect(minX: 256, minY: 0, maxX: 512, maxY: 256)]), in: grid)
        #expect(boundary.resolvedCoordinates(in: grid) == coordinates(columns: 0...2, rows: 0...1))

        let point = TileDamageMapper.map(
            .rects([Geometry.Rect(minX: 300, minY: 300, maxX: 300, maxY: 300)]), in: grid)
        #expect(point.resolvedCoordinates(in: grid) == [TileCoordinate(column: 1, row: 1)])

        let outside = TileDamageMapper.map(
            .rects([Geometry.Rect(minX: 900, minY: 600, maxX: 950, maxY: 650)]), in: grid)
        #expect(outside == .none)
        #expect(TileDamageMapper.map(DamageRegion.none, in: grid) == .none)
        #expect(TileDamageMapper.map(.full, in: grid) == .all)
        #expect(TileDamageMapper.map(nil, in: grid) == .all)

        let retina = try TileGrid(
            documentWidth: 800, documentHeight: 500, zoom: 1, backingScale: 2)
        let retinaMapping = TileDamageMapper.map(
            .rects([Geometry.Rect(minX: 100, minY: 50, maxX: 300, maxY: 150)]), in: retina)
        #expect(retinaMapping.resolvedCoordinates(in: retina) == coordinates(columns: 0...2, rows: 0...1))
    }

    @Test func verify029FrozenConservativeInkCases() throws {
        let transformedText = TextObject(
            text: "Transform", origin: Point(x: 30, y: 80), fontSize: 24,
            transform: Geometry.AffineTransform(a: 1, b: 0.2, c: 0.1, d: 1, tx: 20, ty: 10))
        let fallbackText = TextObject(
            text: "Fallback 👩🏽‍💻", origin: Point(x: 40, y: 150),
            fontName: "OpenDraw-Definitely-Missing-Font", fontSize: 22)
        let image = ImageObject(
            frame: Geometry.Rect(minX: 300, minY: 40, maxX: 350, maxY: 100),
            storage: .linked(relativePath: "ink.png"), pixelWidth: 1, pixelHeight: 1,
            transform: Geometry.AffineTransform(tx: 12, ty: 8))
        let path = rectanglePath(
            minX: 420, minY: 100, maxX: 470, maxY: 160,
            style: PathStyle(fill: nil, stroke: .black, strokeWidth: 4, lineJoin: .round))
        let group = GroupNode(
            transform: Geometry.AffineTransform(tx: 30, ty: 20),
            children: [.path(path), .image(image)])
        let nodes: [SceneNode] = [
            .text(transformedText), .text(fallbackText), .image(image), .path(path), .group(group),
        ]
        let expected: [Geometry.Rect?] = [
            transformedText.conservativeInkBounds?.transformed(by: transformedText.transform),
            fallbackText.conservativeInkBounds?.transformed(by: fallbackText.transform),
            image.frame.transformed(by: image.transform), path.visualBounds,
            path.visualBounds?.union(image.frame.transformed(by: image.transform)).transformed(by: group.transform),
        ]
        let expectedMappings: [Set<TileCoordinate>] = [
            [TileCoordinate(column: 0, row: 0)],
            [TileCoordinate(column: 0, row: 0)],
            [TileCoordinate(column: 1, row: 0)],
            [TileCoordinate(column: 1, row: 0)],
            [TileCoordinate(column: 1, row: 0)],
        ]
        let grid = try TileGrid(documentWidth: 800, documentHeight: 500)
        for ((node, expectedBounds), expectedMapping) in zip(zip(nodes, expected), expectedMappings) {
            let bounds = try #require(TileDamageMapper.conservativeInkBounds(for: node))
            #expect(bounds == expectedBounds)
            let mapping = TileDamageMapper.map(.rects([bounds]), in: grid)
            #expect(mapping.resolvedCoordinates(in: grid) == expectedMapping)
        }
        let absent = TileDamageMapper.conservativeInkBounds(for: .group(GroupNode(children: [])))
        #expect(absent == nil)
        #expect(TileDamageMapper.map(absent.map { .rects([$0]) }, in: grid) == .all)
    }

    @Test func verify030FrozenGridGeometryAndByteCosts() throws {
        let base = try TileGrid(documentWidth: 800, documentHeight: 500)
        #expect(base.canvasWidth == 800)
        #expect(base.canvasHeight == 500)
        #expect(base.columnCount == 4)
        #expect(base.rowCount == 2)
        #expect(base.geometry(at: TileCoordinate(column: 0, row: 0))?.byteCount == 262_144)
        #expect(base.geometry(at: TileCoordinate(column: 3, row: 0))?.width == 32)
        #expect(base.geometry(at: TileCoordinate(column: 3, row: 0))?.byteCount == 32_768)
        #expect(base.geometry(at: TileCoordinate(column: 0, row: 1))?.height == 244)
        #expect(base.geometry(at: TileCoordinate(column: 0, row: 1))?.byteCount == 249_856)
        #expect(base.geometry(at: TileCoordinate(column: 3, row: 1))?.byteCount == 31_232)

        let zoomed = try TileGrid(documentWidth: 800, documentHeight: 500, zoom: 1.5)
        #expect(zoomed.canvasWidth == 1_200)
        #expect(zoomed.canvasHeight == 750)
        #expect(zoomed.columnCount == 5)
        #expect(zoomed.rowCount == 3)
        #expect(zoomed.geometry(at: TileCoordinate(column: 4, row: 0))?.width == 176)
        #expect(zoomed.geometry(at: TileCoordinate(column: 0, row: 2))?.height == 238)

        let small = try TileGrid(documentWidth: 100, documentHeight: 80)
        #expect(small.columnCount == 1)
        #expect(small.rowCount == 1)
        #expect(small.geometry(at: TileCoordinate(column: 0, row: 0))?.byteCount == 32_000)

        let retina = try TileGrid(documentWidth: 800, documentHeight: 500, backingScale: 2)
        #expect(retina.canvasWidth == 1_600)
        #expect(retina.canvasHeight == 1_000)
        #expect(retina.columnCount == 7)
        #expect(retina.rowCount == 4)
        #expect(retina.geometry(at: TileCoordinate(column: 6, row: 0))?.width == 64)
        #expect(retina.geometry(at: TileCoordinate(column: 0, row: 3))?.height == 232)
    }

    @Test func verify031FrozenCapacityAndExactBoundaryEviction() throws {
        let capacityGrid = try TileGrid(documentWidth: 512 * 256, documentHeight: 256)
        let capacity = TileCache<Int>()
        for column in 0..<512 {
            let coordinate = TileCoordinate(column: column, row: 0)
            let geometry = try #require(capacityGrid.geometry(at: coordinate))
            #expect(capacity.insert(column, geometry: geometry))
        }
        #expect(capacity.count == 512)
        #expect(capacity.totalByteCount == 134_217_728)

        let boundaryGrid = try TileGrid(documentWidth: 512 * 256 + 32, documentHeight: 500)
        let boundary = TileCache<Int>()
        let corner = TileCoordinate(column: 512, row: 1)
        let cornerGeometry = try #require(boundaryGrid.geometry(at: corner))
        #expect(boundary.insert(-1, geometry: cornerGeometry))
        for column in 0..<510 {
            let coordinate = TileCoordinate(column: column, row: 0)
            let geometry = try #require(boundaryGrid.geometry(at: coordinate))
            #expect(boundary.insert(column, geometry: geometry))
        }
        #expect(boundary.totalByteCount == 133_724_672)
        let firstFull = TileCoordinate(column: 510, row: 0)
        let firstFullGeometry = try #require(boundaryGrid.geometry(at: firstFull))
        #expect(boundary.insert(510, geometry: firstFullGeometry))
        #expect(boundary.totalByteCount == 133_986_816)
        #expect(boundary.evictionCount == 0)
        let secondFull = TileCoordinate(column: 511, row: 0)
        let secondFullGeometry = try #require(boundaryGrid.geometry(at: secondFull))
        #expect(boundary.insert(511, geometry: secondFullGeometry))
        #expect(boundary.totalByteCount == 134_217_728)
        #expect(boundary.evictionCount == 1)
        #expect(!boundary.coordinates.contains(corner))
        #expect(boundary.coordinates.contains(firstFull))
        #expect(boundary.coordinates.contains(secondFull))
    }

    @Test func verify031FrozenLRUAndGenerationBehavior() throws {
        let grid = try TileGrid(documentWidth: 4 * 256, documentHeight: 256)
        let cache = TileCache<String>(byteBudget: 3 * TileGrid.fullTileByteCount)
        let coordinates = (0..<4).map { TileCoordinate(column: $0, row: 0) }
        for (value, coordinate) in zip(["A", "B", "C"], coordinates) {
            let geometry = try #require(grid.geometry(at: coordinate))
            #expect(cache.insert(value, geometry: geometry))
        }
        #expect(cache.value(for: coordinates[0]) == "A")
        let dGeometry = try #require(grid.geometry(at: coordinates[3]))
        #expect(cache.insert("D", geometry: dGeometry))
        #expect(cache.coordinates == [coordinates[0], coordinates[2], coordinates[3]])
        #expect(cache.evictionCount == 1)
        cache.bumpGeneration()
        #expect(cache.generation == 1)
        #expect(cache.count == 0)
        #expect(cache.totalByteCount == 0)
    }

    private func coordinates(columns: ClosedRange<Int>, rows: ClosedRange<Int>) -> Set<TileCoordinate> {
        Set(rows.flatMap { row in columns.map { TileCoordinate(column: $0, row: row) } })
    }
}
