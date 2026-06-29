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
import Foundation
import Testing

/// Tests for ``LocationInfoView``: the latitude/longitude formatting shown in the
/// Map tab, and the SF Symbols its rows (and the Map tab's status placeholders)
/// rely on.
@Suite( "LocationInfoView" )
struct LocationInfoViewTests
{
    /// A positive latitude is shown to four decimals with a north suffix.
    @Test
    func formatsPositiveLatitudeAsNorth()
    {
        #expect( LocationInfoView.format( 46.2, positive: "N", negative: "S" ) == "46.2000° N" )
    }

    /// A negative latitude is shown sign-free with a south suffix.
    @Test
    func formatsNegativeLatitudeAsSouth()
    {
        #expect( LocationInfoView.format( -33.8688, positive: "N", negative: "S" ) == "33.8688° S" )
    }

    /// A positive longitude is shown with an east suffix.
    @Test
    func formatsPositiveLongitudeAsEast()
    {
        #expect( LocationInfoView.format( 151.2093, positive: "E", negative: "W" ) == "151.2093° E" )
    }

    /// A negative longitude is shown sign-free with a west suffix.
    @Test
    func formatsNegativeLongitudeAsWest()
    {
        #expect( LocationInfoView.format( -6.15, positive: "E", negative: "W" ) == "6.1500° W" )
    }

    /// Exactly zero takes the positive (non-negative) suffix.
    @Test
    func formatsZeroWithThePositiveSuffix()
    {
        #expect( LocationInfoView.format( 0, positive: "N", negative: "S" ) == "0.0000° N" )
    }

    /// Every SF Symbol the location views name resolves to a real symbol.
    @Test
    func everyLocationSymbolResolves()
    {
        let symbols =
            [
                "arrow.up.arrow.down",    // Latitude row
                "arrow.left.arrow.right", // Longitude row
                "location.slash",         // "No Location Data" placeholder
                "wifi.slash",             // "Map Unavailable" placeholder
            ]

        symbols.forEach
        {
            symbol in #expect( NSImage( systemSymbolName: symbol, accessibilityDescription: nil ) != nil, "No SF Symbol named \"\( symbol )\"" )
        }
    }
}
