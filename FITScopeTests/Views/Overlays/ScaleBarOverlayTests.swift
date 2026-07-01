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

/// Tests for ``ScaleBarOverlay``: availability gates the toolbar toggle on whether
/// a pixel scale is known, and the measurement picks a nice round angular length
/// whose on-screen size fits the allowed width, labelled in the right unit.
@Suite( "ScaleBarOverlay" )
struct ScaleBarOverlayTests
{
    @Test
    func isUnavailableWithoutAPixelScale() throws
    {
        #expect( ScaleBarOverlay( pixelScale: nil ).isAvailable == false )
    }

    @Test
    func isUnavailableForANonPositivePixelScale() throws
    {
        #expect( ScaleBarOverlay( pixelScale: 0 ).isAvailable == false )
    }

    @Test
    func isAvailableWithAPixelScale() throws
    {
        #expect( ScaleBarOverlay( pixelScale: 1.5 ).isAvailable )
    }

    @Test
    func warnsWithoutAPixelScale() throws
    {
        // With no scale to draw, tapping the always-offered toggle explains why
        // rather than revealing nothing.
        #expect( ScaleBarOverlay( pixelScale: nil ).warning != nil )
    }

    @Test
    func doesNotWarnWithAPixelScale() throws
    {
        #expect( ScaleBarOverlay( pixelScale: 1.5 ).warning == nil )
    }

    @Test
    func hasAStableNonDisplayIdentifier() throws
    {
        #expect( ScaleBarOverlay( pixelScale: nil ).id == "scale" )
    }

    @Test
    func measurementPicksANiceArcminuteLength() throws
    {
        // At 4″/px and actual size (1 point per pixel), up to 200 points spans
        // 800″; the largest nice value that fits is 10′ (600″ → 150 points).
        let measurement = try #require( ScaleBarOverlay.measurement( pixelScale: 4, displayScale: 1, maxLength: 200 ) )

        #expect( measurement.label == "10′" )
        #expect( abs( measurement.lengthInPoints - 150 ) < 0.001 )
    }

    @Test
    func measurementLabelsArcsecondsWhenZoomedIn() throws
    {
        // At 2″/px with only 20 points available, the span is 40″; the largest
        // nice value that fits is 30″ (→ 15 points).
        let measurement = try #require( ScaleBarOverlay.measurement( pixelScale: 2, displayScale: 1, maxLength: 20 ) )

        #expect( measurement.label == "30″" )
        #expect( abs( measurement.lengthInPoints - 15 ) < 0.001 )
    }

    @Test
    func measurementLabelsDegreesForAWideField() throws
    {
        // At 10″/px zoomed out (0.1 points per pixel), 200 points spans 20000″;
        // the largest nice value that fits is 5° (18000″ → 180 points).
        let measurement = try #require( ScaleBarOverlay.measurement( pixelScale: 10, displayScale: 0.1, maxLength: 200 ) )

        #expect( measurement.label == "5°" )
        #expect( abs( measurement.lengthInPoints - 180 ) < 0.001 )
    }

    @Test
    func measurementIsNilForANonPositivePixelScale() throws
    {
        #expect( ScaleBarOverlay.measurement( pixelScale: 0, displayScale: 1, maxLength: 200 ) == nil )
    }

    @Test
    func measurementIsNilWhenEvenTheSmallestBarDoesNotFit() throws
    {
        // Extremely zoomed in: 200 points spans only 0.4″, below the smallest
        // nice value (1″), so no sensible bar can be drawn.
        #expect( ScaleBarOverlay.measurement( pixelScale: 4, displayScale: 100, maxLength: 10 ) == nil )
    }
}
