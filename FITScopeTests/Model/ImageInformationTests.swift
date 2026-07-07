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
        let url  = TestFixtures.monoImage
        let file = try FITSFile( url: url, options: .lenient )
        let info = FITSImageInfo( url: url, file: file )

        let summary = try #require( ImageInformation( fitsMetadata: info.imageMetadata ) )

        #expect( summary.dimensions.contains( "×" ), "dimensions read NAXIS1 × NAXIS2" )
        #expect( summary.bitDepth.contains( "bit" ), "bit depth reads BITPIX" )
        #expect( summary.channels.isEmpty == false )
    }

    @Test
    func colorFilterArrayImageIsDetected() throws
    {
        let url  = TestFixtures.colorImage
        let file = try FITSFile( url: url, options: .lenient )
        let info = FITSImageInfo( url: url, file: file )

        #expect( info.isColorFilterArray, "a file with a BAYERPAT keyword is a colour-filter-array image" )
    }

    @Test
    func monochromeImageIsNotColorFilterArray() throws
    {
        let url  = TestFixtures.monoImage
        let file = try FITSFile( url: url, options: .lenient )
        let info = FITSImageInfo( url: url, file: file )

        #expect( info.isColorFilterArray == false, "a file with no BAYERPAT keyword is not a colour-filter-array image" )
    }

    @Test
    func returnsNilWhenGeometryKeywordsMissing() throws
    {
        let url  = URL( fileURLWithPath: "/tmp/none.fits" )
        let info = FITSImageInfo( url: url, sections: [] )

        #expect( ImageInformation( fitsMetadata: info.imageMetadata ) == nil )
    }

    @Test
    func pixelScaleIsDerivedFromHeaderGeometry() throws
    {
        let url  = TestFixtures.monoImage
        let file = try FITSFile( url: url, options: .lenient )
        let info = FITSImageInfo( url: url, file: file )

        let scale = try #require( info.pixelScale, "a file with a WCS / CD matrix yields a pixel scale" )

        #expect( scale > 0 )
    }

    @Test
    func pixelScaleIsNilWithoutGeometry() throws
    {
        let url  = URL( fileURLWithPath: "/tmp/none.fits" )
        let info = FITSImageInfo( url: url, sections: [] )

        #expect( info.pixelScale == nil )
    }

    @Test
    func absentFieldsAreOmittedFromRows() throws
    {
        let url  = TestFixtures.monoImage
        let file = try FITSFile( url: url, options: .lenient )
        let info = FITSImageInfo( url: url, file: file )

        let summary = try #require( ImageInformation( fitsMetadata: info.imageMetadata ) )

        // Every emitted row must have a non-empty value (no "—" placeholders).
        #expect( summary.rows.allSatisfy { $0.value.isEmpty == false } )
        // Core geometry is always present.
        #expect( summary.rows.contains { $0.label == "Dimensions" } )
    }

    /// `rows(for:)` returns rows in exactly the requested field order, not the
    /// canonical one.
    @Test
    func rowsFollowTheRequestedFieldOrder() throws
    {
        let summary = try #require( ImageInformation( fitsMetadata: Self.makeInfo().imageMetadata ) )

        let rows = summary.rows( for: [ .channels, .dimensions, .bitDepth ] )

        #expect( rows.map { $0.label } == [ "Channels", "Dimensions", "Bit Depth" ] )
    }

    /// `rows(for:)` includes only the requested fields — a field absent from the
    /// list is not emitted even though its value is available.
    @Test
    func rowsOmitFieldsNotRequested() throws
    {
        let summary = try #require( ImageInformation( fitsMetadata: Self.makeInfo().imageMetadata ) )

        let rows = summary.rows( for: [ .dimensions ] )

        #expect( rows.map { $0.label } == [ "Dimensions" ] )
    }

    /// A requested field whose keyword is absent from the file is still omitted:
    /// the panel never shows empty placeholders.
    @Test
    func rowsOmitRequestedButAbsentFields() throws
    {
        // Geometry only — no OBJECT or FILTER keyword.
        let summary = try #require( ImageInformation( fitsMetadata: Self.makeInfo().imageMetadata ) )

        let rows = summary.rows( for: [ .object, .dimensions, .filter ] )

        #expect( rows.map { $0.label } == [ "Dimensions" ] )
    }

    /// A requested field whose keyword is present is emitted with its value.
    @Test
    func rowsIncludeRequestedPresentFields() throws
    {
        let info    = try Self.makeInfo( keywords: [ ( "OBJECT", "'M31'" ), ( "EXPTIME", "30" ) ] )
        let summary = try #require( ImageInformation( fitsMetadata: info.imageMetadata ) )

        let rows = summary.rows( for: [ .object, .exposure ] )

        #expect( rows == [ .init( field: .object, value: "M31" ), .init( field: .exposure, value: "30 s" ) ] )
    }

    /// The sampling row pairs the computed pixel scale with its classification —
    /// `CDELT2 = 0.0005°/px` is 1.80″/px, which is well sampled.
    @Test
    func samplingRowShowsScaleAndClassification() throws
    {
        let info    = try Self.makeInfo( keywords: [ ( "CDELT2", "0.0005" ) ] )
        let summary = try #require( ImageInformation( fitsMetadata: info.imageMetadata ) )

        let rows = summary.rows( for: [ .sampling ] )

        #expect( rows == [ .init( field: .sampling, value: "1.80″/px · Well sampled" ) ] )
    }

    /// With no derivable pixel scale, the sampling row is omitted — the panel
    /// never shows an empty placeholder.
    @Test
    func samplingRowIsOmittedWhenPixelScaleUnavailable() throws
    {
        let summary = try #require( ImageInformation( fitsMetadata: Self.makeInfo().imageMetadata ) )

        #expect( summary.rows( for: [ .sampling ] ).isEmpty )
    }

    /// An injected additional value (e.g. the computed weight, which is not a
    /// header keyword) is emitted as its field's row, in the requested order.
    @Test
    func rowsIncludeInjectedAdditionalValues() throws
    {
        let summary = try #require( ImageInformation( fitsMetadata: Self.makeInfo().imageMetadata ) )

        let rows = summary.rows( for: [ .dimensions, .weight ], additionalValues: [ .weight: "75.0" ] )

        #expect( rows.map { $0.field } == [ .dimensions, .weight ] )
        #expect( rows.first { $0.field == .weight }?.value == "75.0" )
    }

    /// A field with neither a header value nor an injected value is still omitted.
    @Test
    func rowsOmitAFieldWithoutHeaderOrInjectedValue() throws
    {
        let summary = try #require( ImageInformation( fitsMetadata: Self.makeInfo().imageMetadata ) )

        let rows = summary.rows( for: [ .dimensions, .weight ] )

        #expect( rows.map { $0.field } == [ .dimensions ] )
    }

    /// Builds a controlled, in-memory `FITSImageInfo` with a valid 4×4 geometry
    /// and any extra header keywords, so row tests don't depend on the contents
    /// of a bundled fixture.
    ///
    /// - Parameter keywords: Extra `(name, FITS-formatted value)` records to add
    ///   after the mandatory geometry keywords. String values must be quoted,
    ///   e.g. `( "OBJECT", "'M31'" )`.
    private static func makeInfo( keywords: [ ( String, String ) ] = [] ) throws -> FITSImageInfo
    {
        var records =
            [
                "SIMPLE  = T",
                "BITPIX  = 8",
                "NAXIS   = 2",
                "NAXIS1  = 4",
                "NAXIS2  = 4",
            ]

        records += keywords.map { "\( $0.0.padding( toLength: 8, withPad: " ", startingAt: 0 ) )= \( $0.1 )" }
        records.append( "END" )

        let header = records.map { $0.padding( toLength: 80, withPad: " ", startingAt: 0 ) }.joined()
        var data   = Data( header.padding( toLength: FITSFile.blockSize, withPad: " ", startingAt: 0 ).utf8 )

        data.append( Data( count: FITSFile.blockSize ) ) // 4×4 bytes fit in one data block.

        let file = try FITSFile( data: data, options: .lenient )

        return FITSImageInfo( url: URL( fileURLWithPath: "/tmp/test.fits" ), file: file )
    }
}
