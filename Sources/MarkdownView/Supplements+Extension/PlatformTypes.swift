//
//  PlatformTypes.swift
//  MarkdownView
//
//  Created by 秋星桥 on 2026/2/1.
//

@_exported import CoreGraphics
@_exported import CoreText
@_exported import Foundation
@_exported import Litext

#if canImport(UIKit)
    @_exported import UIKit

    public typealias PlatformView = UIView
    public typealias PlatformImage = UIImage
    public typealias PlatformScrollView = UIScrollView
#elseif canImport(AppKit)
    @_exported import AppKit

    public typealias PlatformView = NSView
    public typealias PlatformImage = NSImage
    public typealias PlatformScrollView = NSScrollView
#endif
