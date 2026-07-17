import CanvasRender
import DocumentModel
import EditorCommands
import EditorCore
import Foundation
import Geometry
import Testing

private let corpusSeed: UInt64 = 0x0000_0000_A110_F00D

private enum CorpusOperation: String, Hashable {
    case valueSwap
    case structural
    case reorder
    case undo
    case redo
    case gestureFrame
    case zoomChange
}

private struct CorpusPlan {
    let step: Int
    let operation: CorpusOperation
    let subtype: String
    let draws: [UInt64]
}

private struct CorpusLCG {
    var state: UInt64 = corpusSeed
    var advances = 0

    mutating func draw() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1
        advances += 1
        return state >> 33
    }
}

private struct CorpusObject {
    let id: ObjectID
    let parent: SceneParent
    let childIndex: Int
    let siblingCount: Int
}

@Suite
struct TileInvalidationCorpusT2VerifyTests {
    @Test func verify033FrozenSeededInvalidationCompletenessCorpus() throws {
        let planning = makeCorpusPlan()
        let plans = planning.plans
        let counts = Dictionary(grouping: plans, by: \.operation).mapValues(\.count)
        let insertCount = plans.count { $0.operation == .structural && $0.subtype == "insert" }
        let deleteCount = plans.count { $0.operation == .structural && $0.subtype == "delete" }
        let openCount = plans.count { $0.operation == .gestureFrame && $0.subtype == "open" }
        let continueCount = plans.count { $0.operation == .gestureFrame && $0.subtype == "continue" }
        let zoomTransitions = plannedZoomTransitions(plans)

        print("CORPUS_DISTRIBUTION seed=0x00000000A110F00D steps=64 advances=\(planning.advances)")
        print(
            "operations=valueSwap:\(counts[.valueSwap, default: 0]) "
                + "structural:\(counts[.structural, default: 0]) "
                + "reorder:\(counts[.reorder, default: 0]) "
                + "undo:\(counts[.undo, default: 0]) redo:\(counts[.redo, default: 0]) "
                + "gestureFrame:\(counts[.gestureFrame, default: 0]) "
                + "zoomChange:\(counts[.zoomChange, default: 0])")
        print("structural=insert:\(insertCount) delete:\(deleteCount)")
        print("gesture_frames=open:\(openCount) continue:\(continueCount)")
        print("zoom_changes=\(zoomTransitions.joined(separator: " "))")
        print("last_step=(\(plans.last!.step), '\(plans.last!.operation.rawValue)', \(planning.advances))")

        let distributionMatches =
            plans.count == 64 && planning.advances == 205
            && counts[.valueSwap] == 15 && counts[.structural] == 21
            && counts[.reorder] == 5 && counts[.undo] == 8 && counts[.redo] == 5
            && counts[.gestureFrame] == 6 && counts[.zoomChange] == 4
            && insertCount == 11 && deleteCount == 10 && openCount == 6 && continueCount == 0
            && zoomTransitions
                == [
                    "step2:1.0->1.0", "step14:1.0->1.5",
                    "step19:1.5->0.5", "step38:0.5->0.5",
                ]
        guard distributionMatches else {
            Issue.record("VERIFY-033 frozen distribution diverged; mutation assertions were not run")
            return
        }

        var history = try DeltaCommandHistory(document: corpusReferenceDocument())
        let renderer = TileCompositeRenderer()
        renderer.subscribe(to: history)
        var zoom = 1.0
        var openGesture: GestureID?
        let warmWidth = Int(ceil(history.document.width * zoom))
        let warmHeight = Int(ceil(history.document.height * zoom))
        let warm = try compositeImage(
            history.document, renderer: renderer, width: warmWidth, height: warmHeight, zoom: zoom)
        #expect(warm.1.renderedTiles.count == 8)
        renderer.clearInvalidationRecords()

        for plan in plans {
            let recordStart = renderer.invalidationRecords.count
            if plan.operation != .gestureFrame, let gesture = openGesture {
                _ = try history.endGesture(gesture)
                openGesture = nil
            }

            try applyCorpusPlan(plan, history: &history, zoom: &zoom, openGesture: &openGesture)
            try assertCorpusComposite(
                plan: plan, recordStart: recordStart, history: history,
                renderer: renderer, zoom: zoom)
        }

        if let gesture = openGesture {
            let finalPlan = CorpusPlan(
                step: 64, operation: .gestureFrame, subtype: "corpus-end-commit", draws: [])
            let recordStart = renderer.invalidationRecords.count
            _ = try history.endGesture(gesture)
            try assertCorpusComposite(
                plan: finalPlan, recordStart: recordStart, history: history,
                renderer: renderer, zoom: zoom)
        }
    }
}

private func makeCorpusPlan() -> (plans: [CorpusPlan], advances: Int) {
    var generator = CorpusLCG()
    var openGesture = false
    var plans: [CorpusPlan] = []
    for step in 1...64 {
        let selector = generator.draw()
        let operation: CorpusOperation
        switch selector % 100 {
        case 0...29: operation = .valueSwap
        case 30...49: operation = .structural
        case 50...59: operation = .reorder
        case 60...74: operation = .undo
        case 75...84: operation = .redo
        case 85...94: operation = .gestureFrame
        default: operation = .zoomChange
        }
        if operation != .gestureFrame { openGesture = false }
        var draws = [selector]
        let subtype: String
        switch operation {
        case .valueSwap:
            draws.append(contentsOf: [generator.draw(), generator.draw(), generator.draw()])
            subtype = "translate"
        case .structural:
            let s = generator.draw()
            draws.append(s)
            if s % 2 == 0 {
                draws.append(contentsOf: [generator.draw(), generator.draw(), generator.draw()])
                subtype = "insert"
            } else {
                draws.append(generator.draw())
                subtype = "delete"
            }
        case .reorder:
            draws.append(contentsOf: [generator.draw(), generator.draw()])
            subtype = "sibling"
        case .undo, .redo:
            subtype = "stack"
        case .gestureFrame:
            if openGesture {
                draws.append(contentsOf: [generator.draw(), generator.draw()])
                subtype = "continue"
            } else {
                draws.append(contentsOf: [generator.draw(), generator.draw(), generator.draw()])
                openGesture = true
                subtype = "open"
            }
        case .zoomChange:
            draws.append(generator.draw())
            subtype = "selection"
        }
        plans.append(CorpusPlan(step: step, operation: operation, subtype: subtype, draws: draws))
    }
    return (plans, generator.advances)
}

private func plannedZoomTransitions(_ plans: [CorpusPlan]) -> [String] {
    let choices = [0.5, 1.0, 1.5, 2.0]
    var zoom = 1.0
    return plans.compactMap { plan in
        guard plan.operation == .zoomChange else { return nil }
        let old = zoom
        zoom = choices[Int(plan.draws[1] % 4)]
        return "step\(plan.step):\(old)->\(zoom)"
    }
}

private func applyCorpusPlan(
    _ plan: CorpusPlan, history: inout DeltaCommandHistory,
    zoom: inout Double, openGesture: inout GestureID?
) throws {
    switch plan.operation {
    case .valueSwap:
        let objects = corpusObjects(in: history.document)
        let target = objects[Int(plan.draws[1] % UInt64(objects.count))]
        let dx = Double(Int(plan.draws[2] % 201) - 100)
        let dy = Double(Int(plan.draws[3] % 201) - 100)
        var transform = corpusTransform(
            try StructuralCommands.slot(for: target.id, in: history.document).node)
        transform.tx += dx
        transform.ty += dy
        _ = try history.commit(
            ValueSwapCommands.transform(
                in: history.document, nodeID: target.id, newValue: transform))
    case .structural:
        if plan.subtype == "insert" {
            let layer = history.document.layers[0]
            let index = Int(plan.draws[2] % UInt64(layer.nodes.count + 1))
            let x = Double(plan.draws[3] % 761)
            let y = Double(plan.draws[4] % 461)
            let path = rectanglePath(
                minX: x, minY: y, maxX: x + 40, maxY: y + 40,
                style: PathStyle(fill: .black, stroke: nil))
            var fixedPath = path
            fixedPath.id = corpusInsertedID(plan.step)
            _ = try history.commit(
                StructuralCommands.insert(
                    .path(fixedPath), in: history.document,
                    parent: .layer(layer.id), at: index, name: "Corpus insert"))
        } else {
            let objects = corpusObjects(in: history.document)
            guard !objects.isEmpty else { return }
            let victim = objects[Int(plan.draws[2] % UInt64(objects.count))]
            _ = try history.commit(
                StructuralCommands.delete(nodeIDs: [victim.id], in: history.document))
        }
    case .reorder:
        let candidates = corpusObjects(in: history.document).filter { $0.siblingCount >= 2 }
        guard !candidates.isEmpty else { return }
        let candidate = candidates[Int(plan.draws[1] % UInt64(candidates.count))]
        let newIndex = Int(plan.draws[2] % UInt64(candidate.siblingCount))
        _ = try history.commit(
            StructuralCommands.reorderNode(
                in: history.document, nodeID: candidate.id,
                to: candidate.parent, at: newIndex))
    case .undo:
        _ = try history.undo()
    case .redo:
        _ = try history.redo()
    case .gestureFrame:
        if let gesture = openGesture {
            let dx = Double(Int(plan.draws[1] % 201) - 100)
            let dy = Double(Int(plan.draws[2] % 201) - 100)
            try history.updateDocumentTransformGesture(
                gesture, documentTransform: Geometry.AffineTransform(tx: dx, ty: dy))
        } else {
            let objects = corpusObjects(in: history.document)
            let target = objects[Int(plan.draws[1] % UInt64(objects.count))]
            let dx = Double(Int(plan.draws[2] % 201) - 100)
            let dy = Double(Int(plan.draws[3] % 201) - 100)
            let gesture = try history.beginTransformGesture(nodeID: target.id)
            openGesture = gesture
            try history.updateDocumentTransformGesture(
                gesture, documentTransform: Geometry.AffineTransform(tx: dx, ty: dy))
        }
    case .zoomChange:
        zoom = [0.5, 1.0, 1.5, 2.0][Int(plan.draws[1] % 4)]
    }
}

private func assertCorpusComposite(
    plan: CorpusPlan, recordStart: Int, history: DeltaCommandHistory,
    renderer: TileCompositeRenderer, zoom: Double
) throws {
    let width = Int(ceil(history.document.width * zoom))
    let height = Int(ceil(history.document.height * zoom))
    let direct = try directImage(
        history.document, width: width, height: height, deviceScale: zoom)
    let composite = try compositeImage(
        history.document, renderer: renderer, width: width, height: height, zoom: zoom)
    let difference = try compare(composite.0, direct)
    let records = Array(renderer.invalidationRecords.dropFirst(recordStart))
    let rendered = Set(composite.1.renderedTiles)
    let generationBumped = records.contains(where: \.didBumpGeneration)
    var expected = Set<TileCoordinate>()
    for record in records { expected.formUnion(record.invalidatedCoordinates) }

    var offending = Set<TileCoordinate>()
    var renderSetPasses: Bool
    if generationBumped {
        let requested = Set(composite.1.visibleCoordinates)
        renderSetPasses = rendered == requested
        offending = rendered.symmetricDifference(requested)
    } else if expected.isEmpty {
        renderSetPasses = rendered.isEmpty
        offending = rendered
    } else {
        renderSetPasses = rendered.isSubset(of: expected)
        offending = rendered.subtracting(expected)
    }
    if !renderSetPasses || difference.differingPixels != 0 || !difference.passesFrozenInstrument {
        let tileText = corpusTileList(offending.isEmpty ? rendered : offending)
        print(
            "CORPUS_FAILURE step=\(plan.step) operation=\(plan.operation.rawValue) "
                + "subtype=\(plan.subtype) draws_consumed=\(plan.draws.count) "
                + "seed=0x00000000A110F00D offending_tiles=\(tileText) "
                + "differing_pixels=\(difference.differingPixels)")
        Issue.record("VERIFY-033 step \(plan.step) invalidation completeness failure")
    }
}

private func corpusObjects(in document: EditorDocument) -> [CorpusObject] {
    var result: [CorpusObject] = []
    for layer in document.layers {
        appendCorpusObjects(layer.nodes, parent: .layer(layer.id), to: &result)
    }
    return result
}

private func appendCorpusObjects(
    _ nodes: [SceneNode], parent: SceneParent, to result: inout [CorpusObject]
) {
    for (index, node) in nodes.enumerated() {
        result.append(
            CorpusObject(
                id: node.id, parent: parent, childIndex: index,
                siblingCount: nodes.count))
        if case .group(let group) = node {
            appendCorpusObjects(group.children, parent: .group(group.id), to: &result)
        }
    }
}

private func corpusTransform(_ node: SceneNode) -> Geometry.AffineTransform {
    switch node {
    case .path(let path): return path.transform
    case .text(let text): return text.transform
    case .image(let image): return image.transform
    case .group(let group): return group.transform
    }
}

private func corpusReferenceDocument() throws -> EditorDocument {
    var nodes: [SceneNode] = []
    for index in 0..<1_000 {
        let x = Double((index % 40) * 20)
        let y = Double((index / 40) * 20)
        let path = PathObject(
            id: corpusReferenceID(index),
            segments: [
                CubicBezier(
                    start: Point(x: x, y: y), control1: Point(x: x + 4, y: y),
                    control2: Point(x: x + 8, y: y + 8), end: Point(x: x + 12, y: y + 12))
            ], style: PathStyle(fill: nil, stroke: .black, strokeWidth: 1))
        switch index % 4 {
        case 0: nodes.append(.path(path))
        case 1:
            nodes.append(
                .text(
                    TextObject(
                        id: corpusReferenceID(index), text: "R\(index)",
                        origin: Point(x: x, y: y + 12), fontSize: 10)))
        case 2:
            var child = path
            child.id = corpusReferenceID(1_000 + index)
            nodes.append(
                .group(
                    GroupNode(
                        id: corpusReferenceID(index), name: "G\(index)",
                        children: [.path(child)])))
        default:
            nodes.append(
                .image(
                    ImageObject(
                        id: corpusReferenceID(index),
                        frame: Rect(minX: x, minY: y, maxX: x + 12, maxY: y + 12),
                        storage: .linked(relativePath: "asset.png"),
                        pixelWidth: 1, pixelHeight: 1)))
        }
    }
    return try EditorDocument(
        width: 800, height: 500,
        layers: [Layer(name: "Benchmark", nodes: nodes)])
}

private func corpusReferenceID(_ index: Int) -> ObjectID {
    let suffix = String(format: "%012X", index)
    return ObjectID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!)
}

private func corpusInsertedID(_ step: Int) -> ObjectID {
    let suffix = String(format: "%012X", 0xF000_0000 + step)
    return ObjectID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!)
}

private func corpusTileList(_ coordinates: Set<TileCoordinate>) -> String {
    coordinates.sorted {
        ($0.row, $0.column) < ($1.row, $1.column)
    }.map { "(\($0.column),\($0.row))" }.joined(separator: ",")
}
