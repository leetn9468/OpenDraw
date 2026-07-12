import AppKit
import EditorCore

public enum BackingScale {
    @MainActor
    public static func pixels(for points: CGFloat, in window: NSWindow?) -> CGFloat {
        points * (window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1)
    }
}
