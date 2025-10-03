//
//  Created by Lakr233 & Helixform on 2025/2/18.
//  Copyright (c) 2025 Litext Team. All rights reserved.
//

import Foundation

@MainActor
public protocol LTXAttributeStringRepresentable {
    func attributedStringRepresentation() -> NSAttributedString
}
