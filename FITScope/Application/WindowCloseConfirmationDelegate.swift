/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import AppKit

/// A window-delegate proxy that warns before a window closes when it has unsaved
/// image adjustments, vetoing the close if the user cancels.
///
/// SwiftUI owns a `WindowGroup` window's delegate and offers no declarative hook
/// to confirm a close, so this bridges to AppKit's `windowShouldClose(_:)` — the
/// single veto point consulted by both the close button and ⌘W. It installs
/// itself as the window's delegate while forwarding every message it does not
/// itself implement to SwiftUI's original delegate (``forwardee``), so SwiftUI's
/// own window and scene lifecycle keep working. `NSWindow.delegate` is weak, so
/// the host must retain this object for the window's lifetime.
@MainActor
public final class WindowCloseConfirmationDelegate: NSObject, NSWindowDelegate
{
    /// SwiftUI's original window delegate, to which every message this proxy does
    /// not handle is forwarded. Weak, since SwiftUI retains its own delegate.
    ///
    /// `nonisolated(unsafe)` because the `NSObject` message-forwarding overrides
    /// (`responds(to:)` / `forwardingTarget(for:)`) are themselves `nonisolated`,
    /// yet AppKit only ever dispatches window-delegate messages on the main thread,
    /// so every access — those overrides and ``install(on:hasAdjustments:)`` —
    /// happens on the main actor in practice.
    public nonisolated( unsafe ) weak var forwardee: NSWindowDelegate?

    /// Reports whether the window currently has adjustments worth warning about.
    /// Supplied by the host so this delegate stays free of model details.
    public var hasAdjustments: () -> Bool = { false }

    /// Installs this proxy as `window`'s delegate, remembering the current delegate
    /// as the forwardee, and adopts the given adjustments query.
    ///
    /// Idempotent: calling it again for a window this proxy already owns is a
    /// no-op, so it can be driven from a callback that fires more than once.
    ///
    /// - Parameters:
    ///   - window:         The window to guard.
    ///   - hasAdjustments: Reports whether the window has adjustments to warn about.
    public func install( on window: NSWindow, hasAdjustments: @escaping () -> Bool )
    {
        guard window.delegate !== self
        else
        {
            return
        }

        self.forwardee      = window.delegate
        self.hasAdjustments = hasAdjustments
        window.delegate     = self
    }

    /// Vetoes a close when the window has adjustments, unless the user confirms.
    ///
    /// - Parameter sender: The window about to close.
    /// - Returns: `true` to allow the close, `false` to cancel it.
    public func windowShouldClose( _ sender: NSWindow ) -> Bool
    {
        guard self.hasAdjustments()
        else
        {
            return true
        }

        return Self.confirmDiscardingAdjustments()
    }

    /// Reports responsiveness for this proxy *and* the forwarded delegate, so
    /// AppKit still dispatches the delegate methods only SwiftUI implements.
    ///
    /// - Parameter aSelector: The selector being probed.
    /// - Returns: Whether this proxy or its forwardee responds to it.
    public override func responds( to aSelector: Selector! ) -> Bool
    {
        super.responds( to: aSelector ) || ( self.forwardee?.responds( to: aSelector ) ?? false )
    }

    /// Routes any message this proxy does not implement to SwiftUI's delegate.
    ///
    /// - Parameter aSelector: The selector being dispatched.
    /// - Returns: The forwardee, or `nil` when there is none.
    public override func forwardingTarget( for aSelector: Selector! ) -> Any?
    {
        self.forwardee
    }

    /// Presents the "adjustments will be lost" warning and reports the choice.
    ///
    /// A synchronous, app-modal `NSAlert`, so it can return a decision directly to
    /// `windowShouldClose(_:)`. "Cancel" is the default (Return), so an accidental
    /// dismissal keeps the window and its adjustments.
    ///
    /// - Returns: `true` when the user chose to close anyway, `false` to cancel.
    private static func confirmDiscardingAdjustments() -> Bool
    {
        let alert             = NSAlert()
        alert.alertStyle      = .warning
        alert.messageText     = "Close this window and discard its adjustments?"
        alert.informativeText = "This window has images with adjustments that haven't been exported. Closing the window will discard them."

        let closeButton  = alert.addButton( withTitle: "Close Anyway" )
        let cancelButton = alert.addButton( withTitle: "Cancel" )

        closeButton.hasDestructiveAction = true
        closeButton.keyEquivalent        = ""
        cancelButton.keyEquivalent       = "\r"

        return alert.runModal() == .alertFirstButtonReturn
    }
}
