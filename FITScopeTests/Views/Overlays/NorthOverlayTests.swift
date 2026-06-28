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
import SwiftPixel
import Testing

/// Tests for ``NorthOverlay``: availability gates the toolbar toggle on whether
/// the WCS yields an orientation, and the compass derivation turns the WCS linear
/// transform (the `CD` matrix, or `CDELT` + `CROTA2`) into on-screen north and
/// east directions, tracking the image as the user rotates or flips it.
@Suite( "NorthOverlay" )
struct NorthOverlayTests
{
    /// Builds a WCS metadata from raw keyword/value pairs.
    private static func wcs( _ pairs: [ String: Double ] ) -> FITSMetadata
    {
        FITSMetadata( properties: pairs.map { FITSPropertySnapshot( name: $0.key, value: .float( $0.value ) ) } )
    }

    /// Whether two on-screen direction vectors point the same way, within a small
    /// tolerance — both are unit vectors, so a component-wise comparison suffices.
    private static func sameDirection( _ a: CGVector, _ b: CGVector, tolerance: CGFloat = 0.0001 ) -> Bool
    {
        abs( a.dx - b.dx ) <= tolerance && abs( a.dy - b.dy ) <= tolerance
    }

    @Test
    func isUnavailableWithoutWCS() throws
    {
        #expect( NorthOverlay( wcs: nil ).isAvailable == false )
    }

    @Test
    func isUnavailableWhenTheWCSCarriesNoOrientation() throws
    {
        // A header with celestial keywords but no linear transform (no CD matrix,
        // no CDELT) cannot yield a north direction, so the toggle stays hidden.
        #expect( NorthOverlay( wcs: Self.wcs( [ "CRVAL1": 83.8, "CRVAL2": -5.4 ] ) ).isAvailable == false )
    }

    @Test
    func isAvailableWithACDMatrix() throws
    {
        #expect( NorthOverlay( wcs: Self.wcs( [ "CD1_1": -1, "CD1_2": 0, "CD2_1": 0, "CD2_2": 1 ] ) ).isAvailable )
    }

    @Test
    func hasAStableNonDisplayIdentifier() throws
    {
        #expect( NorthOverlay( wcs: nil ).id == "north" )
    }

    @Test
    func compassPointsNorthDownAndEastLeftForAStandardSkyWCS() throws
    {
        // A north-up / east-left sky field (CDELT1 < 0, CDELT2 > 0, no rotation):
        // CD1_1 = -1, CD2_2 = +1. FITScope displays data row 0 at the top — the
        // opposite of the conventional bottom-up sky display — so such a field
        // appears vertically flipped: north points DOWN and east points LEFT.
        let compass = try #require( NorthOverlay.compass( wcs: Self.wcs( [ "CD1_1": -1, "CD1_2": 0, "CD2_1": 0, "CD2_2": 1 ] ), orientation: .identity ) )

        #expect( Self.sameDirection( compass.north, CGVector( dx: 0, dy: 1 ) ) )
        #expect( Self.sameDirection( compass.east,  CGVector( dx: -1, dy: 0 ) ) )
    }

    @Test
    func compassRotatesWithTheDisplayOrientation() throws
    {
        // Rotating the displayed image 90° clockwise turns the on-screen compass
        // with it: the down-pointing north of the standard field becomes a
        // left-pointing north (down → left under a clockwise quarter-turn).
        let compass = try #require( NorthOverlay.compass( wcs: Self.wcs( [ "CD1_1": -1, "CD1_2": 0, "CD2_1": 0, "CD2_2": 1 ] ), orientation: .init( rotation: .clockwise90, mirroredHorizontally: false ) ) )

        #expect( Self.sameDirection( compass.north, CGVector( dx: -1, dy: 0 ) ) )
    }

    @Test
    func compassMirrorsWithAHorizontalFlip() throws
    {
        // A horizontal flip mirrors east/west but leaves the vertical north of the
        // standard field unchanged: north still points down, east now points right.
        let compass = try #require( NorthOverlay.compass( wcs: Self.wcs( [ "CD1_1": -1, "CD1_2": 0, "CD2_1": 0, "CD2_2": 1 ] ), orientation: .init( rotation: .none, mirroredHorizontally: true ) ) )

        #expect( Self.sameDirection( compass.north, CGVector( dx: 0, dy: 1 ) ) )
        #expect( Self.sameDirection( compass.east,  CGVector( dx: 1, dy: 0 ) ) )
    }

    @Test
    func compassFallsBackToCDELTAndCROTAWhenNoCDMatrix() throws
    {
        // With no CD matrix, the standard AIPS CDELT + CROTA2 form yields the same
        // transform: CDELT1 < 0, CDELT2 > 0, CROTA2 = 0 is the same north-up field.
        let compass = try #require( NorthOverlay.compass( wcs: Self.wcs( [ "CDELT1": -1, "CDELT2": 1, "CROTA2": 0 ] ), orientation: .identity ) )

        #expect( Self.sameDirection( compass.north, CGVector( dx: 0, dy: 1 ) ) )
        #expect( Self.sameDirection( compass.east,  CGVector( dx: -1, dy: 0 ) ) )
    }

    @Test
    func compassAppliesCROTARotation() throws
    {
        // A CROTA2 of 90° rotates the sky relative to the pixel grid. Starting from
        // the standard north-down / east-left field, a +90° rotation of the WCS
        // turns north onto the east axis. Verify north is horizontal (dy ≈ 0).
        let compass = try #require( NorthOverlay.compass( wcs: Self.wcs( [ "CDELT1": -1, "CDELT2": 1, "CROTA2": 90 ] ), orientation: .identity ) )

        #expect( abs( compass.north.dy ) <= 0.0001 )
    }
}
