//
//  Created by Lakr233 & Helixform on 2025/2/18.
//  Copyright (c) 2025 Litext Team. All rights reserved.
//

import CoreText
import Foundation

open class LTXAttachment {
    open var size: CGSize
    open var view: LTXPlatformView?

    private var _runDelegate: CTRunDelegate?

    public init() {
        size = .zero
    }

    @MainActor
    open func attributedStringRepresentation() -> NSAttributedString {
        guard let representableView = view as? LTXAttributeStringRepresentable else {
            return NSAttributedString(string: " ")
        }
        return representableView.attributedStringRepresentation()
    }

    open var runDelegate: CTRunDelegate {
        guard _runDelegate == nil else {
            return _runDelegate!
        }

        var callbacks = CTRunDelegateCallbacks(
            version: kCTRunDelegateVersion1,
            dealloc: { _ in },
            getAscent: { refCon in
                let attachment = Unmanaged<LTXAttachment>.fromOpaque(refCon).takeUnretainedValue()
                return attachment.size.height * 0.9
            },
            getDescent: { refCon in
                let attachment = Unmanaged<LTXAttachment>.fromOpaque(refCon).takeUnretainedValue()
                return attachment.size.height * 0.1
            },
            getWidth: { refCon in
                let attachment = Unmanaged<LTXAttachment>.fromOpaque(refCon).takeUnretainedValue()
                return attachment.size.width
            }
        )

        let unmanagedSelf = Unmanaged.passUnretained(self)
        _runDelegate = CTRunDelegateCreate(&callbacks, unmanagedSelf.toOpaque())

        return _runDelegate!
    }
}
