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

/// Tests for `AppUpdater`: that it defaults to the FITScope GitHub repository
/// and builds a `GitHubUpdater` pointed at that repository's releases endpoint.
@Suite( "AppUpdater" )
struct AppUpdaterTests
{
    @Test
    func defaultsToTheFITScopeRepository()
    {
        let updater = AppUpdater()

        #expect( updater.owner == "macmade", "the updater must default to the FITScope repository owner" )
        #expect( updater.repository == "FITScope", "the updater must default to the FITScope repository name" )
    }

    @Test
    func buildsAGitHubUpdaterForTheConfiguredRepository() throws
    {
        let updater = AppUpdater( owner: "octocat", repository: "Hello-World" )
        let github  = try #require( updater.makeUpdater(), "a valid owner/repository must yield an updater" )

        #expect( github.owner == "octocat", "the configured owner must propagate to the GitHubUpdater" )
        #expect( github.repository == "Hello-World", "the configured repository must propagate to the GitHubUpdater" )
        #expect( github.url.absoluteString == "https://api.github.com/repos/octocat/Hello-World/releases?per_page=100", "the updater must target the configured repository's releases endpoint" )
    }

    @Test
    func defaultUpdaterTargetsTheFITScopeReleasesEndpoint() throws
    {
        let github = try #require( AppUpdater().makeUpdater(), "the default updater must build" )

        #expect( github.url.absoluteString == "https://api.github.com/repos/macmade/FITScope/releases?per_page=100", "the default updater must target FITScope's releases endpoint" )
    }
}
