//
//  MarkdownTextKitBridge.swift
//  MarkdownView
//
//  Created by GitHub Copilot on 2025/10/13.
//

import CoreText
import Foundation
import UIKit

enum MarkdownReplacementText {
    static let attachment: String = "\u{FFFC}"
}

protocol MarkdownAttributedStringRepresentable: AnyObject {
    func markdownAttributedStringRepresentation() -> NSAttributedString
}

final class MarkdownAttachment {
    private var cachedRunDelegate: CTRunDelegate?
    private var copyRepresentation: NSAttributedString?
    private lazy var textAttachmentStorage = MarkdownTextAttachment(owner: self)

    init(copyRepresentation: NSAttributedString? = nil) {
        self.copyRepresentation = copyRepresentation
    }

    static func hold(attrString: NSAttributedString) -> MarkdownAttachment {
        MarkdownAttachment(copyRepresentation: attrString)
    }

    var size: CGSize = .zero

    var view: UIView? {
        didSet { textAttachmentStorage.hostedView = view }
    }

    var runDelegate: CTRunDelegate {
        if let cachedRunDelegate { return cachedRunDelegate }

        var callbacks = CTRunDelegateCallbacks(
            version: kCTRunDelegateVersion1,
            dealloc: { _ in },
            getAscent: { refCon in
                let attachment = Unmanaged<MarkdownAttachment>.fromOpaque(refCon).takeUnretainedValue()
                return attachment.size.height * 0.9
            },
            getDescent: { refCon in
                let attachment = Unmanaged<MarkdownAttachment>.fromOpaque(refCon).takeUnretainedValue()
                return attachment.size.height * 0.1
            },
            getWidth: { refCon in
                let attachment = Unmanaged<MarkdownAttachment>.fromOpaque(refCon).takeUnretainedValue()
                return attachment.size.width
            }
        )

        let unmanaged = Unmanaged.passUnretained(self)
        let opaque = unmanaged.toOpaque()
        guard let delegate = CTRunDelegateCreate(&callbacks, opaque) else {
            fatalError("Failed to create CTRunDelegate for MarkdownAttachment")
        }

        cachedRunDelegate = delegate
        return delegate
    }

    func resolvedTextAttachment() -> MarkdownTextAttachment {
        textAttachmentStorage.hostedView = view
        return textAttachmentStorage
    }

    func attributedStringRepresentation() -> NSAttributedString {
        if let view = view as? MarkdownAttributedStringRepresentable {
            return view.markdownAttributedStringRepresentation()
        }
        if let copyRepresentation {
            return copyRepresentation
        }
        return NSAttributedString(string: " ")
    }
}

final class MarkdownLineDrawingAction {
    typealias Handler = (CGContext, CTLine, CGPoint, CGRect) -> Void

    let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }
}

final class BlockquoteDrawingContext {
    private var pendingBounds: CGRect?
    private var lastResolvedBounds: CGRect?
    let fillColor: UIColor
    let headIndent: CGFloat
    let lineWidth: CGFloat
    let inset: CGFloat
    let verticalInset: CGFloat

    init(
        fillColor: UIColor,
        headIndent: CGFloat,
        lineWidth: CGFloat = 4,
        inset: CGFloat = 4,
        verticalInset: CGFloat = 2
    ) {
        self.fillColor = fillColor
        self.headIndent = headIndent
        self.lineWidth = lineWidth
        self.inset = inset
        self.verticalInset = verticalInset
    }

    func accumulate(_ rect: CGRect) {
        guard !rect.isNull, !rect.isInfinite, !rect.isEmpty else { return }
        pendingBounds = pendingBounds?.union(rect) ?? rect
    }

    func consumeBounds() -> CGRect? {
        if let bounds = pendingBounds {
            if let lastResolvedBounds {
                self.lastResolvedBounds = lastResolvedBounds.union(bounds)
            } else {
                lastResolvedBounds = bounds
            }
            pendingBounds = nil
            return lastResolvedBounds
        }
        return lastResolvedBounds
    }

    func resetBounds() {
        pendingBounds = nil
        lastResolvedBounds = nil
    }
}

final class MarkdownTextAttachment: NSTextAttachment {
    private static let transparentImage: UIImage = {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 1, height: 1), false, 0)
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }()

    weak var owner: MarkdownAttachment?
    var hostedView: UIView?

    init(owner: MarkdownAttachment) {
        self.owner = owner
        super.init(data: nil, ofType: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFrag: CGRect,
        glyphPosition _: CGPoint,
        characterIndex _: Int
    ) -> CGRect {
        guard let owner else { return super.attachmentBounds(for: textContainer, proposedLineFragment: lineFrag, glyphPosition: .zero, characterIndex: 0) }
        let size = owner.size
        if size == .zero {
            return .init(origin: .zero, size: .init(width: lineFrag.width, height: lineFrag.height))
        }
        return .init(origin: .zero, size: size)
    }

    override func image(
        forBounds _: CGRect,
        textContainer _: NSTextContainer?,
        characterIndex _: Int
    ) -> UIImage? {
        guard hostedView == nil else { return Self.transparentImage }
        return Self.transparentImage
    }
}

extension NSAttributedString.Key {
    static let markdownAttachment: NSAttributedString.Key = .init("markdownAttachment")
    static let markdownLineDrawing: NSAttributedString.Key = .init("markdownLineDrawing")
    static let blockquoteContext: NSAttributedString.Key = .init("blockquoteContext")
}

extension [NSAttributedString.Key: Any] {
    mutating func merge(attachment: MarkdownAttachment) {
        self[.markdownAttachment] = attachment
        self[kCTRunDelegateAttributeName as NSAttributedString.Key] = attachment.runDelegate
    }

    mutating func merge(lineDrawing action: MarkdownLineDrawingAction) {
        self[.markdownLineDrawing] = action
    }
}
