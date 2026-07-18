import AppKit
import EditorCore

/// OpenDraw's complete UI token namespace. Shell code must not introduce
/// colors, fonts, spacing, radii, or component metrics outside this type.
@MainActor enum Theme {
    enum Color {
        static let workspace = NSColor.underPageBackgroundColor
        static let artboard = NSColor.white
        static let panelMaterial = NSVisualEffectView.Material.sidebar
        static let toolbarMaterial = NSVisualEffectView.Material.titlebar
        static let separator = NSColor.separatorColor
        static let fieldBackground = NSColor.textBackgroundColor
        static let textPrimary = NSColor.labelColor
        static let textSecondary = NSColor.secondaryLabelColor
        static let textTertiary = NSColor.tertiaryLabelColor
        static let accent = NSColor.controlAccentColor
        static let handleFill = NSColor.white
        static let handleStroke = NSColor.controlAccentColor
        static let directionStem = NSColor.controlAccentColor.withAlphaComponent(0.6)
        static let guideSnap = NSColor.systemRed

        static let artboardShadow = adaptive(
            dark: literal(0x000000, alpha: 0.55),
            light: literal(0x000000, alpha: 0.18))
        static let controlHover = adaptive(
            dark: literal(0xFFFFFF, alpha: 0.07),
            light: literal(0x000000, alpha: 0.05))
        static let controlActiveBackground = adaptive(
            dark: literal(0x0A84FF, alpha: 0.22),
            light: literal(0x007AFF, alpha: 0.15))
        static let iconRest = adaptive(
            dark: literal(0xFFFFFF, alpha: 0.75),
            light: literal(0x000000, alpha: 0.70))
        static let badgeReadoutBackground = literal(0x141416, alpha: 0.88)
        static let marqueeFill = adaptive(
            dark: literal(0x0A84FF, alpha: 0.08),
            light: literal(0x007AFF, alpha: 0.08))

        static func appKit(_ value: SRGBColor?) -> NSColor {
            guard let value else { return artboard }
            return NSColor(
                srgbRed: value.red, green: value.green, blue: value.blue,
                alpha: value.alpha)
        }

        static func srgb(_ color: NSColor) -> SRGBColor {
            let value = color.usingColorSpace(.sRGB) ?? color
            return SRGBColor(
                red: value.redComponent, green: value.greenComponent,
                blue: value.blueComponent, alpha: value.alphaComponent)
        }

        private static func adaptive(dark: NSColor, light: NSColor) -> NSColor {
            NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            }
        }

        private static func literal(_ rgb: UInt32, alpha: CGFloat = 1) -> NSColor {
            let red = CGFloat((rgb >> 16) & 0xFF) / 255
            let green = CGFloat((rgb >> 8) & 0xFF) / 255
            let blue = CGFloat(rgb & 0xFF) / 255
            return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
        }
    }

    enum Spacing {
        static let hairline: CGFloat = 2
        static let intraControl: CGFloat = 4
        static let iconLabel: CGFloat = 6
        static let controlRow: CGFloat = 8
        static let section: CGFloat = 12
        static let panel: CGFloat = 16
        static let gutter: CGFloat = 20
    }

    enum Radius {
        static let checkStepper: CGFloat = 3
        static let fieldButton: CGFloat = 5
        static let toolWell: CGFloat = 6
        static let chip: CGFloat = 8
        static let window: CGFloat = 10
    }

    @MainActor enum Font {
        static var windowTitle: NSFont { NSFont.systemFont(ofSize: 13, weight: .semibold) }
        static var control: NSFont { NSFont.systemFont(ofSize: 13, weight: .regular) }
        static var layer: NSFont { NSFont.systemFont(ofSize: 12, weight: .regular) }
        static var section: NSFont { NSFont.systemFont(ofSize: 11, weight: .semibold) }
        static var fieldLabel: NSFont { NSFont.systemFont(ofSize: 11, weight: .regular) }
        static var numeric: NSFont { NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular) }
        static var badge: NSFont { NSFont.monospacedSystemFont(ofSize: 10.5, weight: .medium) }
        static var zoom: NSFont { NSFont.monospacedSystemFont(ofSize: 11, weight: .regular) }
    }

    enum Metric {
        static let railWidth: CGFloat = 44
        static let railButton: CGFloat = 32
        static let railIcon: CGFloat = 18
        static let railSeparatorWidth: CGFloat = 24
        static let toolbarIcon: CGFloat = 17
        static let toolbarButtonWidth: CGFloat = 30
        static let toolbarButtonHeight: CGFloat = 26
        static let toolbarZoomReadoutWidth: CGFloat = 52
        static let layersWidth: CGFloat = 190
        static let inspectorWidth: CGFloat = 252
        static let layerRowHeight: CGFloat = 28
        static let inspectorFieldHeight: CGFloat = 22
        static let inspectorLabelWidth: CGFloat = 18
        static let inspectorFieldWidth: CGFloat = 80
        static let inspectorNumericTextWidth: CGFloat = 62
        static let inspectorStepperWidth: CGFloat = 18
        static let stackFlush: CGFloat = 0
        static let colorWellWidth: CGFloat = 26
        static let colorWellHeight: CGFloat = 16
        static let iconStrokeWidth: CGFloat = 1.6
        static let iconGrid: CGFloat = 24
        static let artboardInset: CGFloat = 24
        static let gradientPopoverWidth: CGFloat = 260
        static let gradientPopoverHeight: CGFloat = 190
    }

    enum DefaultValue {
        static let gradientStart = "0,0"
        static let gradientEnd = "100,0"
        static let gradientStops = "0:#000000, 1:#FFFFFF"
    }
}
