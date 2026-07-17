import DocumentModel
import EditorCommands
import Foundation
import Geometry
import Testing

private final class GestureDamageRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [EditorCommands.DocumentChange] = []

    func append(_ change: EditorCommands.DocumentChange) {
        lock.withLock { storage.append(change) }
    }

    var changes: [EditorCommands.DocumentChange] {
        lock.withLock { storage }
    }
}

@Test
func verifyT2TransformGesturePublishesFrameCommitAndCancellationDamage() throws {
    let path = t2GestureRectangle()
    let original = try EditorDocument(
        width: 512, height: 512,
        layers: [Layer(name: "Gesture damage", nodes: [.path(path)])])

    var committedHistory = try DeltaCommandHistory(document: original)
    let committedRecorder = GestureDamageRecorder()
    let committedObservation = committedHistory.observeChanges { committedRecorder.append($0) }
    let committedGesture = try committedHistory.beginTransformGesture(nodeID: path.id)
    try committedHistory.updateTransformGesture(
        committedGesture, newValue: Geometry.AffineTransform(tx: 100))
    try committedHistory.updateTransformGesture(
        committedGesture, newValue: Geometry.AffineTransform(tx: 200))
    #expect(try committedHistory.endGesture(committedGesture) == .committed)
    withExtendedLifetime(committedObservation) {}

    let committed = committedRecorder.changes
    #expect(committed.count == 3)
    #expect(committed.map(\.kind) == [.gestureFrame, .gestureFrame, .command("Transform gesture")])
    #expect(committed.map(\.revision) == [0, 0, 1])
    #expect(
        committed.map(\.damage)
            == [
                .rects([Rect(minX: 10, minY: 10, maxX: 120, maxY: 20)]),
                .rects([Rect(minX: 110, minY: 10, maxX: 220, maxY: 20)]),
                .rects([Rect(minX: 10, minY: 10, maxX: 220, maxY: 20)]),
            ])

    var cancelledHistory = try DeltaCommandHistory(document: original)
    let cancelledRecorder = GestureDamageRecorder()
    let cancelledObservation = cancelledHistory.observeChanges { cancelledRecorder.append($0) }
    let cancelledGesture = try cancelledHistory.beginTransformGesture(nodeID: path.id)
    try cancelledHistory.updateTransformGesture(
        cancelledGesture, newValue: Geometry.AffineTransform(tx: 50))
    try cancelledHistory.cancelDeltaGesture(cancelledGesture)
    withExtendedLifetime(cancelledObservation) {}

    let cancelled = cancelledRecorder.changes
    #expect(cancelled.count == 2)
    #expect(cancelled.map(\.kind) == [.gestureFrame, .gestureCancelled])
    #expect(cancelled.map(\.revision) == [0, 0])
    #expect(
        cancelled.map(\.damage)
            == [
                .rects([Rect(minX: 10, minY: 10, maxX: 70, maxY: 20)]),
                .rects([Rect(minX: 10, minY: 10, maxX: 70, maxY: 20)]),
            ])
    #expect(cancelledHistory.document == original)
    #expect(cancelledHistory.undoDepth == 0)
}

private func t2GestureRectangle() -> PathObject {
    let points = [
        Point(x: 10, y: 10), Point(x: 20, y: 10), Point(x: 20, y: 20),
        Point(x: 10, y: 20), Point(x: 10, y: 10),
    ]
    return PathObject(
        segments: zip(points, points.dropFirst()).map {
            CubicBezier(start: $0, control1: $0, control2: $1, end: $1)
        }, isClosed: true, style: PathStyle(fill: .black, stroke: nil))
}
