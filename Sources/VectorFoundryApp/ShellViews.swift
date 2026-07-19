import AppKit
import DocumentModel
import EditorCommands
import EditorCore
import EditorTools
import Geometry

private enum ToolGlyph {
    case select, directSelect, pen, rectangle, ellipse, text, image

    /// Accepted design-of-record SVG `d` strings, retained verbatim beside
    /// their NSBezierPath transcriptions.
    var svgPathData: String {
        switch self {
        case .select: "M7 4 L7 17 L10.5 13.8 L13 19 L15.2 18 L12.8 13 L17.5 13 Z"
        case .directSelect:
            "M7 4 L7 15 L10 12.5 L12 17 L14 16 L12.2 11.8 L16 11.8 Z M16.5 16.5 h4 v4 h-4 Z"
        case .pen:
            "M12 3 L16 10 C16 14 14 16 12 17 C10 16 8 14 8 10 Z M12 17 L12 21 M12 10.5 m-1.3 0 a1.3 1.3 0 1 0 2.6 0 a1.3 1.3 0 1 0 -2.6 0"
        case .rectangle: "M4.5 6.5 h15 v11 h-15 Z"
        case .ellipse: "M12 5.5 a7.5 6.5 0 1 0 0 13 a7.5 6.5 0 1 0 0 -13"
        case .text: "M6 6 h12 M12 6 v12 M9.5 18 h5"
        case .image:
            "M4.5 5.5 h15 v13 h-15 Z M4.5 15 l4.5 -4 4 3.5 3.5 -3 3 2.5 M9 9.2 m-1.2 0 a1.2 1.2 0 1 0 2.4 0 a1.2 1.2 0 1 0 -2.4 0"
        }
    }

    func path() -> NSBezierPath {
        let path = NSBezierPath()
        switch self {
        case .select:
            polygon(path, [(7, 4), (7, 17), (10.5, 13.8), (13, 19), (15.2, 18), (12.8, 13), (17.5, 13)])
        case .directSelect:
            polygon(path, [(7, 4), (7, 15), (10, 12.5), (12, 17), (14, 16), (12.2, 11.8), (16, 11.8)])
            path.appendRect(NSRect(x: 16.5, y: 16.5, width: 4, height: 4))
        case .pen:
            path.move(to: NSPoint(x: 12, y: 3))
            path.line(to: NSPoint(x: 16, y: 10))
            path.curve(
                to: NSPoint(x: 12, y: 17), controlPoint1: NSPoint(x: 16, y: 14), controlPoint2: NSPoint(x: 14, y: 16))
            path.curve(
                to: NSPoint(x: 8, y: 10), controlPoint1: NSPoint(x: 10, y: 16), controlPoint2: NSPoint(x: 8, y: 14))
            path.close()
            path.move(to: NSPoint(x: 12, y: 17))
            path.line(to: NSPoint(x: 12, y: 21))
            path.appendOval(in: NSRect(x: 10.7, y: 9.2, width: 2.6, height: 2.6))
        case .rectangle:
            path.appendRect(NSRect(x: 4.5, y: 6.5, width: 15, height: 11))
        case .ellipse:
            path.appendOval(in: NSRect(x: 4.5, y: 5.5, width: 15, height: 13))
        case .text:
            segment(path, (6, 6), (18, 6))
            segment(path, (12, 6), (12, 18))
            segment(path, (9.5, 18), (14.5, 18))
        case .image:
            path.appendRect(NSRect(x: 4.5, y: 5.5, width: 15, height: 13))
            path.move(to: NSPoint(x: 4.5, y: 15))
            for point in [(9.0, 11.0), (13.0, 14.5), (16.5, 11.5), (19.5, 14.0)] {
                path.line(to: NSPoint(x: point.0, y: point.1))
            }
            path.appendOval(in: NSRect(x: 7.8, y: 8, width: 2.4, height: 2.4))
        }
        path.lineWidth = Theme.Metric.iconStrokeWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        return path
    }
}

private func polygon(_ path: NSBezierPath, _ points: [(CGFloat, CGFloat)]) {
    guard let first = points.first else { return }
    path.move(to: NSPoint(x: first.0, y: first.1))
    for point in points.dropFirst() { path.line(to: NSPoint(x: point.0, y: point.1)) }
    path.close()
}

private func segment(_ path: NSBezierPath, _ start: (CGFloat, CGFloat), _ end: (CGFloat, CGFloat)) {
    path.move(to: NSPoint(x: start.0, y: start.1))
    path.line(to: NSPoint(x: end.0, y: end.1))
}

private final class ToolRailButton: NSButton {
    let tool: ActiveTool?
    let glyph: ToolGlyph
    private(set) var hovering = false
    var onVisualChange: (() -> Void)?
    var active = false { didSet { refreshAppearance() } }

    init(label: String, key: String, tool: ActiveTool?, glyph: ToolGlyph) {
        self.tool = tool
        self.glyph = glyph
        super.init(frame: .zero)
        title = ""
        isBordered = false
        bezelStyle = .recessed
        toolTip = "\(label) — \(key)"
        setAccessibilityLabel(label)
        setAccessibilityRole(.button)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: Theme.Metric.railButton).isActive = true
        heightAnchor.constraint(equalToConstant: Theme.Metric.railButton).isActive = true
        refreshAppearance()
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseEnteredAndExited], owner: self))
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        refreshAppearance()
    }
    override func mouseExited(with event: NSEvent) {
        hovering = false
        refreshAppearance()
    }
    private func refreshAppearance() {
        onVisualChange?()
        _ = glyph.svgPathData
    }
}

private final class ToolRailDrawingView: NSView {
    weak var rail: ToolRailView?
    override func draw(_ dirtyRect: NSRect) { rail?.drawButtons() }
}

final class ToolRailView: NSView {
    var onTool: ((ActiveTool) -> Void)?
    var onPlaceImage: (() -> Void)?
    private var buttons: [ToolRailButton] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityLabel("Tools")
        setAccessibilityRole(.group)
        let material = NSVisualEffectView()
        material.material = Theme.Color.panelMaterial
        material.blendingMode = .behindWindow
        material.state = .active
        material.translatesAutoresizingMaskIntoConstraints = false
        addSubview(material)
        let drawing = ToolRailDrawingView()
        drawing.rail = self
        drawing.translatesAutoresizingMaskIntoConstraints = false
        addSubview(drawing, positioned: .above, relativeTo: material)
        NSLayoutConstraint.activate([
            material.leadingAnchor.constraint(equalTo: leadingAnchor),
            material.trailingAnchor.constraint(equalTo: trailingAnchor),
            material.topAnchor.constraint(equalTo: topAnchor), material.bottomAnchor.constraint(equalTo: bottomAnchor),
            drawing.leadingAnchor.constraint(equalTo: leadingAnchor),
            drawing.trailingAnchor.constraint(equalTo: trailingAnchor),
            drawing.topAnchor.constraint(equalTo: topAnchor), drawing.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Theme.Spacing.hairline
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack, positioned: .above, relativeTo: drawing)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Theme.Metric.railWidth),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Theme.Spacing.controlRow),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
        addButton("Select", "V", .selection, .select, to: stack)
        addButton("Direct Select", "A", .directSelection, .directSelect, to: stack)
        addSeparator(to: stack)
        addButton("Pen", "P", .pen, .pen, to: stack)
        addButton("Rectangle", "R", .rectangle, .rectangle, to: stack)
        addButton("Ellipse", "E", .ellipse, .ellipse, to: stack)
        addSeparator(to: stack)
        addButton("Text", "T", .text, .text, to: stack)
        addButton("Place Image", "I", nil, .image, to: stack)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        subviews.compactMap { $0 as? ToolRailDrawingView }.first?.needsDisplay = true
    }

    func updateActiveTool(_ tool: ActiveTool) {
        for button in buttons { button.active = button.tool == tool }
    }

    fileprivate func drawButtons() {
        for button in buttons {
            let frame = button.convert(button.bounds, to: self)
            if button.active || button.hovering {
                (button.active ? Theme.Color.controlActiveBackground : Theme.Color.controlHover).setFill()
                NSBezierPath(
                    roundedRect: frame, xRadius: Theme.Radius.toolWell,
                    yRadius: Theme.Radius.toolWell
                ).fill()
            }
            let scale = Theme.Metric.railIcon / Theme.Metric.iconGrid
            let inset = (Theme.Metric.railButton - Theme.Metric.railIcon) / 2
            let transform = Foundation.AffineTransform(
                m11: scale, m12: 0, m21: 0, m22: -scale,
                tX: frame.minX + inset, tY: frame.maxY - inset)
            let path = button.glyph.path()
            path.transform(using: transform)
            (button.active ? Theme.Color.accent : Theme.Color.iconRest).setStroke()
            path.lineWidth = Theme.Metric.iconStrokeWidth
            path.stroke()
        }
    }

    private func addButton(
        _ label: String, _ key: String, _ tool: ActiveTool?, _ glyph: ToolGlyph, to stack: NSStackView
    ) {
        let button = ToolRailButton(label: label, key: key, tool: tool, glyph: glyph)
        button.target = self
        button.action = #selector(pressed(_:))
        button.onVisualChange = { [weak self] in
            self?.subviews.compactMap { $0 as? ToolRailDrawingView }.first?.needsDisplay = true
        }
        buttons.append(button)
        stack.addArrangedSubview(button)
    }

    private func addSeparator(to stack: NSStackView) {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: Theme.Metric.railSeparatorWidth).isActive = true
        stack.addArrangedSubview(separator)
        stack.setCustomSpacing(Theme.Spacing.controlRow, after: separator)
    }

    @objc private func pressed(_ sender: ToolRailButton) {
        if let tool = sender.tool { onTool?(tool) } else { onPlaceImage?() }
    }
}

private final class InspectorSection: NSStackView {
    private let content = NSStackView()

    init(title: String) {
        super.init(frame: .zero)
        orientation = .vertical
        alignment = .leading
        spacing = Theme.Spacing.controlRow
        edgeInsets = NSEdgeInsets(
            top: Theme.Spacing.controlRow, left: Theme.Spacing.section,
            bottom: Theme.Spacing.section, right: Theme.Spacing.section)
        widthAnchor.constraint(greaterThanOrEqualToConstant: Theme.Metric.inspectorWidth).isActive = true
        let header = NSButton(title: title.uppercased(), target: self, action: #selector(toggle(_:)))
        header.isBordered = false
        header.font = Theme.Font.section
        header.contentTintColor = Theme.Color.textSecondary
        header.setAccessibilityLabel("\(title) section")
        addArrangedSubview(header)
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = Theme.Spacing.controlRow
        addArrangedSubview(content)
    }

    required init?(coder: NSCoder) { nil }
    func addRow(_ view: NSView) { content.addArrangedSubview(view) }
    @objc private func toggle(_ sender: NSButton) { content.isHidden.toggle() }
}

private final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

private final class GradientPopoverContent: NSViewController {
    let kind = NSPopUpButton()
    let start = NSTextField(string: Theme.DefaultValue.gradientStart)
    let end = NSTextField(string: Theme.DefaultValue.gradientEnd)
    let stops = NSTextField(string: Theme.DefaultValue.gradientStops)
    var onApply: ((Int, String, String, String) -> Bool)?
    var onClose: (() -> Void)?

    override func loadView() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Theme.Spacing.controlRow
        stack.edgeInsets = NSEdgeInsets(
            top: Theme.Spacing.section, left: Theme.Spacing.section,
            bottom: Theme.Spacing.section, right: Theme.Spacing.section)
        kind.addItems(withTitles: ["Linear", "Radial"])
        stack.addArrangedSubview(kind)
        for (label, field) in [("Start x,y", start), ("End x,y", end), ("Stops offset:#RRGGBB", stops)] {
            let caption = NSTextField(labelWithString: label)
            caption.font = Theme.Font.fieldLabel
            caption.textColor = Theme.Color.textSecondary
            field.font = Theme.Font.numeric
            field.setAccessibilityLabel(label)
            stack.addArrangedSubview(caption)
            stack.addArrangedSubview(field)
        }
        let apply = NSButton(title: "Apply", target: self, action: #selector(applyGradient))
        apply.keyEquivalent = "\r"
        stack.addArrangedSubview(apply)
        stack.frame = NSRect(
            origin: .zero,
            size: NSSize(width: Theme.Metric.gradientPopoverWidth, height: Theme.Metric.gradientPopoverHeight))
        view = stack
    }

    @objc private func applyGradient() {
        if onApply?(kind.indexOfSelectedItem, start.stringValue, end.stringValue, stops.stringValue) == true {
            onClose?()
        }
    }
}

final class InspectorView: NSVisualEffectView, NSTextFieldDelegate {
    private weak var canvas: CanvasView?
    private let stack = FlippedStackView()
    private var geometryFields: [String: NSTextField] = [:]
    private var artboardFields: [String: NSTextField] = [:]
    private var steppers: [String: NSStepper] = [:]
    private let selectionSections = NSStackView()
    private let artboardSection = InspectorSection(title: "Artboard")
    private let textSection = InspectorSection(title: "Text")
    private let textContent = NSTextField()
    private let textFontName = NSTextField()
    private let textFontSize = NSTextField()
    private let fillWell = NSColorWell()
    private let strokeWell = NSColorWell()
    private let strokeWidth = NSTextField()
    private let dash = NSTextField()
    private let opacity = NSSlider(value: 1, minValue: 0, maxValue: 1, target: nil, action: nil)
    private var arrangeButtons: [String: NSButton] = [:]
    private var gradientPopover: NSPopover?

    init(canvas: CanvasView) {
        self.canvas = canvas
        super.init(frame: .zero)
        material = Theme.Color.panelMaterial
        blendingMode = .behindWindow
        state = .active
        setAccessibilityLabel("Inspector")
        setAccessibilityRole(.group)
        widthAnchor.constraint(equalToConstant: Theme.Metric.inspectorWidth).isActive = true

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor), scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Theme.Metric.stackFlush
        scroll.documentView = stack
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true

        selectionSections.orientation = .vertical
        selectionSections.alignment = .leading
        selectionSections.spacing = Theme.Metric.stackFlush
        buildGeometry()
        buildFillAndStroke()
        buildText()
        buildArrange()
        stack.addArrangedSubview(selectionSections)
        buildArtboard()
        stack.addArrangedSubview(artboardSection)
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    private func buildGeometry() {
        let section = InspectorSection(title: "Geometry")
        for row in [[("X", "x"), ("Y", "y")], [("W", "w"), ("H", "h")], [("∠", "angle")]] {
            let rowView = NSStackView()
            rowView.orientation = .horizontal
            rowView.spacing = Theme.Spacing.iconLabel
            for (label, key) in row {
                let caption = NSTextField(labelWithString: label)
                caption.font = Theme.Font.fieldLabel
                caption.textColor = Theme.Color.textSecondary
                caption.alignment = .right
                caption.widthAnchor.constraint(equalToConstant: Theme.Metric.inspectorLabelWidth).isActive = true
                let field = numericField(key: key, label: "Geometry \(label)")
                geometryFields[key] = field
                rowView.addArrangedSubview(caption)
                rowView.addArrangedSubview(field)
                rowView.addArrangedSubview(stepper(key: key, label: "Geometry \(label) stepper"))
            }
            section.addRow(rowView)
        }
        selectionSections.addArrangedSubview(section)
    }

    private func buildFillAndStroke() {
        let section = InspectorSection(title: "Fill & Stroke")
        fillWell.colorWellStyle = .minimal
        fillWell.target = self
        fillWell.action = #selector(fillChanged)
        configureWell(fillWell, label: "Fill color")
        strokeWell.colorWellStyle = .minimal
        strokeWell.target = self
        strokeWell.action = #selector(strokeChanged)
        configureWell(strokeWell, label: "Stroke color")
        section.addRow(labeled("Fill", fillWell))
        section.addRow(labeled("Stroke", strokeWell))
        strokeWidth.font = Theme.Font.numeric
        strokeWidth.target = self
        strokeWidth.action = #selector(strokeWidthChanged)
        strokeWidth.setAccessibilityLabel("Stroke width")
        strokeWidth.widthAnchor.constraint(equalToConstant: Theme.Metric.inspectorFieldWidth).isActive = true
        section.addRow(labeled("Width", strokeWidth))
        dash.font = Theme.Font.numeric
        dash.isEditable = false
        dash.isBezeled = true
        dash.setAccessibilityLabel("Dash pattern")
        dash.toolTip = "Dash pattern from the selected path style"
        dash.widthAnchor.constraint(equalToConstant: Theme.Metric.inspectorFieldWidth).isActive = true
        section.addRow(labeled("Dash", dash))
        opacity.target = self
        opacity.action = #selector(opacityChanged)
        opacity.setAccessibilityLabel("Opacity")
        opacity.widthAnchor.constraint(equalToConstant: Theme.Metric.inspectorFieldWidth).isActive = true
        section.addRow(labeled("Opacity", opacity))
        let gradient = NSButton(title: "Edit Gradient…", target: self, action: #selector(editGradient(_:)))
        gradient.font = Theme.Font.fieldLabel
        gradient.setAccessibilityLabel("Edit gradient")
        section.addRow(gradient)
        selectionSections.addArrangedSubview(section)
    }

    private func buildArrange() {
        let section = InspectorSection(title: "Arrange")
        let align = NSStackView()
        align.orientation = .horizontal
        align.spacing = Theme.Spacing.hairline
        let symbols = [
            ("Align Left", "align.horizontal.left"), ("Align Center", "align.horizontal.center"),
            ("Align Right", "align.horizontal.right"), ("Align Top", "align.vertical.top"),
            ("Align Middle", "align.vertical.center"), ("Align Bottom", "align.vertical.bottom"),
        ]
        let actions = [
            #selector(alignLeft), #selector(alignCenter), #selector(alignRight),
            #selector(alignTop), #selector(alignMiddle), #selector(alignBottom),
        ]
        for (index, pair) in symbols.enumerated() {
            let button = symbolButton(pair.0, symbol: pair.1, action: actions[index])
            arrangeButtons[pair.0] = button
            align.addArrangedSubview(button)
        }
        section.addRow(align)
        for row in [["Group", "Ungroup"], ["Compound", "Release"]] {
            let buttons = NSStackView()
            buttons.orientation = .horizontal
            buttons.spacing = Theme.Spacing.iconLabel
            for name in row {
                let button = NSButton(title: name, target: self, action: arrangeAction(name))
                button.font = Theme.Font.fieldLabel
                button.widthAnchor.constraint(equalToConstant: Theme.Metric.inspectorFieldWidth).isActive = true
                button.setAccessibilityLabel(name)
                arrangeButtons[name] = button
                buttons.addArrangedSubview(button)
            }
            section.addRow(buttons)
        }
        selectionSections.addArrangedSubview(section)
    }

    private func buildText() {
        for (label, field, accessibilityLabel) in [
            ("Text", textContent, "Text content"),
            ("Font", textFontName, "Text font name"),
            ("Size", textFontSize, "Text font size"),
        ] {
            field.font = field === textFontSize ? Theme.Font.numeric : Theme.Font.control
            field.delegate = self
            field.target = self
            field.action = #selector(textFieldCommitted(_:))
            field.setAccessibilityLabel(accessibilityLabel)
            field.widthAnchor.constraint(equalToConstant: Theme.Metric.inspectorFieldWidth).isActive = true
            textSection.addRow(labeled(label, field))
        }
        textSection.isHidden = true
        selectionSections.addArrangedSubview(textSection)
    }

    private func buildArtboard() {
        for (label, key) in [("W", "width"), ("H", "height")] {
            let field = numericField(key: key, label: "Artboard \(label)")
            artboardFields[key] = field
            let controls = NSStackView(views: [field, stepper(key: key, label: "Artboard \(label) stepper")])
            controls.orientation = .horizontal
            controls.spacing = Theme.Spacing.intraControl
            artboardSection.addRow(labeled(label, controls))
        }
        let empty = NSTextField(labelWithString: "No selection")
        empty.font = Theme.Font.fieldLabel
        empty.textColor = Theme.Color.textTertiary
        artboardSection.addRow(empty)
    }

    private func numericField(key: String, label: String) -> NSTextField {
        let field = NSTextField()
        field.identifier = NSUserInterfaceItemIdentifier(key)
        field.font = Theme.Font.numeric
        field.delegate = self
        field.target = self
        field.action = #selector(numericCommitted(_:))
        field.setAccessibilityLabel(label)
        field.widthAnchor.constraint(equalToConstant: Theme.Metric.inspectorNumericTextWidth).isActive = true
        field.heightAnchor.constraint(equalToConstant: Theme.Metric.inspectorFieldHeight).isActive = true
        return field
    }

    private func stepper(key: String, label: String) -> NSStepper {
        let stepper = NSStepper()
        stepper.identifier = NSUserInterfaceItemIdentifier(key)
        stepper.increment = 1
        stepper.target = self
        stepper.action = #selector(stepperChanged(_:))
        stepper.setAccessibilityLabel(label)
        stepper.widthAnchor.constraint(equalToConstant: Theme.Metric.inspectorStepperWidth).isActive = true
        steppers[key] = stepper
        return stepper
    }

    private func configureWell(_ well: NSColorWell, label: String) {
        well.setAccessibilityLabel(label)
        well.widthAnchor.constraint(equalToConstant: Theme.Metric.colorWellWidth).isActive = true
        well.heightAnchor.constraint(equalToConstant: Theme.Metric.colorWellHeight).isActive = true
    }

    private func labeled(_ title: String, _ control: NSView) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = Theme.Spacing.controlRow
        let label = NSTextField(labelWithString: title)
        label.font = Theme.Font.fieldLabel
        label.textColor = Theme.Color.textSecondary
        label.widthAnchor.constraint(equalToConstant: Theme.Metric.inspectorLabelWidth * 2).isActive = true
        row.addArrangedSubview(label)
        row.addArrangedSubview(control)
        return row
    }

    private func symbolButton(_ label: String, symbol: String, action: Selector?) -> NSButton {
        let button = NSButton(
            image: NSImage(systemSymbolName: symbol, accessibilityDescription: label)!, target: self, action: action)
        button.isBordered = false
        button.image = button.image?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: Theme.Metric.toolbarIcon, weight: .medium))
        button.setAccessibilityLabel(label)
        return button
    }

    private func arrangeAction(_ name: String) -> Selector {
        switch name {
        case "Group": #selector(group)
        case "Ungroup": #selector(ungroup)
        case "Compound": #selector(compound)
        default: #selector(releaseCompound)
        }
    }

    func refresh() {
        guard let canvas else { return }
        let bounds = canvas.selectedBounds
        selectionSections.isHidden = bounds == nil
        artboardSection.isHidden = bounds != nil
        if let bounds {
            set(geometryFields["x"], bounds.minX)
            set(geometryFields["y"], bounds.minY)
            set(geometryFields["w"], bounds.width)
            set(geometryFields["h"], bounds.height)
            if let transform = canvas.selectedTransform {
                set(geometryFields["angle"], atan2(transform.b, transform.a) * 180 / .pi)
            }
        } else {
            set(artboardFields["width"], canvas.history.document.width)
            set(artboardFields["height"], canvas.history.document.height)
        }
        if let style = canvas.selectedPathStyle {
            fillWell.color = Theme.Color.appKit(style.fill)
            strokeWell.color = Theme.Color.appKit(style.stroke)
            strokeWidth.stringValue = number(style.strokeWidth)
            dash.stringValue = style.dash.isEmpty ? "—" : style.dash.map(number).joined(separator: ", ")
            opacity.doubleValue = style.opacity ?? 1
        }
        if let text = canvas.selectedTextObject {
            textSection.isHidden = false
            textContent.stringValue = text.text
            textFontName.stringValue = text.fontName
            textFontSize.stringValue = number(text.fontSize)
        } else {
            textSection.isHidden = true
        }
        let multiple = canvas.hasMultipleSelection
        for title in ["Align Left", "Align Center", "Align Right", "Align Top", "Align Middle", "Align Bottom"] {
            arrangeButtons[title]?.isEnabled = multiple
        }
        arrangeButtons["Group"]?.isEnabled = canvas.canGroupSelection
        arrangeButtons["Compound"]?.isEnabled = canvas.canMakeCompoundSelection
        arrangeButtons["Ungroup"]?.isEnabled = canvas.canUngroupSelection
        arrangeButtons["Release"]?.isEnabled = canvas.canReleaseCompoundSelection
    }

    @objc private func numericCommitted(_ sender: NSTextField) {
        guard let canvas, let key = sender.identifier?.rawValue, let value = Double(sender.stringValue), value.isFinite
        else {
            refresh()
            return
        }
        if key == "width" {
            canvas.commitArtboard(width: value)
            return
        }
        if key == "height" {
            canvas.commitArtboard(height: value)
            return
        }
        guard let bounds = canvas.selectedBounds else { return }
        let transform: Geometry.AffineTransform
        switch key {
        case "x": transform = Geometry.AffineTransform(tx: value - bounds.minX)
        case "y": transform = Geometry.AffineTransform(ty: value - bounds.minY)
        case "w" where bounds.width > 0:
            let factor = value / bounds.width
            transform = Geometry.AffineTransform(a: factor, d: 1, tx: bounds.minX * (1 - factor))
        case "h" where bounds.height > 0:
            let factor = value / bounds.height
            transform = Geometry.AffineTransform(a: 1, d: factor, ty: bounds.minY * (1 - factor))
        case "angle":
            let current = canvas.selectedTransform.map { atan2($0.b, $0.a) } ?? 0
            transform = TransformInteractions.rotation(about: bounds.center, radians: value * .pi / 180 - current)
        default:
            refresh()
            return
        }
        canvas.commitDocumentTransform(transform)
        refresh()
    }

    @objc private func textFieldCommitted(_ sender: NSTextField) {
        guard let canvas else { return }
        if sender === textContent {
            canvas.commitSelectedTextContent(sender.stringValue)
        } else if sender === textFontName {
            canvas.commitSelectedTextFontName(sender.stringValue)
        } else if sender === textFontSize, let value = Double(sender.stringValue), value > 0 {
            canvas.commitSelectedTextFontSize(value)
        } else {
            refresh()
            return
        }
        refresh()
    }

    @objc private func stepperChanged(_ sender: NSStepper) {
        guard let key = sender.identifier?.rawValue,
            let field = geometryFields[key] ?? artboardFields[key]
        else { return }
        field.doubleValue = sender.doubleValue
        numericCommitted(field)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === textContent || field === textFontName || field === textFontSize {
            textFieldCommitted(field)
        } else {
            numericCommitted(field)
        }
    }

    @objc private func fillChanged() { canvas?.commitPathStyle { $0.fill = Theme.Color.srgb(fillWell.color) } }
    @objc private func strokeChanged() { canvas?.commitPathStyle { $0.stroke = Theme.Color.srgb(strokeWell.color) } }
    @objc private func strokeWidthChanged() {
        guard let value = Double(strokeWidth.stringValue) else {
            refresh()
            return
        }
        canvas?.commitPathStyle { $0.strokeWidth = value }
    }
    @objc private func opacityChanged() { canvas?.commitPathStyle { $0.opacity = opacity.doubleValue } }
    @objc private func editGradient(_ sender: NSButton) {
        guard let canvas else { return }
        let content = GradientPopoverContent()
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = content
        content.onApply = { [weak canvas] in
            canvas?.applyGradient(kindIndex: $0, start: $1, end: $2, stops: $3) ?? false
        }
        content.onClose = { [weak popover] in popover?.close() }
        gradientPopover = popover
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxX)
    }
    @objc private func alignLeft() { canvas?.alignSelectedLeft() }
    @objc private func alignCenter() { canvas?.alignSelected(.horizontalCenter) }
    @objc private func alignRight() { canvas?.alignSelected(.right) }
    @objc private func alignTop() { canvas?.alignSelected(.top) }
    @objc private func alignMiddle() { canvas?.alignSelected(.verticalCenter) }
    @objc private func alignBottom() { canvas?.alignSelected(.bottom) }
    @objc private func group() { canvas?.groupSelected() }
    @objc private func ungroup() { canvas?.ungroupSelected() }
    @objc private func compound() { canvas?.makeCompoundSelected() }
    @objc private func releaseCompound() { canvas?.releaseCompoundSelected() }

    private func set(_ field: NSTextField?, _ value: Double) {
        field?.stringValue = number(value)
        if let key = field?.identifier?.rawValue { steppers[key]?.doubleValue = value }
    }
    private func number(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".00", with: "")
    }
}

private final class LayerEntry: NSObject {
    let layerID: ObjectID
    let node: SceneNode?
    let children: [LayerEntry]
    init(layerID: ObjectID, node: SceneNode? = nil, children: [LayerEntry] = []) {
        self.layerID = layerID
        self.node = node
        self.children = children
    }
    var id: ObjectID { node?.id ?? layerID }
}

private final class LayerCellView: NSTableCellView {
    private weak var eye: NSButton?
    private weak var lock: NSButton?
    private var eyeEngaged = false
    private var lockEngaged = false

    func installHoverControls(eye: NSButton, lock: NSButton, eyeEngaged: Bool, lockEngaged: Bool) {
        self.eye = eye
        self.lock = lock
        self.eyeEngaged = eyeEngaged
        self.lockEngaged = lockEngaged
        eye.isHidden = !eyeEngaged
        lock.isHidden = !lockEngaged
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseEnteredAndExited], owner: self))
    }
    override func mouseEntered(with event: NSEvent) {
        eye?.isHidden = false
        lock?.isHidden = false
    }
    override func mouseExited(with event: NSEvent) {
        eye?.isHidden = !eyeEngaged
        lock?.isHidden = !lockEngaged
    }
}

final class LayersView: NSVisualEffectView, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private weak var canvas: CanvasView?
    private let outline = NSOutlineView()
    private var entries: [LayerEntry] = []
    private let layerPasteboard = NSPasteboard.PasteboardType("com.opendraw.layer")

    init(canvas: CanvasView) {
        self.canvas = canvas
        super.init(frame: .zero)
        material = Theme.Color.panelMaterial
        blendingMode = .behindWindow
        state = .active
        setAccessibilityLabel("Layers")
        setAccessibilityRole(.outline)
        widthAnchor.constraint(equalToConstant: Theme.Metric.layersWidth).isActive = true
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.documentView = outline
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor), scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("layer"))
        outline.addTableColumn(column)
        outline.outlineTableColumn = column
        outline.headerView = nil
        outline.rowSizeStyle = .custom
        outline.style = .sourceList
        outline.delegate = self
        outline.dataSource = self
        outline.target = self
        outline.action = #selector(selectionChanged)
        outline.registerForDraggedTypes([layerPasteboard])
        refresh()
    }

    required init?(coder: NSCoder) { nil }

    func refresh() {
        guard let canvas else { return }
        entries = canvas.history.document.layers.map { layer in
            LayerEntry(layerID: layer.id, children: layer.nodes.map { entry(node: $0, layerID: layer.id) })
        }
        outline.reloadData()
        outline.expandItem(nil, expandChildren: true)
        if let selected = canvas.selectedNodeIDs.first, let row = row(for: selected), row >= 0 {
            outline.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
    }

    private func entry(node: SceneNode, layerID: ObjectID) -> LayerEntry {
        if case .group(let group) = node {
            return LayerEntry(
                layerID: layerID, node: node, children: group.children.map { entry(node: $0, layerID: layerID) })
        }
        return LayerEntry(layerID: layerID, node: node)
    }

    private func row(for id: ObjectID) -> Int? {
        for index in 0..<outline.numberOfRows where (outline.item(atRow: index) as? LayerEntry)?.id == id {
            return index
        }
        return nil
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? LayerEntry)?.children.count ?? entries.count
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? LayerEntry)?.children[index] ?? entries[index]
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let entry = item as? LayerEntry else { return false }
        return !entry.children.isEmpty
    }
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        Theme.Metric.layerRowHeight
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let entry = item as? LayerEntry, let canvas else { return nil }
        let cell = LayerCellView()
        let label = NSTextField(labelWithString: name(for: entry))
        label.font = Theme.Font.layer
        let layer = canvas.history.document.layers.first { $0.id == entry.layerID }
        label.textColor = layer?.isVisible == false ? Theme.Color.textTertiary : Theme.Color.textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: Theme.Spacing.iconLabel),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        cell.setAccessibilityLabel(name(for: entry))
        cell.setAccessibilityRole(entry.node == nil ? .row : .staticText)
        if entry.node == nil, let layer {
            let eye = compactSymbol(
                layer.isVisible ? "eye" : "eye.slash", label: layer.isVisible ? "Hide layer" : "Show layer")
            eye.state = layer.isVisible ? NSControl.StateValue.on : NSControl.StateValue.off
            eye.target = self
            eye.action = #selector(toggleVisibility(_:))
            eye.identifier = NSUserInterfaceItemIdentifier(layer.id.rawValue.uuidString)
            let lock = compactSymbol(
                layer.isLocked ? "lock.fill" : "lock.open", label: layer.isLocked ? "Unlock layer" : "Lock layer")
            lock.state = layer.isLocked ? NSControl.StateValue.on : NSControl.StateValue.off
            lock.target = self
            lock.action = #selector(toggleLock(_:))
            lock.identifier = eye.identifier
            let controls = NSStackView(views: [eye, lock])
            controls.orientation = .horizontal
            controls.spacing = Theme.Spacing.intraControl
            controls.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(controls)
            cell.installHoverControls(
                eye: eye, lock: lock, eyeEngaged: !layer.isVisible,
                lockEngaged: layer.isLocked)
            NSLayoutConstraint.activate([
                controls.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -Theme.Spacing.iconLabel),
                controls.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                label.trailingAnchor.constraint(
                    lessThanOrEqualTo: controls.leadingAnchor, constant: -Theme.Spacing.intraControl),
            ])
        } else {
            label.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -Theme.Spacing.iconLabel)
                .isActive = true
        }
        return cell
    }

    private func compactSymbol(_ symbol: String, label: String) -> NSButton {
        let button = NSButton(
            image: NSImage(systemSymbolName: symbol, accessibilityDescription: label)!, target: nil, action: nil)
        button.isBordered = false
        button.setAccessibilityLabel(label)
        return button
    }

    private func name(for entry: LayerEntry) -> String {
        guard let node = entry.node else {
            return canvas?.history.document.layers.first(where: { $0.id == entry.layerID })?.name ?? "Layer"
        }
        switch node {
        case .path: return "Path"
        case .text(let value): return value.text.isEmpty ? "Text" : value.text
        case .image: return "Image"
        case .group(let value): return value.name
        }
    }

    @objc private func selectionChanged() {
        guard outline.selectedRow >= 0, let entry = outline.item(atRow: outline.selectedRow) as? LayerEntry else {
            return
        }
        if let node = entry.node { canvas?.selectNode(node.id) } else { canvas?.activateLayer(entry.layerID) }
    }

    @objc private func toggleVisibility(_ sender: NSButton) {
        guard let id = uuid(sender) else { return }
        guard let layer = canvas?.history.document.layers.first(where: { $0.id.rawValue == id }) else { return }
        canvas?.commitLayerState(layer.id, visible: !layer.isVisible)
    }
    @objc private func toggleLock(_ sender: NSButton) {
        guard let id = uuid(sender) else { return }
        guard let layer = canvas?.history.document.layers.first(where: { $0.id.rawValue == id }) else { return }
        canvas?.commitLayerState(layer.id, locked: !layer.isLocked)
    }
    private func uuid(_ sender: NSButton) -> UUID? { sender.identifier.flatMap { UUID(uuidString: $0.rawValue) } }

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let entry = item as? LayerEntry else { return nil }
        let item = NSPasteboardItem()
        let kind = entry.node == nil ? "layer" : "node"
        item.setString("\(kind):\(entry.id.rawValue.uuidString)", forType: layerPasteboard)
        return item
    }
    func outlineView(
        _ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?,
        proposedChildIndex index: Int
    ) -> NSDragOperation {
        guard index >= 0, let value = info.draggingPasteboard.string(forType: layerPasteboard) else { return [] }
        if value.hasPrefix("layer:") { return item == nil ? .move : [] }
        guard let target = item as? LayerEntry else { return [] }
        if target.node == nil { return .move }
        if case .group? = target.node { return .move }
        return []
    }
    func outlineView(
        _ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int
    ) -> Bool {
        guard let value = info.draggingPasteboard.string(forType: layerPasteboard) else { return false }
        let pieces = value.split(separator: ":", maxSplits: 1).map(String.init)
        guard pieces.count == 2, let uuid = UUID(uuidString: pieces[1]) else { return false }
        let id = ObjectID(rawValue: uuid)
        if pieces[0] == "layer" {
            canvas?.reorderLayer(id, to: index)
        } else {
            guard let target = item as? LayerEntry else { return false }
            let parent: SceneParent
            if case .group(let group)? = target.node {
                parent = .group(group.id)
            } else {
                parent = .layer(target.layerID)
            }
            canvas?.reorderNode(id, to: parent, at: index)
        }
        refresh()
        return true
    }
}

final class EditorShellView: NSView {
    var onDocumentChange: (() -> Void)?
    let rail: ToolRailView
    let layers: LayersView
    let inspector: InspectorView
    let canvas: CanvasView

    init(canvas: CanvasView) {
        self.canvas = canvas
        rail = ToolRailView()
        layers = LayersView(canvas: canvas)
        inspector = InspectorView(canvas: canvas)
        super.init(frame: .zero)
        for view in [rail, canvas, layers, inspector] { view.translatesAutoresizingMaskIntoConstraints = false }
        addSubview(canvas)
        addSubview(layers)
        addSubview(inspector)
        addSubview(rail, positioned: .above, relativeTo: canvas)
        NSLayoutConstraint.activate([
            rail.leadingAnchor.constraint(equalTo: leadingAnchor), rail.topAnchor.constraint(equalTo: topAnchor),
            rail.bottomAnchor.constraint(equalTo: bottomAnchor),
            canvas.leadingAnchor.constraint(equalTo: rail.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: topAnchor),
            canvas.bottomAnchor.constraint(equalTo: bottomAnchor),
            canvas.trailingAnchor.constraint(equalTo: layers.leadingAnchor),
            layers.topAnchor.constraint(equalTo: topAnchor), layers.bottomAnchor.constraint(equalTo: bottomAnchor),
            layers.trailingAnchor.constraint(equalTo: inspector.leadingAnchor),
            inspector.topAnchor.constraint(equalTo: topAnchor),
            inspector.bottomAnchor.constraint(equalTo: bottomAnchor),
            inspector.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        canvas.setContentHuggingPriority(.defaultLow, for: .horizontal)
        canvas.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        rail.onTool = { [weak canvas, weak rail] tool in
            canvas?.activeTool = tool
            rail?.updateActiveTool(tool)
        }
        canvas.onSelectionChange = { [weak self] in self?.refreshPanels() }
        canvas.onDocumentChange = { [weak self] in
            self?.refreshPanels()
            self?.onDocumentChange?()
        }
        canvas.onToolChange = { [weak rail] in rail?.updateActiveTool($0) }
        rail.updateActiveTool(canvas.activeTool)
    }

    required init?(coder: NSCoder) { nil }
    func refreshPanels() {
        inspector.refresh()
        layers.refresh()
    }
    func toggleInspector() { inspector.isHidden.toggle() }
    func toggleLayers() { layers.isHidden.toggle() }
}

final class ZoomToolbarView: NSStackView, NSTextFieldDelegate {
    var onZoomOut: (() -> Void)?
    var onZoomIn: (() -> Void)?
    var onCommit: ((Double) -> Void)?
    private let readout = NSTextField(string: "100%")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        orientation = .horizontal
        alignment = .centerY
        spacing = Theme.Spacing.hairline
        let segments = NSSegmentedControl(
            labels: ["−", "+"], trackingMode: .momentary, target: self, action: #selector(segment(_:)))
        segments.segmentStyle = .smallSquare
        segments.setAccessibilityLabel("Zoom out and in")
        readout.font = Theme.Font.zoom
        readout.alignment = .center
        readout.delegate = self
        readout.target = self
        readout.action = #selector(commit)
        readout.setAccessibilityLabel("Zoom percentage")
        readout.widthAnchor.constraint(equalToConstant: Theme.Metric.toolbarZoomReadoutWidth).isActive = true
        addArrangedSubview(segments)
        addArrangedSubview(readout)
    }

    required init?(coder: NSCoder) { nil }
    func update(_ zoom: Double) { readout.stringValue = "\(Int((zoom * 100).rounded()))%" }
    @objc private func segment(_ sender: NSSegmentedControl) {
        if sender.selectedSegment == 0 { onZoomOut?() } else { onZoomIn?() }
    }
    @objc private func commit() {
        let value = readout.stringValue.replacingOccurrences(of: "%", with: "")
        if let percentage = Double(value) { onCommit?(percentage) }
    }
    func controlTextDidEndEditing(_ obj: Notification) { commit() }
}
