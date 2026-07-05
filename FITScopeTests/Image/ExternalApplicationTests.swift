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

/// Tests for `ExternalApplication`: it derives an application's display name
/// from its bundle URL, and its `applications(from:)` builder turns the raw
/// `NSWorkspace` output into a de-duplicated, name-sorted list.
@Suite( "ExternalApplication" )
struct ExternalApplicationTests
{
    @Test
    func derivesNameFromApplicationBundleURL()
    {
        let application = ExternalApplication( applicationURL: URL( fileURLWithPath: "/Applications/Preview.app" ) )

        #expect( application.name == "Preview" )
        #expect( application.url == URL( fileURLWithPath: "/Applications/Preview.app" ) )
    }

    @Test
    func buildsASortedDeduplicatedList()
    {
        let urls =
            [
                URL( fileURLWithPath: "/Applications/Preview.app" ),
                URL( fileURLWithPath: "/Applications/Photos.app" ),
                URL( fileURLWithPath: "/Applications/Preview.app" ),
            ]

        let applications = ExternalApplication.applications( from: urls )

        #expect( applications.map { $0.name } == [ "Photos", "Preview" ], "duplicates are removed and the rest are sorted by name" )
    }

    @Test
    func sortsCaseInsensitively()
    {
        let urls =
            [
                URL( fileURLWithPath: "/Applications/Photos.app" ),
                URL( fileURLWithPath: "/Applications/acorn.app" ),
            ]

        let applications = ExternalApplication.applications( from: urls )

        #expect( applications.map { $0.name } == [ "acorn", "Photos" ], "the sort ignores case, so \u{201C}acorn\u{201D} precedes \u{201C}Photos\u{201D}" )
    }

    @Test
    func excludesTheGivenApplication()
    {
        let urls =
            [
                URL( fileURLWithPath: "/Applications/FITScope.app" ),
                URL( fileURLWithPath: "/Applications/Preview.app" ),
            ]

        let applications = ExternalApplication.applications( from: urls, excluding: URL( fileURLWithPath: "/Applications/FITScope.app" ) )

        #expect( applications.map { $0.name } == [ "Preview" ], "the excluded application (the running app) is dropped from the list" )
    }

    @Test
    func emptyInputYieldsNoApplications()
    {
        #expect( ExternalApplication.applications( from: [] ).isEmpty )
    }

    @Test
    func theURLIsTheStableIdentity()
    {
        let application = ExternalApplication( applicationURL: URL( fileURLWithPath: "/Applications/Preview.app" ) )

        #expect( application.id == application.url )
    }
}
