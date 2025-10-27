//
//  LocalizedText.swift
//  Litext
//
//  Created by Lakr233 & Helixform on 2025/2/18.
//  Copyright (c) 2025 Litext Team. All rights reserved.
//

import Foundation

///
/// Make sure to add following key to Info.plist
///
/// **Localized resources can be mixed** -> true
///

public enum LocalizedText {
    public static let copy = NSLocalizedString("Copy", bundle: .module, comment: "Copy menu item")
    public static let selectAll = NSLocalizedString("Select All", bundle: .module, comment: "Select all menu item")
    public static let share = NSLocalizedString("Share", bundle: .module, comment: "Share menu item")
    public static let search = NSLocalizedString("Search", bundle: .module, comment: "Search index menu item")
}
