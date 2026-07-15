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
/// `files.user-selected.read-write`, so a shipping build cannot open an arbitrary
/// file by path: the bytes have to be granted through the powerbox. Two open
/// paths are used, deliberately:
///
/// - **Most opens take the fast path** (see ``launchAppOpening(_:)``): the app is
///   launched in process — the way `XCUIApplication` always has — with an
///   argument naming the fixture's absolute path, and opens it directly. This
///   works because a *build-for-testing* app is granted a temporary read-only
///   exception for the whole file system (Xcode adds it to the test host,
///   alongside `get-task-allow`), so no powerbox and no Open panel are involved.
/// - **The Open-panel path stays covered on purpose** (see
///   ``openAnotherFixture(_:in:timeout:)`` and ``dismissLaunchPanel(in:timeout:)``):
///   the add-file, additional-open and no-file tests still present and drive the
///   real powerbox, so the panel flow itself is not left untested.
///
/// The out-of-band `NSWorkspace`/LaunchServices launch this replaced crashed the
/// XCUITest runner under CI; launching the app in process (as `XCUIApplication`
/// does) is the path CI supports.
///
/// The app under test does **not** have XCTest injected (only the runner does),
/// so its launch-time `isRunningTests` guard is `false`; it opens the named
/// fixture (suppressing the launch panel) or, with no fixture, presents its Open
/// panel. The helpers below launch the app and drive that panel.
enum UITestSupport
{
    /// The launch argument that isolates the app's preferences. Must match
    /// `AppDelegate.isolatedPreferencesArgument`.
    private static let isolatedDefaultsArgument = "-uiTestingIsolatedDefaults"

    /// The launch argument, followed by a fixture's absolute path, that asks the
    /// app to open that fixture at launch. Must match
    /// `AppDelegate.uiTestingOpenFixtureArgument`.
    private static let openFixtureArgument = "-uiTestingOpenFixture"

    /// The identifier of the system Open panel's "Go to Folder" sheet.
    private static let goToFolderSheet = "GoToWindow"

    /// The identifier of the path field inside the "Go to Folder" sheet.
    private static let goToFolderField = "PathTextField"

    /// The UI-test `Fixtures` directory (`Test Files/Fixtures` at the repository
    /// root), resolved relative to this source file so the suite works regardless
    /// of the test bundle's on-disk layout. The fixtures are checked into this
    /// repository (not borrowed from a submodule), so their geometry is fixed and
    /// the tests cannot break under an upstream change.
    static var fixturesDirectory: URL
    {
        URL( fileURLWithPath: #filePath )
            .deletingLastPathComponent() // FITScopeUITests/
            .deletingLastPathComponent() // repo root
            .appendingPathComponent( "Test Files/Fixtures" )
    }

    /// Resolves a fixture by its file name within the `Fixtures` directory.
    ///
    /// - Parameter name: e.g. `MonoImage.fits`.
    /// - Returns: The absolute file URL.
    static func fixtureURL( _ name: String ) -> URL
    {
        self.fixturesDirectory.appendingPathComponent( name )
    }

    /// Launches a fresh instance of the app under test.
    ///
    /// The app is launched with an argument that backs its preferences with an
    /// isolated, wiped-on-launch defaults suite, so the suite never reads from nor
    /// writes to the user's real preferences.
    ///
    /// - Returns: The launched application proxy.
    @MainActor
    static func launchApp() -> XCUIApplication
    {
        let app = XCUIApplication()

        app.launchArguments.append( self.isolatedDefaultsArgument )
        app.launch()

        return app
    }

    /// Launches the app already opening the named fixture, the fast way.
    ///
    /// Instead of driving the system Open panel, the app is launched — in process,
    /// the way `XCUIApplication` always launches it — with an argument naming the
    /// fixture's absolute path, and opens it directly. A build-for-testing app is
    /// granted a temporary read-only exception for the whole file system, so it
    /// can read the fixture without the powerbox, and the launch Open panel is
    /// suppressed for free (the open path sets the app's `didOpenFilesAtLaunch`
    /// flag).
    ///
    /// This replaced an out-of-band `NSWorkspace`/LaunchServices launch that
    /// crashed the XCUITest runner under CI; launching in process is the path CI
    /// supports.
    ///
    /// - Parameter name: Fixture file name within the `Fixtures` directory.
    /// - Returns: The launched application proxy.
    @MainActor
    static func launchAppOpening( _ name: String ) throws -> XCUIApplication
    {
        let app = XCUIApplication()

        app.launchArguments.append( self.isolatedDefaultsArgument )
        app.launchArguments.append( self.openFixtureArgument )
        app.launchArguments.append( self.fixtureURL( name ).path )
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

    /// Polls a condition until it holds or the timeout elapses, without a fixed
    /// sleep. Use for state that is not tied to a single element's existence —
    /// window counts, a row count, an element's `isEnabled`, a parsed read-out.
    ///
    /// - Parameters:
    ///   - timeout:   How long to keep polling, in seconds.
    ///   - interval:  The delay between polls, in seconds.
    ///   - condition: The condition to satisfy.
    /// - Returns: `true` if the condition became true within the timeout.
    @MainActor
    static func waitFor( timeout: TimeInterval, interval: TimeInterval = 0.2, _ condition: () -> Bool ) -> Bool
    {
        let deadline = Date().addingTimeInterval( timeout )

        while Date() < deadline
        {
            if condition()
            {
                return true
            }

            RunLoop.current.run( until: Date().addingTimeInterval( interval ) )
        }

        return condition()
    }

    /// Parses a zoom read-out label such as `"125%"` into its integer percentage.
    ///
    /// - Parameter label: The read-out's accessibility label.
    /// - Returns: The integer percentage, or `nil` if it could not be parsed.
    static func percentage( _ label: String ) -> Int?
    {
        Int( label.trimmingCharacters( in: CharacterSet( charactersIn: "%" ) ) )
    }

    /// Clicks the first *hittable* menu item matching a predicate.
    ///
    /// A title can match several items across the menu bar and an open menu (e.g.
    /// a context-menu "Close" and the Window-menu "Close"); only the presented one
    /// is hittable. The closed menus' items carry a zero/`INFINITY` frame, so
    /// clicking them throws — this picks the hittable match instead.
    ///
    /// - Parameters:
    ///   - app:       The application proxy.
    ///   - predicate: The predicate matched against menu items (e.g. on `title`).
    ///   - timeout:   How long to wait for a hittable match.
    @MainActor
    static func clickMenuItem( in app: XCUIApplication, where predicate: NSPredicate, timeout: TimeInterval = 5 )
    {
        let matches = app.menuItems.matching( predicate )

        let found = self.waitFor( timeout: timeout )
        {
            ( 0 ..< matches.count ).contains { matches.element( boundBy: $0 ).isHittable }
        }

        XCTAssertTrue( found, "No hittable menu item matched \( predicate )." )

        for index in 0 ..< matches.count
        {
            let item = matches.element( boundBy: index )

            if item.isHittable
            {
                item.click()

                return
            }
        }
    }

    /// Clicks the first *hittable* menu item with the given title.
    ///
    /// - Parameters:
    ///   - title:   The menu item's title (or label).
    ///   - app:     The application proxy.
    ///   - timeout: How long to wait for a hittable match.
    @MainActor
    static func clickMenuItem( _ title: String, in app: XCUIApplication, timeout: TimeInterval = 5 )
    {
        self.clickMenuItem( in: app, where: NSPredicate( format: "title == %@ OR label == %@", title, title ), timeout: timeout )
    }

    /// Selects an option in a pop-up `Picker` by its visible title.
    ///
    /// A SwiftUI `Picker` renders as a pop-up button on macOS: clicking it opens a
    /// menu whose items are matched by title. The option title is the only string
    /// available to identify a menu item (menu items carry no accessibility
    /// identifier), so it is matched by its displayed text — the value being
    /// chosen, not a structural identifier.
    ///
    /// A picker option title can collide with a menu-bar command's title (e.g. the
    /// "Screen Transfer" stretch option and the "Screen Transfer" editor-window
    /// command), so more than one menu item can carry the same title. Only the
    /// presented option is hittable, so ``clickMenuItem(in:where:timeout:)`` selects
    /// the hittable match rather than assuming the title is unique.
    ///
    /// - Parameters:
    ///   - picker:  The picker element (located by its accessibility identifier).
    ///   - title:   The visible title of the option to choose.
    ///   - app:     The application proxy.
    ///   - timeout: How long to wait for the picker and its menu item.
    @MainActor
    static func selectPickerOption( _ picker: XCUIElement, _ title: String, in app: XCUIApplication, timeout: TimeInterval = 10 )
    {
        XCTAssertTrue( picker.waitForExistence( timeout: timeout ), "The picker did not appear." )

        picker.click()

        self.clickMenuItem( title, in: app, timeout: timeout )
    }

    /// Cancels the Open panel the app presents at launch, leaving the app running
    /// with no file open — the right starting point for testing UI that has
    /// nothing to do with a loaded image (such as the Preferences window).
    ///
    /// - Parameters:
    ///   - app:     The launched application proxy.
    ///   - timeout: How long to wait for the panel to appear and dismiss.
    @MainActor
    static func dismissLaunchPanel( in app: XCUIApplication, timeout: TimeInterval = 15 )
    {
        let dialog = app.dialogs.firstMatch

        XCTAssertTrue( dialog.waitForExistence( timeout: timeout ), "The Open panel did not appear." )

        app.typeKey( .escape, modifierFlags: [] )

        XCTAssertTrue( dialog.waitForNonExistence( timeout: timeout ), "The Open panel did not dismiss." )
    }

    /// Opens an *additional* fixture, through the real Open panel, once the app
    /// already has a window. Most opens now take the faster shared-container path
    /// (see ``launchAppOpening(_:)``); this deliberately drives the system panel so
    /// the powerbox flow itself stays covered. No panel is showing at this
    /// point, so it is requested first with the Open command (`⌘O`) and then driven.
    ///
    /// - Parameters:
    ///   - name:    Fixture file name within the `Fixtures` directory.
    ///   - app:     The launched application proxy.
    ///   - timeout: How long to wait for the panel and its field to appear.
    @MainActor
    static func openAnotherFixture( _ name: String, in app: XCUIApplication, timeout: TimeInterval = 15 ) throws
    {
        app.typeKey( "o", modifierFlags: .command )

        try self.drivePanel( name, in: app, timeout: timeout )
    }

    /// Drives a currently-presented Open panel to select the named fixture.
    ///
    /// The panel appears as a dialog within the app's own accessibility tree.
    /// Rather than type blindly (which races a freshly-presented panel), this opens
    /// *Go to Folder* (`⌘⇧G`), **waits for its path field** (`PathTextField`),
    /// types the absolute path into that field, and only then confirms — so the
    /// keystrokes can never be sent before the field is ready. The open is
    /// confirmed by waiting for the sheet to dismiss before the final Return.
    ///
    /// - Parameters:
    ///   - name:    Fixture file name within the `Fixtures` directory.
    ///   - app:     The launched application proxy.
    ///   - timeout: How long to wait for the panel and its field to appear.
    @MainActor
    private static func drivePanel( _ name: String, in app: XCUIApplication, timeout: TimeInterval ) throws
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
