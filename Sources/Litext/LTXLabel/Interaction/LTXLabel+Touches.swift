//
//  LTXLabel+Touches.swift
//  Litext
//
//  Created by Lakr233 & Helixform on 2025/2/18.
//  Copyright (c) 2025 Litext Team. All rights reserved.
//

import CoreText
import Foundation

@MainActor
private let menuOwnerLock = NSLock()
@MainActor
private var _menuOwnerIdentifier: UUID = .init()

@MainActor
private var menuOwnerIdentifier: UUID {
    get {
        menuOwnerLock.lock()
        defer { menuOwnerLock.unlock() }
        return _menuOwnerIdentifier
    }
    set {
        menuOwnerLock.lock()
        defer { menuOwnerLock.unlock() }
        _menuOwnerIdentifier = newValue
    }
}

import UIKit

// MARK: - Presses Handling

public extension LTXLabel {
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard isSelectable else {
            super.pressesBegan(presses, with: event)
            return
        }
        var didHandleEvent = false
        for press in presses {
            guard let key = press.key else { continue }
            if key.charactersIgnoringModifiers == "c", key.modifierFlags.contains(.command) {
                let copiedText = copySelectedText()
                didHandleEvent = copiedText.length > 0
            }
            if key.charactersIgnoringModifiers == "a", key.modifierFlags.contains(.command) {
                selectAllText()
                didHandleEvent = true
            }
        }
        if !didHandleEvent { super.pressesBegan(presses, with: event) }
    }

    override var canBecomeFocused: Bool {
        isSelectable
    }
}

// MARK: - Hit Testing

public extension LTXLabel {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for handler in [selectionHandleStart, selectionHandleEnd] {
            let rect = handler.frame
                .insetBy(
                    dx: -LTXSelectionHandle.knobExtraResponsiveArea,
                    dy: -LTXSelectionHandle.knobExtraResponsiveArea
                )
            if rect.contains(point) { return true }
        }

        if !bounds.contains(point) { return false }

        for view in attachmentViews {
            if view.frame.contains(point) {
                return super.point(inside: point, with: event)
            }
        }

        if isSelectable || highlightRegionAtPoint(point) != nil {
            return true
        }

        return false
    }
}

// MARK: - Touch Handling

public extension LTXLabel {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.count == 1,
              let firstTouch = touches.first
        else {
            super.touchesBegan(touches, with: event)
            return
        }

        if isSelectable, !isFirstResponder {
            // to received keyboard event from there
            _ = becomeFirstResponder()
        }

        let location = firstTouch.location(in: self)
        setInteractionStateToBegin(initialLocation: location)

        if isLocationAboveAttachmentView(location: location) {
            super.touchesBegan(touches, with: event)
            return
        }
        interactionState.isFirstMove = true

        if activateHighlightRegionAtPoint(location) {
            return
        }

        bumpClickCountIfWithinTimeGap()
        if !isSelectable { return }

        handleTouchClicks(at: location, with: firstTouch)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touches.count == 1,
              let firstTouch = touches.first
        else {
            super.touchesMoved(touches, with: event)
            return
        }

        let location = firstTouch.location(in: self)
        guard isTouchReallyMoved(location) else { return }
        defer { self.delegate?.ltxLabelDetectedUserEventMovingAtLocation(self, location: location) }

        deactivateHighlightRegion()
        performContinuousStateReset()

        if interactionState.isFirstMove {
            interactionState.isFirstMove = false
        }

        guard isSelectable else { return }

        if isPointerDevice(touch: firstTouch) {
            updateSelectionRange(withLocation: location)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isInteractionInProgress = false
        guard touches.count == 1,
              let firstTouch = touches.first
        else {
            super.touchesEnded(touches, with: event)
            return
        }
        let location = firstTouch.location(in: self)
        defer { deactivateHighlightRegion() }

        if !isTouchReallyMoved(location),
           interactionState.clickCount <= 1
        {
            if isLocationInSelection(location: location) {
                showSelectionMenuController()
            } else {
                clearSelection()
            }
        }

        guard selectionRange == nil, !isTouchReallyMoved(location) else { return }
        for region in highlightRegions {
            let rects = region.rects.map {
                convertRectFromTextLayout($0.cgRectValue, insetForInteraction: true)
            }
            for rect in rects where rect.contains(location) {
                self.delegate?.ltxLabelDidTapOnHighlightContent(self, region: region, location: location)
                break
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isInteractionInProgress = false
        guard touches.count == 1,
              let firstTouch = touches.first
        else {
            super.touchesCancelled(touches, with: event)
            return
        }
        _ = firstTouch
        deactivateHighlightRegion()
    }

    // for handling right click on iOS
    func installContextMenuInteraction() {
        let interaction = UIContextMenuInteraction(delegate: self)
        addInteraction(interaction)
    }

    func installTextPointerInteraction() {
        if #available(iOS 13.4, macCatalyst 13.4, *) {
            let pointerInteraction = UIPointerInteraction(delegate: self)
            self.addInteraction(pointerInteraction)
        }
    }
}

// MARK: - Touch Interaction Helpers

private extension LTXLabel {
    func handleTouchClicks(at location: CGPoint, with touch: UITouch) {
        switch interactionState.clickCount {
        case 1:
            handleSingleTap(at: location, with: touch)
        case 2:
            handleDoubleTap(at: location)
        case 3:
            handleTripleTap(at: location)
        default:
            break
        }
    }

    func handleSingleTap(at location: CGPoint, with touch: UITouch) {
        if isPointerDevice(touch: touch) {
            if let index = textIndexAtPoint(location) {
                selectionRange = NSRange(location: index, length: 0)
            }
        }
    }

    func handleDoubleTap(at location: CGPoint) {
        if let index = textIndexAtPoint(location) {
            selectWordAtIndex(index)
            // prevent touches did end discard the changes
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                self.selectWordAtIndex(index)
            }
        }
    }

    func handleTripleTap(at location: CGPoint) {
        if let index = textIndexAtPoint(location) {
            selectLineAtIndex(index)
            // prevent touches did end discard the changes
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                self.selectLineAtIndex(index)
            }
        }
    }
}

// MARK: - Pointer Device Detection

extension LTXLabel {
    func isPointerDevice(touch: UITouch) -> Bool {
        #if targetEnvironment(macCatalyst)
            return true // Mac Catalyst 总是指针设备
        #else
            switch touch.type {
            case .indirectPointer, .pencil:
                return true
            default:
                return false
            }
        #endif
    }
}
