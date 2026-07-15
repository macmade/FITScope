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
import SwiftPixel
import Testing

/// Tests for ``ObjectsOverlay``: availability gates the toolbar toggle on whether
/// the solve found any annotated object, and the coordinate mapping converts the
/// Astrometry.net pixel convention (1-based, origin bottom-left) into the
/// displayed image's pixel space, tracking the image under rotation and flips.
@Suite( "ObjectsOverlay" )
struct ObjectsOverlayTests
{
    /// An annotation at the given pixel position; the other fields are irrelevant
    /// to the test and left at placeholder values.
    private static func annotation( names: [ String ] = [ "NGC 1" ], pixelX: Double = 0, pixelY: Double = 0, radius: Double = 0 ) -> PlateSolveResult.Annotation
    {
        PlateSolveResult.Annotation( names: names, pixelX: pixelX, pixelY: pixelY, radius: radius, type: nil )
    }

    @Test
    func isUnavailableWithoutAnnotations() throws
    {
        #expect( ObjectsOverlay( annotations: [] ).isAvailable == false )
    }

    @Test
    func isAvailableWithAnnotations() throws
    {
        #expect( ObjectsOverlay( annotations: [ Self.annotation() ] ).isAvailable )
    }

    @Test
    func hasAStableNonDisplayIdentifier() throws
    {
        #expect( ObjectsOverlay( annotations: [] ).id == "objects" )
    }

    @Test
    func carriesAndRunsItsUnavailableTapAction() throws
    {
        // The overlay owns its "tapped with nothing to show" action (proposing a
        // plate solve); the toolbar just runs it.
        var ran     = false
        let overlay = ObjectsOverlay( annotations: [] ) { ran = true }

        overlay.onUnavailableTap?()

        #expect( ran )
    }

    @Test
    func labelUsesTheFirstName() throws
    {
        #expect( Self.annotation( names: [ "M 66", "NGC 3627" ] ).label == "M 66" )
        #expect( Self.annotation( names: [] ).label == nil )
    }

    @Test
    func markerRadiusTracksTheObjectSizeOnScreen() throws
    {
        // Above the floor, the on-screen radius is the annotated radius scaled by
        // the displayed magnification, so the circle grows with zoom.
        #expect( ObjectsOverlay.markerRadius( radius: 5, displayScale: 4 ) == 20 )
    }

    @Test
    func markerRadiusClampsToAMinimumForPointSources() throws
    {
        // A point source carries a zero radius; clamp to the on-screen minimum so
        // it still shows a visible marker rather than collapsing to nothing.
        #expect( ObjectsOverlay.markerRadius( radius: 0, displayScale: 4 ) == ObjectsOverlay.minimumMarkerRadius )
    }

    @Test
    func displayedImagePointConvertsOneBasedToZeroBasedWithoutFlippingY() throws
    {
        // Astrometry's pixel (1, 1) is the first stored pixel (data row 0), which
        // FITScope shows at the top (its pipeline does not flip rows). So (1, 1)
        // maps to the first pixel's centre (0.5, 0.5) — a 1-based→0-based shift, no
        // flip, then centred within the pixel so the marker sits on the object.
        let topLeft = ObjectsOverlay.displayedImagePoint( pixelX: 1, pixelY: 1, displayedImageSize: CGSize( width: 100, height: 80 ), orientation: .identity )

        #expect( topLeft == CGPoint( x: 0.5, y: 0.5 ) )

        // The last row (pixel y = imageHeight) maps to the bottom of the frame.
        let bottom = ObjectsOverlay.displayedImagePoint( pixelX: 1, pixelY: 80, displayedImageSize: CGSize( width: 100, height: 80 ), orientation: .identity )

        #expect( bottom == CGPoint( x: 0.5, y: 79.5 ) )
    }

    @Test
    func displayedImagePointMapsThroughAQuarterTurn() throws
    {
        // A 4×2 source rotated 90° clockwise displays as 2×4. The top-left object
        // (1, 1) — first stored pixel — must follow the rotation to the displayed
        // top-right column, matching the stars overlay's mapping for source (0, 0),
        // at its pixel centre (1.5, 0.5).
        let point = ObjectsOverlay.displayedImagePoint( pixelX: 1, pixelY: 1, displayedImageSize: CGSize( width: 2, height: 4 ), orientation: .init( rotation: .clockwise90, mirroredHorizontally: false ) )

        #expect( point == CGPoint( x: 1.5, y: 0.5 ) )
    }
}
