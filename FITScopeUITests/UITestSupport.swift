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
import XCTest

/// Shared plumbing for the UI-test suite.
///
/// The app is sandboxed (`com.apple.security.app-sandbox`) with only
/// `files.user-selected.read-write`, so it cannot open an arbitrary file by
/// path: the bytes have to be granted through the powerbox. Rather than weaken
/// the sandbox or bundle fixtures, the tests open files exactly as a user would
/// — by driving the standard Open panel. This grants the sandbox extension
/// legitimately and keeps the shipping configuration untouched.
///
/// The app under test does **not** have XCTest injected (only the runner does),
/// so its launch-time `isRunningTests` guard is `false` and it presents its Open
/// panel automatically at launch. The helpers below drive that panel.
enum UITestSupport
{
    /// The identifier of the system Open panel's "Go to Folder" sheet.
    private static let goToFolderSheet = "GoToWindow"

    /// The identifier of the path field inside the "Go to Folder" sheet.
    private static let goToFolderField = "PathTextField"

    /// The UI-test `Fixtures` directory, resolved relative to this source file so
    /// the suite works regardless of the test bundle's on-disk layout. The
    /// fixtures are checked into this repository (not borrowed from a submodule),
    /// so their geometry is fixed and the tests cannot break under an upstream
    /// change.
    static var fixturesDirectory: URL
    {
        URL( fileURLWithPath: #filePath )
            .deletingLastPathComponent() // FITScopeUITests/
            .appendingPathComponent( "Fixtures" )
    }

    /// Resolves a fixture by its file name within the `Fixtures` directory.
    ///
    /// - Parameter name: e.g. `RenderableImage.fits`.
    /// - Returns: The absolute file URL.
    static func fixtureURL( _ name: String ) -> URL
    {
        self.fixturesDirectory.appendingPathComponent( name )
    }

    /// Launches a fresh instance of the app under test.
    ///
    /// - Returns: The launched application proxy.
    @MainActor
    static func launchApp() -> XCUIApplication
    {
        let app = XCUIApplication()

        app.launch()

        return app
    }

    /// Returns a descendant of `app` with the given accessibility identifier,
    /// regardless of its element type.
    ///
    /// - Parameters:
    ///   - app: The application proxy to query.
    ///   - id:  The accessibility identifier to match.
    /// - Returns: The first matching element (which may not yet exist).
    @MainActor
    static func element( _ app: XCUIApplication, _ id: String ) -> XCUIElement
    {
        app.descendants( matching: .any ).matching( identifier: id ).firstMatch
    }

    /// Opens a fixture through the app's Open panel, granting the sandbox access
    /// the same way a user's selection would.
    ///
    /// The Open panel the app presents at launch appears as a dialog within the
    /// app's own accessibility tree. Rather than type blindly (which races a
    /// freshly-presented panel), this opens *Go to Folder* (`⌘⇧G`), **waits for
    /// its path field** (`PathTextField`), types the absolute path into that
    /// field, and only then confirms — so the keystrokes can never be sent before
    /// the field is ready. The open is confirmed by waiting for the sheet to
    /// dismiss before the final Return.
    ///
    /// - Parameters:
    ///   - name:    Fixture file name within the `Fixtures` directory.
    ///   - app:     The launched application proxy.
    ///   - timeout: How long to wait for the panel and its field to appear.
    @MainActor
    static func openFixture( _ name: String, in app: XCUIApplication, timeout: TimeInterval = 15 ) throws
    {
        let path   = self.fixtureURL( name ).path
        let dialog = app.dialogs.firstMatch

        XCTAssertTrue( dialog.waitForExistence( timeout: timeout ), "The Open panel did not appear." )

        // Open "Go to Folder" and wait for its field before typing anything.
        app.typeKey( "g", modifierFlags: [ .command, .shift ] )

        let field = app.textFields[ self.goToFolderField ]

        XCTAssertTrue( field.waitForExistence( timeout: timeout ), "The Go-to-Folder field did not appear." )

        // Replace whatever the field pre-filled, then navigate to and select the
        // file. The path is pasted rather than typed character-by-character: it
        // is faster and not timing-sensitive. (This replaces the system
        // pasteboard contents, which is acceptable within a test run.)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString( path, forType: .string )

        field.typeKey( "a", modifierFlags: .command )
        field.typeKey( "v", modifierFlags: .command )
        field.typeKey( .return, modifierFlags: [] )

        // The sheet dismisses with the file selected; confirm the open once it is
        // gone, so the final Return is never swallowed by the still-open sheet.
        XCTAssertTrue( field.waitForNonExistence( timeout: timeout ), "The Go-to-Folder sheet did not dismiss." )
        app.typeKey( .return, modifierFlags: [] )
    }
}
