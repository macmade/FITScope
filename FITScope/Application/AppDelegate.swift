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

    /// The launch argument that makes the app back its preferences with an
    /// isolated, wiped-on-launch defaults suite, so UI tests never read or mutate
    /// the real user preferences.
    public static let isolatedPreferencesArgument = "-uiTestingIsolatedDefaults"

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
    /// store is backed by a private defaults suite that is wiped on launch, so a
    /// UI test run neither reads from nor writes to the real user preferences.
    /// Otherwise the standard user defaults are used.
    ///
    /// - Returns: The preferences store to use for this launch.
    private static func makePreferences() -> Preferences
    {
        guard ProcessInfo.processInfo.arguments.contains( Self.isolatedPreferencesArgument )
        else
        {
            return Preferences()
        }

        let suiteName = "com.xs-labs.FITScope.uitests"
        let defaults  = UserDefaults( suiteName: suiteName ) ?? .standard

        defaults.removePersistentDomain( forName: suiteName )

        return Preferences( defaults: defaults )
    }

    /// Whether the app is hosting a test bundle. When tests run, the app must
    /// not present the modal Open panel at launch: it would block the main
    /// thread before the test runner can begin executing tests.
    private var isRunningTests: Bool
    {
        let environment = ProcessInfo.processInfo.environment

        return environment[ "XCTestConfigurationFilePath" ] != nil
            || environment[ "XCTestBundlePath" ]            != nil
            || NSClassFromString( "XCTestCase" )            != nil
    }

    /// On launch with no file arguments, present the Open panel; chosen files
    /// open in a new window, Cancel leaves no window.
    public func applicationDidFinishLaunching( _ notification: Notification )
    {
        guard self.isRunningTests == false
        else
        {
            return
        }

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
}
