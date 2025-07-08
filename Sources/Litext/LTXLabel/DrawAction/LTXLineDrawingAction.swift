//
//  Created by Lakr233 & Helixform on 2025/2/18.
//  Copyright (c) 2025 Litext Team. All rights reserved.
//

import CoreText
import Foundation

public class LTXLineDrawingAction: NSObject {
    public typealias ActionHandler = (CGContext, CTLine, CGPoint) -> Void

    public var action: ActionHandler
    public var performOncePerAttribute: Bool

    public init(action: @escaping ActionHandler) {
        self.action = action
        performOncePerAttribute = true
        super.init()
    }

    public init(multilineAction action: @escaping ActionHandler) {
        self.action = action
        performOncePerAttribute = false
        super.init()
    }
}
