//
//  GridView.swift
//  MarkdownView
//
//  Created by ktiays on 2025/1/27.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

/// The frame a table is drawn in: its rounded border, the title bar, the
/// header and striped row backgrounds, and the lines between rows and
/// columns.
///
/// It stays put while the columns scroll sideways beneath the cells, so the
/// border and its rounded corners are always whole. Rows run the full width
/// and do not move; the column lines follow `scrollOffset`. Everything inside
/// the border is clipped to its rounded shape.
final class GridView: PlatformView {
    /// Column widths, in the order drawn.
    private var widths: [CGFloat] = []
    /// Row heights, header first.
    private var heights: [CGFloat] = []
    /// How far the columns are scrolled from their start.
    private(set) var scrollOffset: CGFloat = 0
    /// Where the first column starts when not scrolled, from the left.
    var columnsOrigin: CGFloat = 0 {
        didSet {
            if oldValue != columnsOrigin {
                markNeedsLayout()
            }
        }
    }

    /// Height of the title bar above the rows; zero for none.
    var titleHeight: CGFloat = 0 {
        didSet {
            if oldValue != titleHeight {
                markNeedsLayout()
            }
        }
    }

    private lazy var shapeLayer: CAShapeLayer = .init()
    private lazy var headerBackgroundLayer: CAShapeLayer = .init()
    private lazy var backgroundLayer: CAShapeLayer = .init()
    private lazy var stripeLayer: CAShapeLayer = .init()
    private lazy var columnLineLayer: CAShapeLayer = .init()
    var padding: CGFloat = 2
    private var theme: MarkdownTheme = .default
    private var hasHeaderRow: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if canImport(UIKit)
        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)
            updateThemeColors()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            layoutLayers()
        }

        private func resolvedCGColor(_ color: UIColor) -> CGColor {
            color.cgColor
        }
    #elseif canImport(AppKit)
        override var isFlipped: Bool {
            true
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            updateThemeColors()
        }

        override func layout() {
            super.layout()
            layoutLayers()
        }

        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }

        private func resolvedCGColor(_ color: NSColor) -> CGColor {
            var resolved = color
            effectiveAppearance.performAsCurrentDrawingAppearance {
                resolved = color.usingColorSpace(.sRGB) ?? color
            }
            return resolved.cgColor
        }
    #endif

    /// The layer the grid's shape layers hang off: always there on UIKit,
    /// there on AppKit once `wantsLayer` is set.
    private var hostLayer: CALayer? {
        layer
    }

    private func setupView() {
        #if canImport(UIKit)
            backgroundColor = .clear
            isUserInteractionEnabled = false
        #elseif canImport(AppKit)
            wantsLayer = true
        #endif

        backgroundLayer.strokeColor = PlatformColor.clear.cgColor
        backgroundLayer.lineWidth = 0
        stripeLayer.lineWidth = 0
        headerBackgroundLayer.lineWidth = 0
        shapeLayer.fillColor = PlatformColor.clear.cgColor
        columnLineLayer.fillColor = PlatformColor.clear.cgColor
        // Background, stripes, header, then the lines.
        for layer in [backgroundLayer, stripeLayer, headerBackgroundLayer, shapeLayer, columnLineLayer] {
            hostLayer?.addSublayer(layer)
        }
        updateThemeColors()
    }

    private func updateThemeColors() {
        backgroundLayer.fillColor = resolvedCGColor(theme.table.cellBackgroundColor)
        stripeLayer.fillColor = resolvedCGColor(theme.table.stripeCellBackgroundColor)
        headerBackgroundLayer.fillColor = resolvedCGColor(theme.table.headerBackgroundColor)
        for layer in [shapeLayer, columnLineLayer] {
            layer.strokeColor = resolvedCGColor(theme.table.borderColor)
            layer.lineWidth = theme.table.borderWidth
        }
    }

    // MARK: - Geometry

    private var totalWidth: CGFloat {
        max(0, bounds.width - padding * 2)
    }

    private var totalHeight: CGFloat {
        titleHeight + heights.reduce(0, +)
    }

    /// Where the first row starts.
    private var rowsTop: CGFloat {
        padding + titleHeight
    }

    /// The inside of the border, which everything but the border is clipped to.
    private var innerPath: GridPath {
        let lineWidth = theme.table.borderWidth
        return GridPath.roundedRect(
            CGRect(
                x: padding + lineWidth,
                y: padding + lineWidth,
                width: totalWidth - lineWidth * 2,
                height: totalHeight - lineWidth * 2,
            ),
            cornerRadius: max(0, theme.table.cornerRadius - lineWidth),
        )
    }

    /// The x of every line between two columns, scrolled by `scrollOffset`.
    var columnLinePositions: [CGFloat] {
        var x = columnsOrigin - scrollOffset
        return widths.dropLast().map { width in
            x += width
            return x
        }
    }

    // MARK: - Drawing

    private func layoutLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        for layer in [backgroundLayer, shapeLayer, headerBackgroundLayer, stripeLayer, columnLineLayer] {
            layer.frame = bounds
        }
        drawBackground()
        drawStripeRows()
        drawGrid()
        drawHeaderBackground()
        drawColumnLines()
    }

    private func clipped(_ layer: CAShapeLayer) {
        let mask = (layer.mask as? CAShapeLayer) ?? CAShapeLayer()
        mask.path = innerPath.cgPath
        layer.mask = mask
    }

    private func drawBackground() {
        backgroundLayer.path = innerPath.cgPath
    }

    private func drawStripeRows() {
        let path = GridPath()
        let startRow = hasHeaderRow ? 1 : 0
        var y = rowsTop + heights.prefix(startRow).reduce(0, +)
        for index in startRow ..< heights.count {
            if (index - startRow) % 2 == 1 {
                path.appendGridRect(CGRect(x: padding, y: y, width: totalWidth, height: heights[index]))
            }
            y += heights[index]
        }
        stripeLayer.path = path.cgPath
        clipped(stripeLayer)
    }

    /// The title bar and the header row, which share a colour.
    private func drawHeaderBackground() {
        let path = GridPath()
        if titleHeight > 0 {
            path.appendGridRect(CGRect(x: padding, y: padding, width: totalWidth, height: titleHeight))
        }
        if hasHeaderRow, let headerHeight = heights.first {
            path.appendGridRect(CGRect(x: padding, y: rowsTop, width: totalWidth, height: headerHeight))
        }
        headerBackgroundLayer.path = path.cgPath
        clipped(headerBackgroundLayer)
    }

    /// The border, and the lines under the title bar and between rows.
    private func drawGrid() {
        let lineWidth = theme.table.borderWidth
        let halfLineWidth = lineWidth / 2
        let outerRect = CGRect(
            x: padding + halfLineWidth,
            y: padding + halfLineWidth,
            width: totalWidth - lineWidth,
            height: totalHeight - lineWidth,
        )
        let path = GridPath.roundedRect(outerRect, cornerRadius: theme.table.cornerRadius)

        var y = rowsTop
        var boundaries: [CGFloat] = titleHeight > 0 && !heights.isEmpty ? [y] : []
        for height in heights.dropLast() {
            y += height
            boundaries.append(y)
        }
        for boundary in boundaries {
            path.move(to: .init(x: padding + halfLineWidth, y: boundary))
            path.addGridLine(to: .init(x: padding + totalWidth - halfLineWidth, y: boundary))
        }
        shapeLayer.path = path.cgPath
    }

    /// The lines between columns, from the first row to the bottom border.
    private func drawColumnLines() {
        let path = GridPath()
        let bottom = padding + totalHeight
        for x in columnLinePositions where x > padding && x < padding + totalWidth {
            path.move(to: .init(x: x, y: rowsTop))
            path.addGridLine(to: .init(x: x, y: bottom))
        }
        columnLineLayer.path = path.cgPath
        clipped(columnLineLayer)
    }

    // MARK: - Updates

    func update(widths: [CGFloat], heights: [CGFloat]) {
        self.widths = widths
        self.heights = heights
        markNeedsLayout()
    }

    /// Moves the column lines with the columns; nothing else is redrawn.
    func setScrollOffset(_ offset: CGFloat) {
        guard scrollOffset != offset else { return }
        scrollOffset = offset
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        drawColumnLines()
        CATransaction.commit()
    }

    func setTheme(_ theme: MarkdownTheme) {
        self.theme = theme
        updateThemeColors()
        markNeedsLayout()
    }

    func setHeaderRow(_ hasHeader: Bool) {
        hasHeaderRow = hasHeader
        markNeedsLayout()
    }
}

// The grid draws with each platform's own bezier path: UIKit rounds a
// rectangle with continuous corners and AppKit with circular arcs, and the
// table keeps the look native to each.
#if canImport(UIKit)
    private typealias GridPath = UIBezierPath

    private extension UIBezierPath {
        static func roundedRect(_ rect: CGRect, cornerRadius: CGFloat) -> UIBezierPath {
            UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
        }

        func appendGridRect(_ rect: CGRect) {
            append(UIBezierPath(rect: rect))
        }

        func addGridLine(to point: CGPoint) {
            addLine(to: point)
        }
    }

#elseif canImport(AppKit)
    private typealias GridPath = NSBezierPath

    private extension NSBezierPath {
        static func roundedRect(_ rect: CGRect, cornerRadius: CGFloat) -> NSBezierPath {
            NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        }

        func appendGridRect(_ rect: CGRect) {
            appendRect(rect)
        }

        func addGridLine(to point: CGPoint) {
            line(to: point)
        }
    }

    extension NSBezierPath {
        var cgPath: CGPath {
            let path = CGMutablePath()
            var points = [CGPoint](repeating: .zero, count: 3)
            for i in 0 ..< elementCount {
                let type = element(at: i, associatedPoints: &points)
                switch type {
                case .moveTo: path.move(to: points[0])
                case .lineTo: path.addLine(to: points[0])
                case .curveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
                case .closePath: path.closeSubpath()
                case .cubicCurveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
                case .quadraticCurveTo: path.addQuadCurve(to: points[1], control: points[0])
                @unknown default: break
                }
            }
            return path
        }
    }
#endif
