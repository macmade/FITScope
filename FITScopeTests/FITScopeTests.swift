/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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

import Foundation
import SwiftFITS
import Testing
@testable import FITScope

/// End-to-end render test over the bundled FITS corpus.
///
/// Each corpus file is run through the same load → parse → render path the app
/// uses (`FITSImageRenderer.render()`), and the outcome is checked against the
/// documented baseline in `FITSCorpus`. This suite is the running scoreboard
/// the remediation milestones edit: today only the M42 file renders, and each
/// fix flips more entries from `.fails(...)` to `.renders`.
@Suite( "FITS corpus render baseline" )
struct FITScopeTests
{
    /// The corpus must be present on disk; fail loudly if it is missing.
    @Test
    func corpusIsPresent() throws
    {
        let directory = FITSCorpus.directory

        #expect( FileManager.default.fileExists( atPath: directory.path ), "Corpus directory is missing at \( directory.path )" )

        for file in FITSCorpus.files
        {
            #expect( FileManager.default.fileExists( atPath: file.url.path ), "Missing corpus file: \( file.url.path )" )
        }
    }

    /// Every corpus file produces the outcome documented in the baseline.
    @Test( arguments: FITSCorpus.files )
    @MainActor
    func corpusOutcomeMatchesBaseline( file: FITSCorpus.File ) async throws
    {
        let data     = try Data( contentsOf: file.url )
        let fitsFile = try FITSFile( data: data, options: .lenient )
        let renderer = FITSImageRenderer( file: fitsFile )

        await renderer.render()

        switch file.expectation
        {
            case .renders:
                #expect( renderer.result != nil, "\( file.label ) should render to an image" )
                #expect( renderer.error  == nil, "\( file.label ) should not produce an error, got: \( String( describing: renderer.error ) )" )

            case .fails( let reason ):
                #expect( renderer.result == nil, "\( file.label ) should not render" )

                let message = renderer.error.map { "\( $0 )" } ?? ""

                #expect( message.contains( reason.currentMessageSubstring ), "\( file.label ): expected an error containing \"\( reason.currentMessageSubstring )\", got: \"\( message )\"" )
        }
    }

    /// Deferred (C-2): a minimal header-only FITS file (`NAXIS=0`, single
    /// section) currently *crashes* the app because `FITSImageRenderer` hard
    /// indexes `sections[1]`. This cannot be asserted as a clean error until
    /// M2 replaces the positional index with kind-based selection — running it
    /// today would trap and abort the whole test process. M2 enables this and
    /// replaces it with a real typed-error assertion.
    @Test( .disabled( "C-2: header-only input traps on sections[1]; enable in M2" ) )
    func headerOnlyFileErrorsCleanly() throws
    {
        Issue.record( "Pending M2: header-only FITS should surface a typed \"no image HDU\" error instead of crashing." )
    }
}
