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

import SwiftUtilities

/// A thin coordinator that wires the application's *Check for Updates* command
/// to SwiftUtilities' ``GitHubUpdater``.
///
/// It pins the updater to FITScope's GitHub repository and, when invoked,
/// checks the repository's releases and reports every outcome to the user
/// (up-to-date, an available update, or a failure). The repository can be
/// overridden through the initializer, which is the dependency-injection seam
/// for tests.
struct AppUpdater
{
    /// The default repository owner: the FITScope GitHub account.
    static let defaultOwner = "macmade"

    /// The default repository name: FITScope.
    static let defaultRepository = "FITScope"

    /// The owner (user or organization) of the repository checked for releases.
    let owner: String

    /// The name of the repository checked for releases.
    let repository: String

    /// Creates an updater for the given repository, defaulting to FITScope's.
    ///
    /// - Parameters:
    ///   - owner:      The repository owner. Defaults to ``defaultOwner``.
    ///   - repository: The repository name. Defaults to ``defaultRepository``.
    init( owner: String = AppUpdater.defaultOwner, repository: String = AppUpdater.defaultRepository )
    {
        self.owner      = owner
        self.repository = repository
    }

    /// Builds the underlying ``GitHubUpdater`` for the configured repository.
    ///
    /// The running application's name and version are read from its `Info.plist`,
    /// and releases are fetched through the shared `URLSession`.
    ///
    /// - Returns: The updater, or `nil` if a valid releases URL cannot be built
    ///            from the configured owner and repository.
    func makeUpdater() -> GitHubUpdater?
    {
        GitHubUpdater( owner: self.owner, repository: self.repository )
    }

    /// Checks for updates, reporting every outcome to the user.
    ///
    /// Runs the check through ``GitHubUpdater/checkForUpdates()``, which presents
    /// a modal alert whether the application is up-to-date, an update is
    /// available, or the check failed. Does nothing if the updater cannot be
    /// built.
    @MainActor
    func checkForUpdates()
    {
        self.makeUpdater()?.checkForUpdates()
    }

    /// Checks for updates silently, alerting the user only when a newer version
    /// is available.
    ///
    /// Runs the check through ``GitHubUpdater/checkForUpdatesInBackground()``,
    /// which stays quiet when the application is up-to-date or the check fails.
    /// Suited to an automatic launch-time check that must not interrupt the user
    /// on every run. Does nothing if the updater cannot be built.
    @MainActor
    func checkForUpdatesInBackground()
    {
        self.makeUpdater()?.checkForUpdatesInBackground()
    }
}
