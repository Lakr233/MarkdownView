//
//  Created by Lakr233 & Helixform on 2025/2/18.
//  Copyright (c) 2025 Litext Team. All rights reserved.
//

import CoreText
import Foundation

/// A class that encapsulates a drawing action for CTLine rendering
/// Provides a reusable way to perform custom drawing operations on text lines
public class LTXLineDrawingAction: NSObject {
    /// Type alias for the drawing action handler
    /// - Parameters:
    ///   - context: The CGContext to draw into
    ///   - line: The CTLine to draw
    ///   - point: The CGPoint position to draw at
    public typealias ActionHandler = (CGContext, CTLine, CGPoint) -> Void

    /// The drawing action to be performed
    public var action: ActionHandler

    /// Creates a new line drawing action with the specified handler
    /// - Parameter action: The drawing action to execute
    public init(action: @escaping ActionHandler) {
        self.action = action
        super.init()
    }
}
