import CanvasRender
import CoreGraphics
import DocumentModel
import EditorCommands
import EditorCore
import Foundation
import Geometry

struct Statistics {
    var p50: Double
    var p95: Double
    var maximum: Double
}
let benchmarkEnvironment = ProcessInfo.processInfo.environment
let bench5bEnforcementEnabled = benchmarkEnvironment["BENCH5B_ENFORCEMENT"] != "off"
let benchmarkGateFixture = benchmarkEnvironment["BENCHMARK_GATE_FIXTURE"]

func milliseconds(_ duration: Duration) -> Double {
    let c = duration.components
    return Double(c.seconds) * 1_000 + Double(c.attoseconds) / 1_000_000_000_000_000
}
// Gate/test-side numeric policy: nearest-rank percentile, one-based rank
// ceil(p * sampleCount), converted to a zero-based index. A single sample always
// selects index zero. This does not define production editor behavior.
func nearestRank(_ samples: [Double], percentile: Double) -> Double {
    let rank = max(1, Int(ceil(percentile * Double(samples.count))))
    return samples[min(samples.count - 1, rank - 1)]
}
func measure(warmup: Int = 60, frames: Int = 300, _ frame: (Int) throws -> Void) rethrows -> Statistics {
    for index in 0..<warmup { try frame(index) }
    var samples: [Double] = []
    for index in 0..<frames {
        let start = ContinuousClock.now
        try frame(index + warmup)
        samples.append(milliseconds(start.duration(to: .now)))
    }
    samples.sort()
    return Statistics(
        p50: nearestRank(samples, percentile: 0.50),
        p95: nearestRank(samples, percentile: 0.95), maximum: samples.last!)
}
func id(_ index: Int) -> ObjectID {
    let suffix = String(format: "%012X", index)
    return ObjectID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!)
}
func referenceDocument() throws -> EditorDocument {
    var nodes: [SceneNode] = []
    for index in 0..<1_000 {
        let x = Double((index % 40) * 20)
        let y = Double((index / 40) * 20)
        let path = PathObject(
            id: id(index),
            segments: [
                CubicBezier(
                    start: Point(x: x, y: y), control1: Point(x: x + 4, y: y), control2: Point(x: x + 8, y: y + 8),
                    end: Point(x: x + 12, y: y + 12))
            ],
            style: PathStyle(fill: nil, stroke: .black, strokeWidth: 1))
        switch index % 4 {
        case 0: nodes.append(.path(path))
        case 1:
            nodes.append(
                .text(TextObject(id: id(index), text: "R\(index)", origin: Point(x: x, y: y + 12), fontSize: 10)))
        case 2:
            var child = path
            child.id = id(1_000 + index)
            nodes.append(.group(GroupNode(id: id(index), name: "G\(index)", children: [.path(child)])))
        default:
            nodes.append(
                .image(
                    ImageObject(
                        id: id(index), frame: Rect(minX: x, minY: y, maxX: x + 12, maxY: y + 12),
                        storage: .linked(relativePath: "asset.png"), pixelWidth: 1, pixelHeight: 1)))
        }
    }
    return try EditorDocument(width: 800, height: 500, layers: [Layer(name: "Benchmark", nodes: nodes)])
}
func context() -> CGContext {
    CGContext(
        data: nil, width: 800, height: 500, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func printStats(_ name: String, _ value: Statistics) {
    print(String(format: "%@: p50 %.3f ms | p95 %.3f ms | max %.3f ms", name, value.p50, value.p95, value.maximum))
}
func applyingGateFixture(_ value: Statistics, gate: String, forcedP95: Double) -> Statistics {
    let forcesGate =
        benchmarkGateFixture == gate
        || benchmarkGateFixture == "bench5a-and-b-overrun"
    guard forcesGate else { return value }
    let p95 = max(value.p95, forcedP95)
    return Statistics(p50: min(value.p50, p95), p95: p95, maximum: max(value.maximum, p95))
}

let activity = ProcessInfo.processInfo.beginActivity(
    options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled], reason: "BENCH-R3.5")
defer { ProcessInfo.processInfo.endActivity(activity) }
print(
    "BENCH_METADATA warmup_frames=60 measured_frames=300 production_paths=true "
        + "bench5b_enforcement=\(bench5bEnforcementEnabled ? "on" : "off") "
        + "renderer=tile-composite bench2b_fixture=exposure-corridor")
if let benchmarkGateFixture {
    print("BENCH_GATE_FIXTURE=\(benchmarkGateFixture)")
}
let base = try referenceDocument()
let destination = context()
let baseGrid = try TileGrid(documentWidth: base.width, documentHeight: base.height)
let coldStart = ContinuousClock.now
let coldRenderer = TileCompositeRenderer()
_ = try coldRenderer.composite(base, in: destination)
let coldOpenMilliseconds = milliseconds(coldStart.duration(to: .now))

var dragHistory = try DeltaCommandHistory(document: base)
let dragRenderer = TileCompositeRenderer()
dragRenderer.subscribe(to: dragHistory)
_ = try dragRenderer.composite(dragHistory.document, in: destination)
let bench1 = try measure { index in
    let direction = index.isMultiple(of: 2) ? 1.0 : -1.0
    var transform = dragHistory.document.path(id: id(0))!.transform
    transform.tx += direction
    let edit = try ValueSwapCommands.transform(
        in: dragHistory.document, nodeID: id(0), newValue: transform)
    let expected = TileDamageMapper.map(edit.damageBounds.documentDamage, in: baseGrid)
        .resolvedCoordinates(in: baseGrid)
    try dragHistory.commit(edit)
    let frame = try dragRenderer.composite(dragHistory.document, in: destination)
    precondition(!frame.hitTiles.isEmpty, "BENCH-1 requires clean cache hits")
    precondition(
        Set(frame.renderedTiles) == expected,
        "BENCH-1 rendered tiles must exactly equal mapped edit damage")
}
printStats("BENCH-1 drag", bench1)

let panRenderer = TileCompositeRenderer()
_ = try panRenderer.composite(base, in: destination)
let bench2 = try measure { index in
    let visibleRect = DevicePixelRect(
        minX: index, minY: 0, maxX: index + 800, maxY: 500)
    let frame = try panRenderer.composite(
        base, in: destination, visibleDeviceRect: visibleRect)
    precondition(frame.renderedTiles.isEmpty, "BENCH-2 warm pan must be hit-dominated")
    precondition(!frame.hitTiles.isEmpty, "BENCH-2 warm pan requires cache hits")
}
printStats("BENCH-2 pan", bench2)

let corridor = try TileExposureCorridor.document()
let corridorRenderer = TileCompositeRenderer()
let corridorDestination = context()
let corridorGrid = try TileGrid(
    documentWidth: corridor.width, documentHeight: corridor.height,
    zoom: TileExposureCorridor.zoom,
    backingScale: TileExposureCorridor.backingScale)
precondition(corridorGrid.canvasWidth == 92_960 && corridorGrid.canvasHeight == 500)
let corridorSetup = try corridorRenderer.composite(
    corridor, in: corridorDestination, zoom: TileExposureCorridor.zoom,
    backingScale: TileExposureCorridor.backingScale,
    visibleDeviceRect: TileExposureCorridor.setupVisibleRect)
precondition(
    Set(corridorSetup.renderedTiles) == TileExposureCorridor.expectedSetupTiles(),
    "BENCH-2b setup must render exactly columns 0...3")
precondition(corridorSetup.hitTiles.isEmpty, "BENCH-2b setup cannot contain hits")
var corridorRenderedRegions = Set(corridorSetup.renderedTiles)
let bench2b = try measure { zeroBasedFrame in
    let frameIndex = zeroBasedFrame + 1
    let visibleRect = TileExposureCorridor.visibleRect(frame: frameIndex)
    let expectedRendered = TileExposureCorridor.expectedRenderedTiles(frame: frameIndex)
    precondition(
        expectedRendered.isDisjoint(with: corridorRenderedRegions),
        "BENCH-2b cannot expose an already-rendered region")
    let frame = try corridorRenderer.composite(
        corridor, in: corridorDestination, zoom: TileExposureCorridor.zoom,
        backingScale: TileExposureCorridor.backingScale,
        visibleDeviceRect: visibleRect)
    let rendered = Set(frame.renderedTiles)
    let hits = Set(frame.hitTiles)
    let visible = Set(corridorGrid.coordinates(intersecting: visibleRect))
    precondition(
        rendered == expectedRendered,
        "BENCH-2b frame \(frameIndex) rendered \(rendered), expected \(expectedRendered)")
    precondition(!rendered.isEmpty, "BENCH-2b cannot have a zero-render frame")
    precondition(
        hits == visible.subtracting(expectedRendered),
        "BENCH-2b all non-new visible tiles must composite as hits")
    precondition(
        hits.isSubset(of: corridorRenderedRegions),
        "BENCH-2b cannot serve a never-rendered region as a hit")
    corridorRenderedRegions.formUnion(rendered)
}
printStats("BENCH-2b exposure corridor", bench2b)
print(
    "BENCH-2b exact_indices=true setup_columns=0...3 frame_formula=(f+3,0),(f+3,1) "
        + "frames=1...360 warmup=1...60 measured=61...360 rendered_regions=\(corridorRenderedRegions.count)")

let zoomRenderer = TileCompositeRenderer()
let bench3 = measure { index in
    let zoom = 0.8 + Double(index % 60) / 100
    zoomRenderer.renderZoomGestureDirect(
        base, in: destination, viewport: RenderViewport(zoom: zoom))
}
printStats("BENCH-3 zoom", bench3)
let settleStart = ContinuousClock.now
_ = try zoomRenderer.composite(base, in: destination, zoom: 1.4)
let bench3Settle = milliseconds(settleStart.duration(to: .now))
print(String(format: "BENCH-3 settle: %.3f ms", bench3Settle))

let warmFullStart = ContinuousClock.now
_ = try coldRenderer.composite(base, in: destination)
print(String(format: "BENCH-4 cold-open: %.3f ms", coldOpenMilliseconds))
print(String(format: "Warm full redraw: %.3f ms", milliseconds(warmFullStart.duration(to: .now))))

var applyHistory = try DeltaCommandHistory(document: base)
let benchmarkLayerID = base.layers[0].id
let benchmarkAnchor = PathAnchorLocation(pathID: id(4), anchorIndex: 0)
let applySlice = try AnchorGeometryCommands.slice(in: applyHistory.document, at: benchmarkAnchor)
let applyComposite = try CompositeCommands.ordered(
    name: "BENCH-5 composite anchor apply",
    children: [
        ValueSwapCommands.transform(
            in: applyHistory.document, nodeID: id(4),
            newValue: Geometry.AffineTransform(tx: 1)),
        AnchorGeometryCommands.setSlice(
            in: applyHistory.document, at: benchmarkAnchor,
            newValue: applySlice.translated(dx: 1, dy: 0)),
    ])
try applyHistory.commit(applyComposite)
let measuredBench5a = try measure { index in
    if index.isMultiple(of: 2) {
        try applyHistory.undo()
    } else {
        try applyHistory.redo()
    }
}
let bench5a = applyingGateFixture(measuredBench5a, gate: "bench5a-overrun", forcedP95: 16.701)
printStats("BENCH-5a undo-redo", bench5a)

var recordHistory = try DeltaCommandHistory(document: base)
let structuralNode = base.layers[0].nodes[0]
let measuredBench5b = try measure { index in
    switch index % 4 {
    case 0:
        try recordHistory.commit(
            StructuralCommands.delete(nodeIDs: [structuralNode.id], in: recordHistory.document))
    case 1:
        try recordHistory.commit(
            StructuralCommands.insert(
                structuralNode, in: recordHistory.document, parent: .layer(benchmarkLayerID), at: 0))
    default:
        let direction = index % 4 == 2 ? 1.0 : -1.0
        let currentPath = recordHistory.document.path(id: id(4))!
        var nextTransform = currentPath.transform
        nextTransform.tx += direction
        let currentSlice = try AnchorGeometryCommands.slice(
            in: recordHistory.document, at: benchmarkAnchor)
        let composite = try CompositeCommands.ordered(
            name: "BENCH-5 composite anchor record",
            children: [
                ValueSwapCommands.transform(
                    in: recordHistory.document, nodeID: id(4), newValue: nextTransform),
                AnchorGeometryCommands.setSlice(
                    in: recordHistory.document, at: benchmarkAnchor,
                    newValue: currentSlice.translated(dx: direction, dy: 0)),
            ])
        try recordHistory.commit(composite)
    }
}
let bench5b = applyingGateFixture(measuredBench5b, gate: "bench5b-overrun", forcedP95: 1.001)
printStats("BENCH-5b record", bench5b)
print("BENCH-5 mix=structural,composite,anchor-slice history=delta-only")
print(
    "BENCH-5b enforcement: bench5b_enforcement=\(bench5bEnforcementEnabled ? "on" : "off") "
        + "result=\(bench5bEnforcementEnabled ? "BLOCKING" : "INFORMATIONAL")")

var tileHistory = try DeltaCommandHistory(document: base)
let tileRenderer = TileCompositeRenderer()
tileRenderer.subscribe(to: tileHistory)
let tileDestination = context()
let tileGrid = try TileGrid(documentWidth: base.width, documentHeight: base.height)
_ = try tileRenderer.composite(tileHistory.document, in: tileDestination)
let measuredBench6 = try measure { index in
    let targetID = id(84)
    let direction = index.isMultiple(of: 2) ? 1.0 : -1.0
    var transform = tileHistory.document.path(id: targetID)!.transform
    transform.tx += direction
    let edit = try ValueSwapCommands.transform(
        in: tileHistory.document, nodeID: targetID, newValue: transform)
    let expected = TileDamageMapper.map(edit.damageBounds.documentDamage, in: tileGrid)
        .resolvedCoordinates(in: tileGrid)
    try tileHistory.commit(edit)
    let frame = try tileRenderer.composite(tileHistory.document, in: tileDestination)
    precondition(!frame.hitTiles.isEmpty, "BENCH-6 requires nonzero cache hits every frame")
    precondition(
        Set(frame.renderedTiles) == expected,
        "BENCH-6 rendered tiles must exactly equal the frozen damage mapping")
}
let bench6 = applyingGateFixture(measuredBench6, gate: "bench6-overrun", forcedP95: 8.001)
printStats("BENCH-6 tile-edit", bench6)
print(
    "BENCH-6 assertions cache_hits=nonzero rendered_tiles=exact_damage_mapping "
        + "warmup_frames=60 measured_frames=300 result=BLOCKING")
print("BENCH-6 sequence=node-84 dx=alternating(+1,-1) dy=0 reference_scene_nodes=1000")
precondition(bench5a.p95 <= 16.7, "BENCH-5a p95 exceeds frozen 16.7 ms target")
precondition(bench1.p95 <= 16.7, "BENCH-1 p95 exceeds frozen 16.7 ms target")
precondition(bench2.p95 <= 16.7, "BENCH-2 p95 exceeds frozen 16.7 ms target")
precondition(bench2b.p95 <= 16.7, "BENCH-2b p95 exceeds frozen 16.7 ms target")
precondition(bench3.p95 <= 33.0, "BENCH-3 p95 exceeds frozen 33 ms target")
precondition(bench3Settle <= 100.0, "BENCH-3 settle exceeds frozen 100 ms target")
if bench5bEnforcementEnabled {
    precondition(bench5b.p95 <= 1.0, "BENCH-5b p95 exceeds frozen 1.0 ms target")
}
precondition(bench6.p95 <= 8.0, "BENCH-6 p95 exceeds frozen 8.0 ms target")
