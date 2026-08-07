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
    func doesNotWarnBeforeDetectionRuns() throws
    {
        // With no stars and detection not yet run, there is nothing to warn about:
        // the overlay is simply not offered rather than flagged.
        #expect( StarsOverlay( stars: [] ).warning == nil )
    }

    @Test
    func warnsWhenDetectionRanWithNoStars() throws
    {
        // Detection completed and found nothing: keep the toggle visible and surface
        // a warning so the user learns detection ran rather than silently vanishing.
        #expect( StarsOverlay( stars: [], hasDetectedStars: true ).warning != nil )
    }

    @Test
    func doesNotWarnWhenStarsWereDetected() throws
    {
        // Stars were found, so the overlay has something to show — no warning.
        #expect( StarsOverlay( stars: [ Self.star( hfr: 3 ) ], hasDetectedStars: true ).warning == nil )
    }

    @Test
    func doesNotWarnWhileStillDetecting() throws
    {
        // While detection is in flight the toolbar shows the loading state; a
        // "found nothing" warning would be premature, so none is reported yet.
        #expect( StarsOverlay( stars: [], isLoading: true, hasDetectedStars: true ).warning == nil )
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
    func markerRadiusClampsToAMinimumWhenZoomedOut() throws
    {
        // A small star at a low magnification would shrink below visibility; clamp
        // to the on-screen minimum so the marker stays seen.
        #expect( StarsOverlay.markerRadius( hfr: 1, displayScale: 0.1 ) == StarsOverlay.minimumMarkerRadius )
    }

    @Test
    func displayedImagePointMapsToThePixelCentreForIdentity() throws
    {
        // With no orientation, a source centroid maps to its pixel *centre* — half a
        // pixel past the index — because the renderer draws pixel `i` spanning
        // `[i, i+1]`. Without this the marker lands half a pixel up and to the left.
        let point = StarsOverlay.displayedImagePoint( x: 10, y: 20, displayedImageSize: CGSize( width: 100, height: 80 ), orientation: .identity )

        #expect( point == CGPoint( x: 10.5, y: 20.5 ) )
    }

    @Test
    func displayedImagePointPreservesSubPixelPosition() throws
    {
        // The sub-pixel centroid is kept, not rounded to a whole pixel, so the
        // marker tracks the star's true position.
        let point = StarsOverlay.displayedImagePoint( x: 10.3, y: 20.7, displayedImageSize: CGSize( width: 100, height: 80 ), orientation: .identity )

        #expect( abs( point.x - 10.8 ) < 0.0001 )
        #expect( abs( point.y - 21.2 ) < 0.0001 )
    }

    @Test
    func displayedImagePointMapsThroughAQuarterTurn() throws
    {
        // A 4×2 source rotated 90° clockwise displays as 2×4. The source corner
        // (0,0) — top-left — must land at the displayed top-right column (1,0),
        // matching the pixel transform, at its pixel centre (1.5, 0.5).
        let point = StarsOverlay.displayedImagePoint( x: 0, y: 0, displayedImageSize: CGSize( width: 2, height: 4 ), orientation: .init( rotation: .clockwise90, mirroredHorizontally: false ) )

        #expect( point == CGPoint( x: 1.5, y: 0.5 ) )
    }

    @Test
    func displayedImagePointMapsThroughAHorizontalMirror() throws
    {
        // A mirror keeps the dimensions and reflects across the width, so the
        // source top-left corner (0,0) of a 4×2 image lands on the displayed
        // top-right column (3,0), at its pixel centre (3.5, 0.5).
        let point = StarsOverlay.displayedImagePoint( x: 0, y: 0, displayedImageSize: CGSize( width: 4, height: 2 ), orientation: .init( rotation: .none, mirroredHorizontally: true ) )

        #expect( point == CGPoint( x: 3.5, y: 0.5 ) )
    }

    @Test
    func displayedImagePointMapsThroughAHalfTurn() throws
    {
        // 180° also keeps the dimensions, and sends the source top-left corner to
        // the opposite corner (3,1) of a 4×2 image, at its centre (3.5, 1.5).
        let point = StarsOverlay.displayedImagePoint( x: 0, y: 0, displayedImageSize: CGSize( width: 4, height: 2 ), orientation: .init( rotation: .rotate180, mirroredHorizontally: false ) )

        #expect( point == CGPoint( x: 3.5, y: 1.5 ) )
    }

    @Test
    func displayedImagePointMapsThroughACounterClockwiseQuarterTurn() throws
    {
        // A 4×2 source rotated 90° counter-clockwise displays as 2×4, and the
        // source top-left corner swings to the displayed bottom-left pixel (0,3),
        // at its centre (0.5, 3.5) — the mirror image of the clockwise case above.
        let point = StarsOverlay.displayedImagePoint( x: 0, y: 0, displayedImageSize: CGSize( width: 2, height: 4 ), orientation: .init( rotation: .counterClockwise90, mirroredHorizontally: false ) )

        #expect( point == CGPoint( x: 0.5, y: 3.5 ) )
    }

    @Test
    func displayedImagePointAppliesTheMirrorBeforeTheRotation() throws
    {
        // Order matters: the mirror is taken across the *source* width and only
        // then rotated. A 4×2 source mirrored and turned 90° clockwise displays as
        // 2×4; the source top-left (0,0) mirrors to (3,0), which the turn sends to
        // the displayed (1,3) — centre (1.5, 3.5). Applying the turn first would
        // put it at (1.5, 0.5) instead.
        let point = StarsOverlay.displayedImagePoint( x: 0, y: 0, displayedImageSize: CGSize( width: 2, height: 4 ), orientation: .init( rotation: .clockwise90, mirroredHorizontally: true ) )

        #expect( point == CGPoint( x: 1.5, y: 3.5 ) )
    }

    @Test
    func displayedImagePointClampsOutOfRangeCentroids() throws
    {
        // A centroid past the image bounds is clamped into range rather than
        // mapped out of the frame (then centred within its pixel).
        let point = StarsOverlay.displayedImagePoint( x: 200, y: -5, displayedImageSize: CGSize( width: 100, height: 80 ), orientation: .identity )

        #expect( point == CGPoint( x: 99.5, y: 0.5 ) )
    }
}
