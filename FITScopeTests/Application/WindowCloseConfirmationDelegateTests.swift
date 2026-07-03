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
@testable import FITScope
import Testing

/// Tests for `WindowCloseConfirmationDelegate`: the parts that don't require the
/// modal confirmation UI — that an unadjusted window closes without a prompt, and
/// that the proxy installs itself while forwarding other delegate calls to
/// SwiftUI's original delegate. The "has adjustments" path presents a modal
/// `NSAlert`, which a unit test can't drive, so it is left to an interactive check.
@Suite( "WindowCloseConfirmationDelegate" )
@MainActor
struct WindowCloseConfirmationDelegateTests
{
    /// A stand-in for SwiftUI's original window delegate, used to prove the proxy
    /// forwards the delegate methods it doesn't handle itself.
    private final class SpyDelegate: NSObject, NSWindowDelegate
    {
        func windowDidResize( _ notification: Notification ) {}
    }

    /// With nothing adjusted, closing must proceed with no confirmation.
    @Test
    func allowsCloseWhenThereAreNoAdjustments()
    {
        let delegate = WindowCloseConfirmationDelegate()
        let window   = NSWindow()

        delegate.hasAdjustments = { false }

        #expect( delegate.windowShouldClose( window ) )
    }

    /// Installing makes the proxy the window's delegate, remembers the original as
    /// the forwardee, and adopts the supplied adjustments query.
    @Test
    func installBecomesTheDelegateAndRemembersTheOriginal()
    {
        let window   = NSWindow()
        let original = SpyDelegate()

        window.delegate = original

        let delegate = WindowCloseConfirmationDelegate()

        delegate.install( on: window ) { false }

        #expect( window.delegate === delegate )
        #expect( delegate.forwardee === original )
        #expect( delegate.windowShouldClose( window ) )
    }

    /// Delegate messages the proxy does not implement are routed to the original
    /// delegate, so SwiftUI's own window/scene handling keeps working.
    @Test
    func forwardsUnhandledDelegateMethodsToTheOriginal()
    {
        let window   = NSWindow()
        let original = SpyDelegate()

        window.delegate = original

        let delegate = WindowCloseConfirmationDelegate()

        delegate.install( on: window ) { false }

        #expect( delegate.forwardingTarget( for: #selector( NSWindowDelegate.windowDidResize( _: ) ) ) as? SpyDelegate === original )
        #expect( delegate.responds( to: #selector( NSWindowDelegate.windowDidResize( _: ) ) ) )
    }
}
