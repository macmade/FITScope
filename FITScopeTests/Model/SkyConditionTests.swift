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

import AppKit
@testable import FITScope
import Testing

/// Tests for ``SkyCondition``: the classification of the Sun's altitude into the
/// daylight / civil / nautical / astronomical twilight / night bands used by the
/// Conditions tab.
@Suite( "SkyCondition" )
struct SkyConditionTests
{
    /// The Sun above the −0.833° sunrise/sunset altitude is daylight, including
    /// the boundary itself.
    @Test
    func daylightAboveTheSunriseAltitude()
    {
        #expect( SkyCondition.forSunAltitude( 45 ) == .day )
        #expect( SkyCondition.forSunAltitude( 0 ) == .day )
        #expect( SkyCondition.forSunAltitude( -0.833 ) == .day )
    }

    /// The Sun between −0.833° and −6° is in civil twilight.
    @Test
    func civilTwilightBand()
    {
        #expect( SkyCondition.forSunAltitude( -1 ) == .civilTwilight )
        #expect( SkyCondition.forSunAltitude( -3 ) == .civilTwilight )
        #expect( SkyCondition.forSunAltitude( -6 ) == .civilTwilight )
    }

    /// The Sun between −6° and −12° is in nautical twilight.
    @Test
    func nauticalTwilightBand()
    {
        #expect( SkyCondition.forSunAltitude( -6.5 ) == .nauticalTwilight )
        #expect( SkyCondition.forSunAltitude( -9 ) == .nauticalTwilight )
        #expect( SkyCondition.forSunAltitude( -12 ) == .nauticalTwilight )
    }

    /// The Sun between −12° and −18° is in astronomical twilight.
    @Test
    func astronomicalTwilightBand()
    {
        #expect( SkyCondition.forSunAltitude( -13 ) == .astronomicalTwilight )
        #expect( SkyCondition.forSunAltitude( -15 ) == .astronomicalTwilight )
        #expect( SkyCondition.forSunAltitude( -18 ) == .astronomicalTwilight )
    }

    /// Below −18° the sky is in full astronomical night.
    @Test
    func nightBelowAstronomicalTwilight()
    {
        #expect( SkyCondition.forSunAltitude( -18.5 ) == .night )
        #expect( SkyCondition.forSunAltitude( -40 ) == .night )
        #expect( SkyCondition.forSunAltitude( -90 ) == .night )
    }

    /// Every condition has a non-empty label and an SF Symbol that resolves.
    @Test
    func everyConditionHasALabelAndResolvableSymbol()
    {
        SkyCondition.allCases.forEach
        {
            condition in

            #expect( condition.label.isEmpty == false )
            #expect( NSImage( systemSymbolName: condition.systemImageName, accessibilityDescription: nil ) != nil, "No SF Symbol named \"\( condition.systemImageName )\"" )
        }
    }
}
