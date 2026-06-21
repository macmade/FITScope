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
import SwiftFITS
import Testing

/// Tests for `ImageInformation` keyword extraction.
@Suite( "ImageInformation" )
struct ImageInformationTests
{
    @Test
    func extractsCoreFieldsFromFixture() throws
    {
        let url  = TestFixtures.renderableImage
        let file = try FITSFile( url: url, options: .lenient )
        let info = FITSImageInfo( url: url, file: file )

        let summary = try #require( ImageInformation( info: info ) )

        #expect( summary.dimensions.contains( "×" ), "dimensions read NAXIS1 × NAXIS2" )
        #expect( summary.bitDepth.contains( "bit" ), "bit depth reads BITPIX" )
        #expect( summary.channels.isEmpty == false )
    }

    @Test
    func returnsNilWhenGeometryKeywordsMissing() throws
    {
        let url  = URL( fileURLWithPath: "/tmp/none.fits" )
        let info = FITSImageInfo( url: url, sections: [] )

        #expect( ImageInformation( info: info ) == nil )
    }

    @Test
    func absentFieldsAreOmittedFromRows() throws
    {
        let url  = TestFixtures.renderableImage
        let file = try FITSFile( url: url, options: .lenient )
        let info = FITSImageInfo( url: url, file: file )

        let summary = try #require( ImageInformation( info: info ) )

        // Every emitted row must have a non-empty value (no "—" placeholders).
        #expect( summary.rows.allSatisfy { $0.value.isEmpty == false } )
        // Core geometry is always present.
        #expect( summary.rows.contains { $0.label == "Dimensions" } )
    }
}
