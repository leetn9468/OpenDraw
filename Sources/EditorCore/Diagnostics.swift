import Foundation
import os

public enum Diagnostics {
    public static let subsystem = "org.opendraw.editor"
    public static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
    public static let documents = Logger(subsystem: subsystem, category: "documents")
    public static let rendering = Logger(subsystem: subsystem, category: "rendering")

    public static func installCrashContext() {
        lifecycle.notice("Process started; crash reports are managed by macOS")
    }
}
