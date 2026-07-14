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
import SwiftAstro
import Testing

/// Tests for ``PlateSolveHints``: deriving the astrometry.net position and scale
/// hints from an image's pointing, plate scale and pixel dimensions.
@Suite( "PlateSolveHints" )
struct PlateSolveHintsTests
{
    @Test
    func derivesPositionAndScaleWhenEverythingIsKnown() throws
    {
        let hints = PlateSolveHints(
            coordinate: EquatorialCoordinate( rightAscension: 83.8, declination: -5.4 ),
            pixelScale: 2.0,
            dimensions: ( width: 3600, height: 1800 )
        )

        #expect( hints.centerRA  == 83.8 )
        #expect( hints.centerDec == -5.4 )
        #expect( hints.scaleEstimate == 2.0 )

        // radius = pixelScale * max(width, height) / 3600 = 2 * 3600 / 3600 = 2 degrees.
        let radius = try #require( hints.radius )

        #expect( abs( radius - 2.0 ) < 1e-9 )
        #expect( hints.isEmpty == false )
    }

    @Test
    func includesScaleButNoPositionWhenPointingIsMissing() throws
    {
        let hints = PlateSolveHints( coordinate: nil, pixelScale: 1.5, dimensions: ( width: 1000, height: 1000 ) )

        #expect( hints.scaleEstimate == 1.5 )
        #expect( hints.centerRA  == nil )
        #expect( hints.centerDec == nil )
        #expect( hints.radius    == nil )
        #expect( hints.isEmpty   == false )
    }

    @Test
    func omitsThePositionHintWhenTheScaleOrDimensionsAreMissing() throws
    {
        let coordinate = EquatorialCoordinate( rightAscension: 10, declination: 20 )

        // No plate scale: the radius cannot be founded, so no position hint.
        let noScale = PlateSolveHints( coordinate: coordinate, pixelScale: nil, dimensions: ( width: 1000, height: 1000 ) )

        #expect( noScale.centerRA == nil )
        #expect( noScale.radius   == nil )
        #expect( noScale.isEmpty )

        // No dimensions: same — the field's angular size is unknown.
        let noDimensions = PlateSolveHints( coordinate: coordinate, pixelScale: 2.0, dimensions: nil )

        #expect( noDimensions.centerRA      == nil )
        #expect( noDimensions.radius        == nil )
        #expect( noDimensions.scaleEstimate == 2.0 )
    }

    @Test
    func dropsANonPositivePlateScale() throws
    {
        let zero     = PlateSolveHints( coordinate: nil, pixelScale: 0, dimensions: nil )
        let negative = PlateSolveHints( coordinate: nil, pixelScale: -1, dimensions: nil )

        #expect( zero.scaleEstimate == nil )
        #expect( zero.isEmpty )
        #expect( negative.scaleEstimate == nil )
    }

    @Test
    func dropsThePositionHintForAnOutOfRangeDeclination() throws
    {
        let hints = PlateSolveHints(
            coordinate: EquatorialCoordinate( rightAscension: 10, declination: 120 ),
            pixelScale: 2.0,
            dimensions: ( width: 100, height: 100 )
        )

        // The scale hint stays; the impossible declination drops only the position.
        #expect( hints.scaleEstimate == 2.0 )
        #expect( hints.centerDec == nil )
        #expect( hints.centerRA  == nil )
        #expect( hints.radius    == nil )
    }

    @Test
    func wrapsTheRightAscensionIntoZeroTo360() throws
    {
        let negative = PlateSolveHints(
            coordinate: EquatorialCoordinate( rightAscension: -10, declination: 0 ),
            pixelScale: 1.0,
            dimensions: ( width: 100, height: 100 )
        )
        let over = PlateSolveHints(
            coordinate: EquatorialCoordinate( rightAscension: 370, declination: 0 ),
            pixelScale: 1.0,
            dimensions: ( width: 100, height: 100 )
        )

        #expect( negative.centerRA == 350 )
        #expect( over.centerRA     == 10 )
    }

    @Test
    func isEmptyWhenNothingIsKnown() throws
    {
        let hints = PlateSolveHints( coordinate: nil, pixelScale: nil, dimensions: nil )

        #expect( hints.isEmpty )
    }
}
