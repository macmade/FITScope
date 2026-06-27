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
import SwiftAstro
import SwiftPixel
import Testing

/// Tests for ``StarsOverlay``: availability gates the toolbar toggle on whether
/// any star was detected, and the marker radius tracks the star size on screen
/// while staying visible when zoomed out.
@Suite( "StarsOverlay" )
struct StarsOverlayTests
{
    /// A star at the origin with the given half-flux radius; the other metrics are
    /// irrelevant to the overlay and left at placeholder values.
    private static func star( hfr: Double ) -> Star
    {
        Star( x: 0, y: 0, flux: 1, hfr: hfr, fwhm: hfr * 2, eccentricity: 0 )
    }

    @Test
    func isUnavailableWithoutStars() throws
    {
        #expect( StarsOverlay( stars: [] ).isAvailable == false )
    }

    @Test
    func isAvailableWithStars() throws
    {
        #expect( StarsOverlay( stars: [ Self.star( hfr: 3 ) ] ).isAvailable )
    }

    @Test
    func hasAStableNonDisplayIdentifier() throws
    {
        #expect( StarsOverlay( stars: [] ).id == "stars" )
    }

    @Test
    func isNotLoadingByDefault() throws
    {
        #expect( StarsOverlay( stars: [] ).isLoading == false )
    }

    @Test
    func reportsLoadingWhileDetecting() throws
    {
        // Detection runs before any star is available, so the overlay can report
        // it is loading while still being unavailable — that drives the toolbar's
        // progress state generically, with no star-specific code in the toolbar.
        let overlay = StarsOverlay( stars: [], isLoading: true )

        #expect( overlay.isLoading )
        #expect( overlay.isAvailable == false )
    }

    @Test
    func markerRadiusTracksTheStarSizeOnScreen() throws
    {
        // Above the floor, the on-screen radius is the half-flux radius scaled by
        // the displayed magnification, so the circle hugs the star and grows with
        // zoom.
        #expect( StarsOverlay.markerRadius( hfr: 5, displayScale: 4 ) == 20 )
    }

    @Test
    func markerRadiusClampsToAMinimumWhenZoomedOut()throws
    {
        // A small star at a low magnification would shrink below visibility; clamp
        // to the on-screen minimum so the marker stays seen.
        #expect( StarsOverlay.markerRadius( hfr: 1, displayScale: 0.1 ) == StarsOverlay.minimumMarkerRadius )
    }

    @Test
    func displayedImagePointPassesThroughForIdentity() throws
    {
        // With no orientation, a source centroid keeps its coordinates.
        let point = StarsOverlay.displayedImagePoint( x: 10, y: 20, displayedImageSize: CGSize( width: 100, height: 80 ), orientation: .identity )

        #expect( point == CGPoint( x: 10, y: 20 ) )
    }

    @Test
    func displayedImagePointMapsThroughAQuarterTurn() throws
    {
        // A 4×2 source rotated 90° clockwise displays as 2×4. The source corner
        // (0,0) — top-left — must land at the displayed top-right column (1,0),
        // matching the pixel transform, so the marker follows the rotation.
        let point = StarsOverlay.displayedImagePoint( x: 0, y: 0, displayedImageSize: CGSize( width: 2, height: 4 ), orientation: .init( rotation: .clockwise90, mirroredHorizontally: false ) )

        #expect( point == CGPoint( x: 1, y: 0 ) )
    }

    @Test
    func displayedImagePointClampsOutOfRangeCentroids() throws
    {
        // A centroid past the image bounds is clamped into range rather than
        // mapped out of the frame.
        let point = StarsOverlay.displayedImagePoint( x: 200, y: -5, displayedImageSize: CGSize( width: 100, height: 80 ), orientation: .identity )

        #expect( point == CGPoint( x: 99, y: 0 ) )
    }
}
