//
//  GridView.swift
//  MarkdownView
//
//  Created by ktiays on 2025/1/27.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

final class GridView: PlatformView {
    private var widths: [CGFloat] = []
    private var heights: [CGFloat] = []
    private var totalWidth: CGFloat = 0
    private var totalHeight: CGFloat = 0

    private lazy var shapeLayer: CAShapeLayer = .init()
    private lazy var headerBackgroundLayer: CAShapeLayer = .init()
    private lazy var backgroundLayer: CAShapeLayer = .init()
    private lazy var stripeLayer: CAShapeLayer = .init()
    var padding: CGFloat = 2
    private var theme: MarkdownTheme = .default
    private var hasHeaderRow: Bool = false
    /// Whether the last row is one cell across every column, drawn
    /// without the column separators.
    private(set) var mergesLastRow = false

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

        backgroundLayer.fillColor = resolvedCGColor(theme.table.cellBackgroundColor)
        backgroundLayer.strokeColor = PlatformColor.clear.cgColor
        backgroundLayer.lineWidth = 0
        hostLayer?.addSublayer(backgroundLayer)

        stripeLayer.fillColor = resolvedCGColor(theme.table.stripeCellBackgroundColor)
        hostLayer?.addSublayer(stripeLayer)

        headerBackgroundLayer.fillColor = resolvedCGColor(theme.table.headerBackgroundColor)
        hostLayer?.addSublayer(headerBackgroundLayer)

        shapeLayer.lineWidth = theme.table.borderWidth
        shapeLayer.strokeColor = resolvedCGColor(theme.table.borderColor)
        shapeLayer.fillColor = PlatformColor.clear.cgColor
        hostLayer?.addSublayer(shapeLayer)
    }

    private func updateThemeColors() {
        backgroundLayer.fillColor = resolvedCGColor(theme.table.cellBackgroundColor)
        backgroundLayer.strokeColor = PlatformColor.clear.cgColor
        stripeLayer.fillColor = resolvedCGColor(theme.table.stripeCellBackgroundColor)
        shapeLayer.strokeColor = resolvedCGColor(theme.table.borderColor)
        shapeLayer.lineWidth = theme.table.borderWidth
        headerBackgroundLayer.fillColor = resolvedCGColor(theme.table.headerBackgroundColor)
    }

    private func layoutLayers() {
        backgroundLayer.frame = bounds
        shapeLayer.frame = bounds
        headerBackgroundLayer.frame = bounds
        stripeLayer.frame = bounds
        drawBackground()
        drawStripeRows()
        drawGrid()
        drawHeaderBackground()
    }

    private func drawBackground() {
        let cornerRadius = theme.table.cornerRadius
        let lineWidth = theme.table.borderWidth

        let backgroundRect = CGRect(
            x: padding + lineWidth,
            y: padding + lineWidth,
            width: totalWidth - lineWidth * 2,
            height: totalHeight - lineWidth * 2
        )

        let backgroundPath = GridPath.roundedRect(
            backgroundRect, cornerRadius: max(0, cornerRadius - lineWidth)
        )
        backgroundLayer.path = backgroundPath.cgPath
    }

    private func drawStripeRows() {
        let path = GridPath()
        let lineWidth = theme.table.borderWidth

        var y: CGFloat = padding
        if hasHeaderRow {
            guard !heights.isEmpty else {
                stripeLayer.path = nil
                return
            }
            y += heights[0]
        }

        let startRow = hasHeaderRow ? 1 : 0
        for i in startRow ..< heights.count {
            let dataRowIndex = i - startRow
            if dataRowIndex % 2 == 1 {
                let stripeRect = CGRect(
                    x: padding + lineWidth,
                    y: y,
                    width: totalWidth - (lineWidth * 2),
                    height: heights[i]
                )
                path.appendGridRect(stripeRect)
            }
            y += heights[i]
        }

        let cornerRadius = theme.table.cornerRadius
        let backgroundRect = CGRect(
            x: padding + lineWidth,
            y: padding + lineWidth,
            width: totalWidth - lineWidth * 2,
            height: totalHeight - lineWidth * 2
        )
        let clipPath = GridPath.roundedRect(
            backgroundRect, cornerRadius: max(0, cornerRadius - lineWidth)
        )
        let mask = CAShapeLayer()
        mask.path = clipPath.cgPath
        stripeLayer.mask = mask

        stripeLayer.path = path.cgPath
    }

    private func drawGrid() {
        let path = GridPath()
        let cornerRadius = theme.table.cornerRadius
        let lineWidth = theme.table.borderWidth
        let halfLineWidth = lineWidth / 2
        let columnSeparatorBottom = mergesLastRow
            ? padding + totalHeight - (heights.last ?? 0)
            : totalHeight + padding - halfLineWidth

        let outerRect = CGRect(
            x: padding + halfLineWidth,
            y: padding + halfLineWidth,
            width: totalWidth - lineWidth,
            height: totalHeight - lineWidth
        )

        let outerPath = GridPath.roundedRect(outerRect, cornerRadius: cornerRadius)
        path.append(outerPath)

        var x: CGFloat = padding
        for (index, width) in widths.enumerated() {
            if index < widths.count - 1 {
                x += width
                path.move(to: .init(x: x, y: padding + halfLineWidth))
                path.addGridLine(to: .init(x: x, y: columnSeparatorBottom))
            }
        }

        var y: CGFloat = padding
        for (index, height) in heights.enumerated() {
            if index < heights.count - 1 {
                y += height
                path.move(to: .init(x: padding + halfLineWidth, y: y))
                path.addGridLine(to: .init(x: totalWidth + padding - halfLineWidth, y: y))
            }
        }

        shapeLayer.path = path.cgPath
    }

    private func drawHeaderBackground() {
        guard hasHeaderRow, !heights.isEmpty else {
            headerBackgroundLayer.path = nil
            return
        }

        let cornerRadius = theme.table.cornerRadius
        let lineWidth = theme.table.borderWidth
        let headerHeight = heights[0]

        let headerRect = CGRect(
            x: padding + lineWidth,
            y: padding + lineWidth,
            width: totalWidth - lineWidth * 2,
            height: headerHeight - lineWidth
        )

        let adjustedCornerRadius = max(0, cornerRadius - lineWidth)
        let path = GridPath()

        path.move(to: CGPoint(x: headerRect.minX, y: headerRect.minY + adjustedCornerRadius))
        path.addTopLeftCornerArc(
            center: CGPoint(
                x: headerRect.minX + adjustedCornerRadius, y: headerRect.minY + adjustedCornerRadius
            ),
            radius: adjustedCornerRadius
        )
        path.addGridLine(to: CGPoint(x: headerRect.maxX - adjustedCornerRadius, y: headerRect.minY))
        path.addTopRightCornerArc(
            center: CGPoint(
                x: headerRect.maxX - adjustedCornerRadius, y: headerRect.minY + adjustedCornerRadius
            ),
            radius: adjustedCornerRadius
        )
        path.addGridLine(to: CGPoint(x: headerRect.maxX, y: headerRect.maxY))
        path.addGridLine(to: CGPoint(x: headerRect.minX, y: headerRect.maxY))
        path.close()

        headerBackgroundLayer.path = path.cgPath
    }

    func update(widths: [CGFloat], heights: [CGFloat]) {
        self.widths = widths
        self.heights = heights
        totalWidth = widths.reduce(0, +)
        totalHeight = heights.reduce(0, +)
        markNeedsLayout()
    }

    func setTheme(_ theme: MarkdownTheme) {
        self.theme = theme
        updateThemeColors()
        shapeLayer.lineWidth = theme.table.borderWidth
        markNeedsLayout()
    }

    func setHeaderRow(_ hasHeader: Bool) {
        hasHeaderRow = hasHeader
        markNeedsLayout()
    }

    func setMergesLastRow(_ merges: Bool) {
        guard mergesLastRow != merges else { return }
        mergesLastRow = merges
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

        func addTopLeftCornerArc(center: CGPoint, radius: CGFloat) {
            addArc(withCenter: center, radius: radius, startAngle: .pi, endAngle: 3 * .pi / 2, clockwise: true)
        }

        func addTopRightCornerArc(center: CGPoint, radius: CGFloat) {
            addArc(withCenter: center, radius: radius, startAngle: 3 * .pi / 2, endAngle: 0, clockwise: true)
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

        func addTopLeftCornerArc(center: CGPoint, radius: CGFloat) {
            appendArc(withCenter: center, radius: radius, startAngle: 180, endAngle: 270)
        }

        func addTopRightCornerArc(center: CGPoint, radius: CGFloat) {
            appendArc(withCenter: center, radius: radius, startAngle: 270, endAngle: 0)
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
