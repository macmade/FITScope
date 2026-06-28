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

import CoreGraphics
@testable import FITScope
import SwiftFITS
import Testing

/// Tests for ``WCSProjection``: the gnomonic (TAN) projection between sky
/// coordinates and FITScope's source-display pixel space, built from the WCS
/// reference point, reference pixel, and `CD` matrix (or the `CDELT` + `CROTA2`
/// fallback). The reference sky point maps to the reference pixel; north (rising
/// declination) maps to increasing y because FITScope shows data row 0 at the
/// top; sky and pixel round-trip; and a point on the far hemisphere has no image.
@Suite( "WCSProjection" )
struct WCSProjectionTests
{
    /// A north-up sky WCS centred at RA 10°, Dec 20°, reference pixel (100, 100),
    /// scale 3.6″/px (0.001°/px). Extra keywords can be merged or overridden.
    private static func wcs( _ overrides: [ String: Double ] = [ : ] ) -> FITSMetadata
    {
        var pairs: [ String: Double ] =
            [
                "CRVAL1": 10, "CRVAL2": 20,
                "CRPIX1": 100, "CRPIX2": 100,
                "CD1_1": -0.001, "CD1_2": 0, "CD2_1": 0, "CD2_2": 0.001,
            ]

        overrides.forEach { pairs[ $0.key ] = $0.value }

        return FITSMetadata( properties: pairs.map { FITSPropertySnapshot( name: $0.key, value: .float( $0.value ) ) } )
    }

    /// Whether two points are within a tolerance of each other.
    private static func near( _ a: CGPoint, _ b: CGPoint, tolerance: CGFloat = 0.01 ) -> Bool
    {
        abs( a.x - b.x ) <= tolerance && abs( a.y - b.y ) <= tolerance
    }

    @Test
    func isUnavailableWithoutAReferencePoint() throws
    {
        // A CD matrix alone is not enough to project: the reference sky point
        // (CRVAL) and reference pixel (CRPIX) are required.
        let metadata = FITSMetadata( properties: [ "CD1_1", "CD1_2", "CD2_1", "CD2_2" ].map { FITSPropertySnapshot( name: $0, value: .float( 0.001 ) ) } )

        #expect( WCSProjection( metadata: metadata ) == nil )
    }

    @Test
    func isUnavailableWithoutALinearTransform() throws
    {
        // A reference point with no CD matrix and no CDELT cannot project.
        let metadata = FITSMetadata( properties: [ "CRVAL1": 10.0, "CRVAL2": 20, "CRPIX1": 100, "CRPIX2": 100 ].map { FITSPropertySnapshot( name: $0.key, value: .float( $0.value ) ) } )

        #expect( WCSProjection( metadata: metadata ) == nil )
    }

    @Test
    func referenceSkyMapsToTheReferencePixel() throws
    {
        let projection = try #require( WCSProjection( metadata: Self.wcs() ) )

        // The reference sky point maps to the reference pixel, in 0-based source
        // space (CRPIX is 1-based, so subtract one).
        let point = try #require( projection.sourcePixel( ra: 10, dec: 20 ) )

        #expect( Self.near( point, CGPoint( x: 99, y: 99 ) ) )
    }

    @Test
    func risingDeclinationMapsToIncreasingY() throws
    {
        let projection = try #require( WCSProjection( metadata: Self.wcs() ) )

        // 0.01° north of the reference is 10 px at 0.001°/px. FITScope shows row 0
        // at the top, so north (rising declination) maps to *increasing* y (down),
        // consistent with the north overlay.
        let point = try #require( projection.sourcePixel( ra: 10, dec: 20.01 ) )

        #expect( abs( point.x - 99 ) <= 0.05 )
        #expect( abs( point.y - 109 ) <= 0.05 )
    }

    @Test
    func risingRightAscensionMapsToTheLeft() throws
    {
        let projection = try #require( WCSProjection( metadata: Self.wcs() ) )

        // East (rising RA) is to the left for this north-up field: a small RA
        // increase moves the pixel to a smaller x, with y essentially unchanged.
        let point = try #require( projection.sourcePixel( ra: 10.01, dec: 20 ) )

        #expect( point.x < 99 )
        #expect( abs( point.y - 99 ) <= 0.05 )
    }

    @Test
    func aPointOnTheFarHemisphereHasNoImage() throws
    {
        let projection = try #require( WCSProjection( metadata: Self.wcs() ) )

        // The antipode of the field centre is behind the projection plane: a
        // gnomonic projection cannot image it.
        #expect( projection.sourcePixel( ra: 190, dec: -20 ) == nil )
    }

    @Test
    func skyAndPixelRoundTrip() throws
    {
        let projection = try #require( WCSProjection( metadata: Self.wcs() ) )

        // Deprojecting a pixel and reprojecting the sky position returns the pixel.
        let sky   = projection.sky( forSourceX: 120, y: 130 )
        let point = try #require( projection.sourcePixel( ra: sky.ra, dec: sky.dec ) )

        #expect( Self.near( point, CGPoint( x: 120, y: 130 ), tolerance: 0.0001 ) )
    }

    @Test
    func buildsTheTransformFromCDELTAndCROTAWhenNoCDMatrix() throws
    {
        // With no CD matrix, the projection synthesises one from CDELT + CROTA2 and
        // still maps the reference sky point to the reference pixel.
        let metadata = FITSMetadata( properties: [ "CRVAL1": 10.0, "CRVAL2": 20, "CRPIX1": 100, "CRPIX2": 100, "CDELT1": -0.001, "CDELT2": 0.001, "CROTA2": 0 ].map { FITSPropertySnapshot( name: $0.key, value: .float( $0.value ) ) } )

        let projection = try #require( WCSProjection( metadata: metadata ) )
        let point      = try #require( projection.sourcePixel( ra: 10, dec: 20 ) )

        #expect( Self.near( point, CGPoint( x: 99, y: 99 ) ) )
    }
}
