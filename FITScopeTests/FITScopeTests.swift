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
/// expectation declared for it in `FITSCorpus`.
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

    /// Every corpus file produces the outcome declared for it in `FITSCorpus`.
    @Test( arguments: FITSCorpus.files )
    @MainActor
    func corpusOutcomeMatchesExpectation( file: FITSCorpus.File ) async throws
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

    /// A minimal header-only FITS file (`NAXIS=0`, single section) must surface
    /// a clean, typed error and never trap: with a single section there is no
    /// data section to render, and the selection must not index a fixed
    /// position.
    @Test
    @MainActor
    func headerOnlyFileErrorsCleanly() async throws
    {
        let data = Self.headerOnlyFITSData()
        let file = try FITSFile( data: data, options: .lenient )

        // The file that used to trap: a single header section, no data section.
        try #require( file.sections.count == 1 )

        let renderer = FITSImageRenderer( file: file )

        await renderer.render()

        #expect( renderer.result == nil, "header-only input should not render" )

        let message = renderer.error.map { "\( $0 )" } ?? ""

        #expect( message.contains( "no image HDU" ), "expected a typed no-image-HDU error, got: \"\( message )\"" )
    }

    /// Synthesises a minimal, valid header-only FITS file
    /// (`SIMPLE=T / BITPIX=8 / NAXIS=0 / END`) as a single space-padded block.
    private static func headerOnlyFITSData() -> Data
    {
        let records =
        [
            "SIMPLE  = T",
            "BITPIX  = 8",
            "NAXIS   = 0",
            "END",
        ]
        let header = records.map { $0.padding( toLength: 80, withPad: " ", startingAt: 0 ) }.joined()

        return Data( header.padding( toLength: FITSFile.blockSize, withPad: " ", startingAt: 0 ).utf8 )
    }
}
