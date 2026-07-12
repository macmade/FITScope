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

/// Drives launch and system file-open behaviour: presents the Open panel at
/// launch and opens files delivered by Finder or the Dock, routing them through
/// the shared ``AppModel``.
@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate
{
    /// The shared app model, also injected into the SwiftUI environment.
    public let appModel = AppModel()

    #if DEBUG

        /// The launch argument that makes the app back its preferences with an
        /// isolated, wiped-on-launch defaults suite, so UI tests never read or mutate
        /// the real user preferences.
        ///
        /// Test-only, so it is compiled out of a release build entirely.
        public static let isolatedPreferencesArgument = "-uiTestingIsolatedDefaults"

        /// The launch argument, followed by a single absolute file path, that tells a
        /// UI-test launch to open that fixture at startup — the fast, powerbox-free
        /// path the UI-test suite uses instead of driving the system Open panel.
        ///
        /// A shipping, sandboxed build cannot open an arbitrary path; a build-for-
        /// testing launch can, because Xcode grants the app-under-test a temporary
        /// read-only exception for the whole file system (alongside `get-task-allow`
        /// and the testmanagerd exceptions). This is honoured only alongside
        /// ``isolatedPreferencesArgument``. Test-only, so it is compiled out of a
        /// release build entirely.
        public static let uiTestingOpenFixtureArgument = "-uiTestingOpenFixture"

    #endif

    /// The app's persisted user preferences, injected into the SwiftUI
    /// environment so the windows and the Preferences scene share one store.
    public let preferences = AppDelegate.makePreferences()

    /// The app's secure, Keychain-backed API keys, injected into the SwiftUI
    /// environment so the windows and the Preferences scene share one store.
    public let apiKeyStore = APIKeyStore()

    /// Whether a Finder/Dock open already delivered files, so the launch panel
    /// is not presented on top of a window that is opening.
    private var didOpenFilesAtLaunch = false

    /// How long after launch the automatic, silent update check runs, in
    /// seconds. The short delay keeps the check off the critical launch path so
    /// it never competes with presenting the first window.
    private static let backgroundUpdateCheckDelay: TimeInterval = 5

    /// Builds the preferences store.
    ///
    /// Under ``isolatedPreferencesArgument`` (set by the UI-test launcher) the
    /// store is backed by private defaults suites — both the app-only store and
    /// the shared App Group store — that are wiped on launch, so a UI test run
    /// neither reads from nor writes to the real user preferences (including the
    /// shared per-format preview toggles). Otherwise the standard user defaults
    /// and the real App Group suite are used.
    ///
    /// - Returns: The preferences store to use for this launch.
    private static func makePreferences() -> Preferences
    {
        #if DEBUG

            if ProcessInfo.processInfo.arguments.contains( Self.isolatedPreferencesArgument )
            {
                let suiteName       = "com.xs-labs.FITScope.uitests"
                let sharedSuiteName = "com.xs-labs.FITScope.uitests.shared"
                let defaults        = UserDefaults( suiteName: suiteName ) ?? .standard
                let sharedDefaults  = UserDefaults( suiteName: sharedSuiteName ) ?? defaults

                defaults.removePersistentDomain( forName: suiteName )
                sharedDefaults.removePersistentDomain( forName: sharedSuiteName )

                return Preferences( defaults: defaults, sharedDefaults: sharedDefaults )
            }

        #endif

        return Preferences()
    }

    #if DEBUG

        /// Whether the app is hosting a test bundle. When tests run, the app must
        /// not present the modal Open panel at launch: it would block the main
        /// thread before the test runner can begin executing tests.
        ///
        /// Test-only, so it is compiled out of a release build entirely.
        private var isRunningTests: Bool
        {
            let environment = ProcessInfo.processInfo.environment

            return environment[ "XCTestConfigurationFilePath" ] != nil
                || environment[ "XCTestBundlePath" ]            != nil
                || NSClassFromString( "XCTestCase" )            != nil
        }

        /// Resolves the fixture a UI-test launch asked the app to open.
        ///
        /// Returns `nil` unless the launch is an isolated-defaults UI-test run carrying
        /// ``uiTestingOpenFixtureArgument`` with an existing file path. Test-only, so it
        /// is compiled out of a release build entirely.
        ///
        /// - Returns: The fixture URL to open, or `nil`.
        private static func uiTestingFixtureURLToOpen() -> URL?
        {
            let arguments = ProcessInfo.processInfo.arguments

            guard arguments.contains( Self.isolatedPreferencesArgument ),
                  let flagIndex = arguments.firstIndex( of: Self.uiTestingOpenFixtureArgument )
            else
            {
                return nil
            }

            let valueIndex = arguments.index( after: flagIndex )

            guard valueIndex < arguments.endIndex
            else
            {
                return nil
            }

            let url = URL( fileURLWithPath: arguments[ valueIndex ] )

            return FileManager.default.fileExists( atPath: url.path ) ? url : nil
        }

    #endif

    /// On launch with no file arguments, present the Open panel; chosen files
    /// open in a new window, Cancel leaves no window.
    public func applicationDidFinishLaunching( _ notification: Notification )
    {
        #if DEBUG

            if let uiTestingFixture = Self.uiTestingFixtureURLToOpen()
            {
                // A UI-test launch asked us to open a fixture directly — the fast
                // path that avoids the system Open panel. Mark the launch as having
                // opened files so the panel below is suppressed, then route it
                // through the normal open path once the scene has wired up its
                // window-opening handler.
                self.didOpenFilesAtLaunch = true

                DispatchQueue.main.async
                {
                    self.appModel.openIntoActiveWindowOrNew( urls: [ uiTestingFixture ] )
                }

                return
            }

            // When hosting a test bundle, do not present the modal Open panel at
            // launch: it would block the main thread before the test runner can
            // begin executing tests.
            guard self.isRunningTests == false
            else
            {
                return
            }

        #endif

        DispatchQueue.main.asyncAfter( deadline: .now() + Self.backgroundUpdateCheckDelay )
        {
            AppUpdater().checkForUpdatesInBackground()
        }

        DispatchQueue.main.async
        {
            guard self.didOpenFilesAtLaunch == false
            else
            {
                return
            }

            let urls = self.appModel.runOpenPanel()

            if urls.isEmpty == false
            {
                self.appModel.openWindowWithURLs?( urls )
            }
        }
    }

    /// Removes the temporary images handed to external applications by the "Open
    /// Rendered Image With" menu, so the last one does not outlive the app (see
    /// ``ExternalImageFile/removeTemporaryFiles(in:)``).
    public func applicationWillTerminate( _ notification: Notification )
    {
        ExternalImageFile.removeTemporaryFiles()
    }

    /// Finder double-click / drop-on-Dock: open the files in the active window
    /// or a new one.
    public func application( _ application: NSApplication, open urls: [ URL ] )
    {
        self.didOpenFilesAtLaunch = true

        self.appModel.openIntoActiveWindowOrNew( urls: urls )
    }

    /// Do not auto-create an untitled window when reopened with no windows.
    public func applicationShouldHandleReopen( _ sender: NSApplication, hasVisibleWindows flag: Bool ) -> Bool
    {
        flag
    }

    /// Re-surfaces a modal panel when the app is reactivated.
    ///
    /// The Open and Save panels run app-modal via `runModal()`. If the app is
    /// sent to the background — or the user switches to another Space — while a
    /// panel is up, returning to the app can otherwise leave the panel buried
    /// behind other windows or stranded on the Space it was opened on, where it
    /// is unreachable. Whenever the app becomes active with a modal window
    /// showing, bring that window forward and let it follow the user to the
    /// active Space. This is generic: it covers any modal window, not just the
    /// Open panel.
    public func applicationDidBecomeActive( _ notification: Notification )
    {
        guard let modalWindow = NSApp.modalWindow
        else
        {
            return
        }

        Self.surface( modalWindow )
    }

    /// Brings a window to the front and lets it follow the user to whichever
    /// Space is currently active, so a reactivated app never leaves it buried or
    /// stranded on another Space.
    ///
    /// - Parameter window: The window to surface.
    public static func surface( _ window: NSWindow )
    {
        window.collectionBehavior.insert( .moveToActiveSpace )
        window.orderFrontRegardless()
    }
}
