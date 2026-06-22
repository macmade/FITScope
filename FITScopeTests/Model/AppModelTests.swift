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

@testable import FITScope
import Foundation
import Testing

/// Tests for `AppModel`: routing files to the active window vs. a new one, and
/// forgetting a window's model once it closes so a later open does not route
/// into a window that is gone.
@Suite( "AppModel" )
@MainActor
struct AppModelTests
{
    private var url: URL
    {
        URL( filePath: "/tmp/FITScopeAppModelTests.fits" )
    }

    @Test
    func opensANewWindowWhenNoWindowIsActive() throws
    {
        let app       = AppModel()
        var requested = 0

        app.openWindowWithURLs = { _ in requested += 1 }

        app.openIntoActiveWindowOrNew( urls: [ self.url ] )

        #expect( requested == 1, "with no active window, opening files must create a new window" )
    }

    @Test
    func routesFilesIntoTheActiveWindow() throws
    {
        let app       = AppModel()
        let model     = WindowModel()
        var requested = 0

        app.activeModel        = model
        app.openWindowWithURLs = { _ in requested += 1 }

        app.openIntoActiveWindowOrNew( urls: [ self.url ] )

        #expect( model.files.count == 1, "with an active window, files open into it" )
        #expect( requested == 0, "an active window must not also spawn a new window" )
    }

    @Test
    func opensAFreshWindowAfterTheActiveOneClosed() throws
    {
        let app   = AppModel()
        let model = WindowModel()

        app.activeModel = model

        // The window closes: its model must stop being treated as active.
        app.windowDidClose( model )

        var requested = 0

        app.openWindowWithURLs = { _ in requested += 1 }

        app.openIntoActiveWindowOrNew( urls: [ self.url ] )

        #expect( requested == 1, "after the active window closed, opening files must create a new window, not route into the closed one" )
        #expect( model.files.isEmpty, "no file should be routed into the closed window's model" )
    }

    @Test
    func closingANonActiveWindowKeepsTheActiveOne() throws
    {
        let app    = AppModel()
        let active = WindowModel()
        let other  = WindowModel()

        app.activeModel = active

        app.windowDidClose( other )

        #expect( app.activeModel === active, "closing a different window must not clear the active one" )
    }

    @Test
    func openInNewWindowAlwaysSpawnsANewWindowEvenWithAnActiveOne() throws
    {
        let app           = AppModel()
        let model         = WindowModel()
        var requestedURLs = [ URL ]()

        app.activeModel        = model
        app.openWindowWithURLs = { requestedURLs.append( contentsOf: $0 ) }

        app.openInNewWindow( urls: [ self.url ] )

        #expect( requestedURLs == [ self.url ], "open-in-new-window must always request a new window carrying the URLs" )
        #expect( model.files.isEmpty, "open-in-new-window must not route into the active window" )
    }

    @Test
    func openInNewWindowIgnoresAnEmptyURLList() throws
    {
        let app       = AppModel()
        var requested = 0

        app.openWindowWithURLs = { _ in requested += 1 }

        app.openInNewWindow( urls: [] )

        #expect( requested == 0, "opening no files must not spawn a window" )
    }

    @Test
    func handsTheActiveWindowToAnotherWhenTheActiveOneCloses() throws
    {
        let app    = AppModel()
        let first  = WindowModel()
        let second = WindowModel()

        // `first` is active; it closes, then `second` comes to the front — the
        // window that becomes key re-sets the active model (here standing in for
        // the view's `appearsActive` change).
        app.activeModel = first
        app.windowDidClose( first )
        app.activeModel = second

        app.openIntoActiveWindowOrNew( urls: [ self.url ] )

        #expect( second.files.count == 1, "files open into the window that became active after the previous one closed" )
        #expect( first.files.isEmpty, "the closed window receives nothing" )
    }
}
