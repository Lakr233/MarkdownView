//
//  RenderedTextContent.swift
//  MarkdownView
//
//  Created by 秋星桥 on 6/3/25.
//

import Litext

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public struct RenderedTextContent {
    public let image: PlatformImage?
    public let text: String

    public typealias Map = [String: RenderedTextContent]

    public init(image: PlatformImage?, text: String) {
        self.image = image
        self.text = text
    }
}
