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

let activity = ProcessInfo.processInfo.beginActivity(
    options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled], reason: "BENCH-R3.5")
defer { ProcessInfo.processInfo.endActivity(activity) }
print("BENCH_METADATA warmup_frames=60 measured_frames=300 production_paths=true")
let base = try referenceDocument()
let destination = context()
let coldStart = ContinuousClock.now
CoreGraphicsRenderer().render(base, in: destination)
let coldOpenMilliseconds = milliseconds(coldStart.duration(to: .now))

var dragDocument = base
let dragCache = SceneBitmapCache()
var revision: UInt64 = 0
let bench1 = measure { index in
    revision += 1
    _ = dragDocument.translateNode(id: id(0), documentDX: index.isMultiple(of: 2) ? 1 : -1, documentDY: 0)
    dragCache.render(dragDocument, revision: revision, in: destination, viewport: RenderViewport())
}
printStats("BENCH-1 drag", bench1)

let panCache = SceneBitmapCache()
let bench2 = measure { index in
    panCache.render(base, revision: 1, in: destination, viewport: RenderViewport(pan: Point(x: Double(index), y: 0)))
}
printStats("BENCH-2 pan", bench2)

let stripCache = ViewportStripCache()
var priorStripCount = 0
let bench2b = measure { index in
    stripCache.render(
        base, revision: 1, in: destination,
        viewport: RenderViewport(zoom: 2, pan: Point(x: -Double(index * 2), y: 0)),
        pixelWidth: 800, pixelHeight: 500)
    let current = stripCache.redrawnStripCount
    precondition(current > priorStripCount, "BENCH-2b must redraw a nonzero strip every frame")
    priorStripCount = current
}
printStats("BENCH-2b forced-exposure pan", bench2b)
print("BENCH-2b strip_redraw_frames=360 nonzero_every_frame=true")

let zoomCache = SceneBitmapCache()
let bench3 = measure { index in
    let zoom = 0.8 + Double(index % 60) / 100
    zoomCache.render(base, revision: 1, in: destination, viewport: RenderViewport(zoom: zoom))
}
printStats("BENCH-3 zoom", bench3)
let settleStart = ContinuousClock.now
zoomCache.render(base, revision: 1, in: destination, viewport: RenderViewport(zoom: 1.4))
print(String(format: "BENCH-3 settle: %.3f ms", milliseconds(settleStart.duration(to: .now))))

let warmFullStart = ContinuousClock.now
CoreGraphicsRenderer().render(base, in: destination)
print(String(format: "BENCH-4 cold-open: %.3f ms", coldOpenMilliseconds))
print(String(format: "Warm full redraw: %.3f ms", milliseconds(warmFullStart.duration(to: .now))))

let deltaFlag = DeltaHistoryFeatureFlag.environment()
precondition(deltaFlag.isEnabled, "BENCH-5 requires OPENDRAW_DELTA_HISTORY=1")
var applyHistory = try DeltaCommandHistory(document: base, featureFlag: deltaFlag)
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
let bench5a = try measure { index in
    if index.isMultiple(of: 2) {
        try applyHistory.undo()
    } else {
        try applyHistory.redo()
    }
}
printStats("BENCH-5a undo-redo", bench5a)

var recordHistory = try DeltaCommandHistory(document: base, featureFlag: deltaFlag)
let structuralNode = base.layers[0].nodes[0]
let bench5b = try measure { index in
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
printStats("BENCH-5b record", bench5b)
print("BENCH-5 mix=structural,composite,anchor-slice flag=ON")
precondition(bench5a.p95 <= 16.7, "BENCH-5a p95 exceeds frozen 16.7 ms target")
precondition(bench5b.p95 <= 1.0, "BENCH-5b p95 exceeds frozen 1.0 ms target")
