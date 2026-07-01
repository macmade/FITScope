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

/// Tests for `AppDelegate`'s window handling — specifically that surfacing a
/// buried/off-Space modal panel lets it follow the user to the active Space when
/// the app is reactivated.
@Suite( "AppDelegate" )
@MainActor
struct AppDelegateTests
{
    /// Builds a bare off-screen window with an empty collection behavior, so a
    /// test can observe exactly what `surface(_:)` adds.
    private func makeWindow() -> NSWindow
    {
        let window = NSWindow(
            contentRect: NSRect( x: 0, y: 0, width: 100, height: 100 ),
            styleMask:   [ .titled ],
            backing:     .buffered,
            defer:       true
        )

        window.collectionBehavior = []

        return window
    }

    @Test
    func surfacingAWindowLetsItFollowToTheActiveSpace() throws
    {
        let window = self.makeWindow()

        #expect( window.collectionBehavior.contains( .moveToActiveSpace ) == false, "the freshly built window must not already move to the active Space" )

        AppDelegate.surface( window )

        #expect( window.collectionBehavior.contains( .moveToActiveSpace ), "surfacing a window must let it follow the user to the active Space" )
    }

    @Test
    func surfacingPreservesExistingCollectionBehavior() throws
    {
        let window = self.makeWindow()

        window.collectionBehavior = [ .fullScreenPrimary ]

        AppDelegate.surface( window )

        #expect( window.collectionBehavior.contains( .fullScreenPrimary ), "surfacing must add to, not replace, the window's existing collection behavior" )
        #expect( window.collectionBehavior.contains( .moveToActiveSpace ), "surfacing must still add the active-Space behavior" )
    }
}
