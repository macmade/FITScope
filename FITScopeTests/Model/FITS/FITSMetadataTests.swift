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

/// Tests for ``FITSMetadata`` typed WCS / astrometry extraction.
@Suite( "FITSMetadata" )
struct FITSMetadataTests
{
    // MARK: - Raw WCS keywords (full precision, from the real corpus)

    /// The WCS reference values are read at full floating-point precision — not
    /// the lossy 6-significant-figure display string — which is why the metadata
    /// is built from typed values rather than from ``FITSImageInfo``.
    @Test
    func readsFullPrecisionWCSReferenceFromFixture() throws
    {
        let metadata = try Self.metadata( fixture: TestFixtures.monoImage )

        let crval1 = try #require( metadata.crval1 )

        // Full precision retained …
        #expect( abs( crval1 - 182.62570646887 ) < 1e-9 )
        // … and demonstrably not the %g-rounded 182.626 a display string would give.
        #expect( abs( crval1 - 182.626 ) > 1e-4 )

        #expect( try #require( metadata.crval2 ).isApproximately( 39.41233768771, tolerance: 1e-9 ) )
    }

    @Test
    func readsCDMatrixAndReferencePixelFromFixture() throws
    {
        let metadata = try Self.metadata( fixture: TestFixtures.monoImage )

        #expect( try #require( metadata.cd1_1 ).isApproximately(  2.756050e-5, tolerance: 1e-12 ) )
        #expect( try #require( metadata.cd1_2 ).isApproximately( -2.082210e-6, tolerance: 1e-12 ) )
        #expect( try #require( metadata.cd2_1 ).isApproximately( -2.080210e-6, tolerance: 1e-12 ) )
        #expect( try #require( metadata.cd2_2 ).isApproximately( -2.758710e-5, tolerance: 1e-12 ) )
        #expect( try #require( metadata.crpix1 ).isApproximately( -213.5, tolerance: 1e-9 ) )
        #expect( try #require( metadata.crpix2 ).isApproximately( -204.0, tolerance: 1e-9 ) )
    }

    @Test
    func readsAxisTypesFromFixture() throws
    {
        let metadata = try Self.metadata( fixture: TestFixtures.monoImage )

        #expect( metadata.ctype1 == "RA---TAN" )
        #expect( metadata.ctype2 == "DEC--TAN" )
    }

    @Test
    func absentKeywordsAreNil() throws
    {
        let metadata = Self.metadata( [ ( "NAXIS", .integer( 2 ) ) ] )

        #expect( metadata.crval1         == nil )
        #expect( metadata.focalLength    == nil )
        #expect( metadata.observationDate == nil )
        #expect( metadata.pixelScale     == nil )
        #expect( metadata.rightAscension == nil )
    }

    /// A real observing site (`SITELAT`/`SITELONG`) resolves to a coordinate, while an
    /// all-zero pair is the "no fix" sentinel and yields no location.
    @Test
    func observingSiteCoordinateRejectsZeroPair() throws
    {
        let site = Self.metadata( [ ( "SITELAT", .float( 45.5 ) ), ( "SITELONG", .float( -73.6 ) ) ] )
        let zero = Self.metadata( [ ( "SITELAT", .float( 0 ) ),    ( "SITELONG", .float( 0 ) ) ] )

        #expect( site.coordinate == Coordinate( latitude: 45.5, longitude: -73.6 ) )
        #expect( zero.coordinate == nil )
    }

    @Test
    func firstOccurrenceOfADuplicateKeywordWins() throws
    {
        let metadata = Self.metadata(
            [
                ( "FOCALLEN", .float( 530 ) ),
                ( "FOCALLEN", .float( 999 ) ),
            ]
        )

        #expect( metadata.focalLength == 530 )
    }

    // MARK: - Right ascension (degrees)

    /// `CRVAL1` is in decimal degrees and is the preferred RA source.
    @Test
    func rightAscensionFromCRVAL1IsDegrees() throws
    {
        let metadata = Self.metadata( [ ( "CRVAL1", .float( 182.625 ) ) ] )

        #expect( try #require( metadata.rightAscension ).isApproximately( 182.625, tolerance: 1e-9 ) )
    }

    /// `OBJCTRA` is conventionally sexagesimal *hours*; 12h30m00s = 187.5°.
    @Test
    func rightAscensionFromObjctraIsSexagesimalHours() throws
    {
        let metadata = Self.metadata( [ ( "OBJCTRA", .string( "12 30 00" ) ) ] )

        #expect( try #require( metadata.rightAscension ).isApproximately( 187.5, tolerance: 1e-9 ) )
    }

    @Test
    func rightAscensionAcceptsColonSeparatedHours() throws
    {
        let metadata = Self.metadata( [ ( "OBJCTRA", .string( "12:30:00" ) ) ] )

        #expect( try #require( metadata.rightAscension ).isApproximately( 187.5, tolerance: 1e-9 ) )
    }

    // MARK: - Declination (degrees)

    @Test
    func declinationFromCRVAL2IsDegrees() throws
    {
        let metadata = Self.metadata( [ ( "CRVAL2", .float( 39.4123 ) ) ] )

        #expect( try #require( metadata.declination ).isApproximately( 39.4123, tolerance: 1e-9 ) )
    }

    /// `OBJCTDEC` is sexagesimal *degrees*, sign-aware; -12°30'00" = -12.5°.
    @Test
    func declinationFromObjctdecIsSignedSexagesimalDegrees() throws
    {
        let metadata = Self.metadata( [ ( "OBJCTDEC", .string( "-12 30 00" ) ) ] )

        #expect( try #require( metadata.declination ).isApproximately( -12.5, tolerance: 1e-9 ) )
    }

    // MARK: - Observation date

    @Test
    func parsesDateObsWithFractionalSeconds() throws
    {
        let metadata = Self.metadata( [ ( "DATE-OBS", .string( "2026-01-15T22:30:45.500" ) ) ] )

        let date          = try #require( metadata.observationDate )
        var calendar      = Calendar( identifier: .gregorian )
        calendar.timeZone = try #require( TimeZone( identifier: "UTC" ) )
        let components    = calendar.dateComponents( [ .year, .month, .day, .hour, .minute, .second ], from: date )

        #expect( components.year   == 2026 )
        #expect( components.month  == 1 )
        #expect( components.day    == 15 )
        #expect( components.hour   == 22 )
        #expect( components.minute == 30 )
        #expect( components.second == 45 )
    }

    @Test
    func parsesDateObsWithoutFractionalSeconds() throws
    {
        let metadata = Self.metadata( [ ( "DATE-OBS", .string( "2026-01-15T22:30:45" ) ) ] )

        #expect( metadata.observationDate != nil )
    }

    // MARK: - GPS

    @Test
    func readsGPSCoordinatesAndElevation() throws
    {
        let metadata = Self.metadata(
            [
                ( "SITELAT",  .string( "46 12 00" ) ),
                ( "SITELONG", .string( "-6 09 00" ) ),
                ( "SITEELEV", .float( 410 ) ),
            ]
        )

        #expect( try #require( metadata.latitude  ).isApproximately(  46.2, tolerance: 1e-9 ) )
        #expect( try #require( metadata.longitude ).isApproximately( -6.15, tolerance: 1e-9 ) )
        #expect( metadata.elevation == 410 )
    }

    /// The combined coordinate is present only when both the latitude and the
    /// longitude are available, carrying each through unchanged.
    @Test
    func coordinateCombinesLatitudeAndLongitude() throws
    {
        let metadata = Self.metadata(
            [
                ( "SITELAT",  .string( "46 12 00" ) ),
                ( "SITELONG", .string( "-6 09 00" ) ),
            ]
        )

        let coordinate = try #require( metadata.coordinate )

        #expect( coordinate.latitude.isApproximately(  46.2, tolerance: 1e-9 ) )
        #expect( coordinate.longitude.isApproximately( -6.15, tolerance: 1e-9 ) )
    }

    /// With no longitude there is no coordinate, even when a latitude is present.
    @Test
    func coordinateIsNilWhenLongitudeMissing()
    {
        let metadata = Self.metadata( [ ( "SITELAT", .float( 46.2 ) ) ] )

        #expect( metadata.coordinate == nil )
    }

    /// With no latitude there is no coordinate, even when a longitude is present.
    @Test
    func coordinateIsNilWhenLatitudeMissing()
    {
        let metadata = Self.metadata( [ ( "SITELONG", .float( -6.15 ) ) ] )

        #expect( metadata.coordinate == nil )
    }

    /// With neither coordinate keyword there is no coordinate.
    @Test
    func coordinateIsNilWhenBothMissing()
    {
        let metadata = Self.metadata( [ ( "NAXIS", .integer( 2 ) ) ] )

        #expect( metadata.coordinate == nil )
    }

    // MARK: - Focal length

    @Test
    func readsFocalLength() throws
    {
        let metadata = Self.metadata( [ ( "FOCALLEN", .float( 530 ) ) ] )

        #expect( metadata.focalLength == 530 )
    }

    // MARK: - Pixel scale (arcsec / pixel)

    /// `CDELT2` is in degrees/pixel; 0.0005°/px = 1.8″/px.
    @Test
    func pixelScaleFromCDELT() throws
    {
        let metadata = Self.metadata(
            [
                ( "CDELT1", .float( 0.0005 ) ),
                ( "CDELT2", .float( 0.0005 ) ),
            ]
        )

        #expect( try #require( metadata.pixelScale ).isApproximately( 1.8, tolerance: 1e-6 ) )
    }

    /// With no CDELT, the scale comes from the CD matrix:
    /// √(CD1_1² + CD2_1²) · 3600.
    @Test
    func pixelScaleFromCDMatrix() throws
    {
        let metadata = try Self.metadata( fixture: TestFixtures.monoImage )

        let expected = ( ( 2.756050e-5 * 2.756050e-5 ) + ( 2.080210e-6 * 2.080210e-6 ) ).squareRoot() * 3600

        #expect( try #require( metadata.pixelScale ).isApproximately( expected, tolerance: 1e-9 ) )
    }

    /// With neither CDELT nor a CD matrix, the scale is derived from the focal
    /// length and the sensor pixel size: 206.265 · pixelSize(µm) / focalLength(mm).
    @Test
    func pixelScaleFromFocalLengthAndPixelSize() throws
    {
        let metadata = Self.metadata(
            [
                ( "FOCALLEN", .float( 530 ) ),
                ( "XPIXSZ",   .float( 3.76 ) ),
            ]
        )

        let expected = 206.265 * 3.76 / 530

        #expect( try #require( metadata.pixelScale ).isApproximately( expected, tolerance: 1e-6 ) )
    }

    // MARK: - Sampling classification

    /// Below the 0.67″/px lower bound the image is over-sampled; the bound itself
    /// is inside the well-sampled band.
    @Test
    func samplingClassifiesOverSampledBelowTheLowerBound()
    {
        #expect( FITSMetadata.Sampling( pixelScale: 0.50 ) == .overSampled )
        #expect( FITSMetadata.Sampling( pixelScale: 0.66 ) == .overSampled )
        #expect( FITSMetadata.Sampling( pixelScale: 0.67 ) == .wellSampled )
    }

    /// Between 0.67″/px and 2.0″/px, inclusive, the image is well sampled.
    @Test
    func samplingClassifiesWellSampledWithinTheBand()
    {
        #expect( FITSMetadata.Sampling( pixelScale: 0.67 ) == .wellSampled )
        #expect( FITSMetadata.Sampling( pixelScale: 1.50 ) == .wellSampled )
        #expect( FITSMetadata.Sampling( pixelScale: 2.00 ) == .wellSampled )
    }

    /// Above the 2.0″/px upper bound the image is under-sampled; the bound itself
    /// is inside the well-sampled band.
    @Test
    func samplingClassifiesUnderSampledAboveTheUpperBound()
    {
        #expect( FITSMetadata.Sampling( pixelScale: 2.00 ) == .wellSampled )
        #expect( FITSMetadata.Sampling( pixelScale: 2.01 ) == .underSampled )
        #expect( FITSMetadata.Sampling( pixelScale: 3.60 ) == .underSampled )
    }

    /// With no derivable pixel scale there is no sampling classification.
    @Test
    func samplingIsNilWhenPixelScaleUnavailable()
    {
        let metadata = Self.metadata( [ ( "NAXIS", .integer( 2 ) ) ] )

        #expect( metadata.sampling == nil )
    }

    /// The classification follows the derived pixel scale — 0.0005°/px = 1.8″/px,
    /// which is well sampled.
    @Test
    func samplingFollowsTheDerivedPixelScale()
    {
        let metadata = Self.metadata( [ ( "CDELT2", .float( 0.0005 ) ) ] )

        #expect( metadata.sampling == .wellSampled )
    }

    // MARK: - Helpers

    /// Builds metadata from an explicit list of typed keyword snapshots.
    private static func metadata( _ keywords: [ ( String, FITSValue ) ] ) -> FITSMetadata
    {
        FITSMetadata( properties: keywords.map { FITSPropertySnapshot( name: $0.0, value: $0.1 ) } )
    }

    /// Builds metadata from a fixture file, flattening every section's typed
    /// header properties — mirroring how the app derives the snapshot.
    private static func metadata( fixture url: URL ) throws -> FITSMetadata
    {
        let file       = try FITSFile( url: url, options: .lenient )
        let properties = file.sections.flatMap
        {
            $0.properties.map { FITSPropertySnapshot( name: $0.name, value: $0.value ) }
        }

        return FITSMetadata( properties: properties )
    }
}

private extension Double
{
    /// Whether the value is within `tolerance` of `other`, for floating-point
    /// comparisons in expectations.
    func isApproximately( _ other: Double, tolerance: Double ) -> Bool
    {
        abs( self - other ) <= tolerance
    }
}
