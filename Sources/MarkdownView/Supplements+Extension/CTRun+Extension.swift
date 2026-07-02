//
//  Created by ktiays on 2025/1/22.
//  Copyright (c) 2025 ktiays. All rights reserved.
//

import CoreText
#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public extension CTRun {
    var attributes: [NSAttributedString.Key: Any] {
        (CTRunGetAttributes(self) as? [NSAttributedString.Key: Any]) ?? [:]
    }
}
