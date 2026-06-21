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
import Testing

/// Tests for `CanvasGeometry`: fit factor is the limiting ratio; centered
/// origin places the content's centre at the viewport's centre.
@Suite( "CanvasGeometry" )
struct CanvasGeometryTests
{
    @Test
    func fitFactorIsLimitingRatio() throws
    {
        // 1000×500 content into a 200×200 viewport → width limits → 0.2.
        #expect( CanvasGeometry.fitFactor( content: CGSize( width: 1000, height: 500 ), visible: CGSize( width: 200, height: 200 ) ) == 0.2 )
    }

    @Test
    func fitFactorIsZeroForDegenerateInput() throws
    {
        #expect( CanvasGeometry.fitFactor( content: .zero, visible: CGSize( width: 200, height: 200 ) ) == 0 )
        #expect( CanvasGeometry.fitFactor( content: CGSize( width: 10, height: 10 ), visible: .zero ) == 0 )
    }

    @Test
    func centeredOriginCentersContent() throws
    {
        // Visible 100×100 (in document space) over 400×400 content → origin (150,150).
        let origin = CanvasGeometry.centeredOrigin( content: CGSize( width: 400, height: 400 ), visibleInDocumentSpace: CGSize( width: 100, height: 100 ) )

        #expect( origin == CGPoint( x: 150, y: 150 ) )
    }

    @Test
    func clampBoundsMagnification() throws
    {
        #expect( CanvasGeometry.clamp( 100, min: 0.05, max: 40 ) == 40 )
        #expect( CanvasGeometry.clamp( 0.001, min: 0.05, max: 40 ) == 0.05 )
        #expect( CanvasGeometry.clamp( 1.5, min: 0.05, max: 40 ) == 1.5 )
    }

    @Test
    func boundedFitFactorTracksTheViewportSize() throws
    {
        let content = CGSize( width: 1000, height: 500 )

        // The fit magnification follows the viewport: a larger viewport fits at a
        // larger magnification, so re-evaluating after a resize keeps an image
        // fitted.
        #expect( CanvasGeometry.boundedFitFactor( content: content, visible: CGSize( width: 200, height: 200 ), minimum: 0.05, maximum: 40 ) == 0.2 )
        #expect( CanvasGeometry.boundedFitFactor( content: content, visible: CGSize( width: 500, height: 500 ), minimum: 0.05, maximum: 40 ) == 0.5 )
    }

    @Test
    func boundedFitFactorClampsToTheMagnificationRange() throws
    {
        // A tiny image would fit far above the maximum; clamp to the ceiling.
        #expect( CanvasGeometry.boundedFitFactor( content: CGSize( width: 1, height: 1 ), visible: CGSize( width: 800, height: 800 ), minimum: 0.05, maximum: 40 ) == 40 )

        // A huge image would fit far below the floor; clamp to the floor.
        #expect( CanvasGeometry.boundedFitFactor( content: CGSize( width: 100_000, height: 100_000 ), visible: CGSize( width: 200, height: 200 ), minimum: 0.05, maximum: 40 ) == 0.05 )
    }

    @Test
    func boundedFitFactorIsZeroForDegenerateInput() throws
    {
        #expect( CanvasGeometry.boundedFitFactor( content: .zero, visible: CGSize( width: 200, height: 200 ), minimum: 0.05, maximum: 40 ) == 0 )
    }

    @Test
    func minimumMagnificationIsTheFitFactorForLargeImages() throws
    {
        // A large image (fit factor < 1): the smallest useful zoom is the fit
        // factor itself — zooming out further only adds empty margin.
        #expect( CanvasGeometry.minimumMagnification( fitFactor: 0.2, floor: 0.05 ) == 0.2 )
    }

    @Test
    func minimumMagnificationNeverExceedsActualSize() throws
    {
        // A small image (fit factor > 1) is scaled up to fit; actual size (100%)
        // must stay reachable, so the minimum never rises above 1.0.
        #expect( CanvasGeometry.minimumMagnification( fitFactor: 3.0, floor: 0.05 ) == 1.0 )
    }

    @Test
    func minimumMagnificationNeverDropsBelowTheFloor() throws
    {
        // A huge image fits below the floor; the minimum stays at the floor so
        // the scroll view keeps a sane lower bound.
        #expect( CanvasGeometry.minimumMagnification( fitFactor: 0.001, floor: 0.05 ) == 0.05 )
    }

    @Test
    func canZoomOutAboveTheMinimum() throws
    {
        #expect( CanvasGeometry.canZoomOut( magnification: 0.5, minimum: 0.2 ) == true )
    }

    @Test
    func cannotZoomOutAtOrBelowTheMinimum() throws
    {
        #expect( CanvasGeometry.canZoomOut( magnification: 0.2, minimum: 0.2 ) == false )
        #expect( CanvasGeometry.canZoomOut( magnification: 0.1, minimum: 0.2 ) == false )
    }

    @Test
    func isFittedAtTheFitMagnification() throws
    {
        #expect( CanvasGeometry.isFitted( magnification: 0.2, fitMagnification: 0.2 ) == true )

        // A small image is fitted while scaled up above 100%.
        #expect( CanvasGeometry.isFitted( magnification: 3.0, fitMagnification: 3.0 ) == true )
    }

    @Test
    func isNotFittedAwayFromTheFitMagnification() throws
    {
        #expect( CanvasGeometry.isFitted( magnification: 0.5, fitMagnification: 0.2 ) == false )
    }

    @Test
    func resizeReFitsAFittedImage() throws
    {
        // A fitted image follows the new fit magnification, whether the viewport
        // grew (fit rises) or shrank (fit falls).
        #expect( CanvasGeometry.magnificationAfterResize( currentMagnification: 0.2, fitMagnification: 0.5, wasFitted: true ) == 0.5 )
        #expect( CanvasGeometry.magnificationAfterResize( currentMagnification: 0.5, fitMagnification: 0.2, wasFitted: true ) == 0.2 )
    }

    @Test
    func resizeKeepsAZoomedInImageThatStillFills() throws
    {
        // Zoomed in and still larger than the viewport: keep the magnification.
        #expect( CanvasGeometry.magnificationAfterResize( currentMagnification: 2.0, fitMagnification: 0.3, wasFitted: false ) == 2.0 )
    }

    @Test
    func resizeSnapsAZoomedInImageBackToFitWhenItNoLongerFills() throws
    {
        // The viewport grew past the zoomed-in image: snapping up to the fit
        // magnification avoids black borders on all sides.
        #expect( CanvasGeometry.magnificationAfterResize( currentMagnification: 0.5, fitMagnification: 0.8, wasFitted: false ) == 0.8 )
    }
}
