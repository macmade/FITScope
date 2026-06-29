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

/// Tests for ``WeatherConditions``'s mapping of a WMO weather code to an SF Symbol
/// and a description.
@Suite( "WeatherConditions" )
struct WeatherConditionsTests
{
    /// Each WMO weather code maps to the expected SF Symbol, with the day / night
    /// variants distinguished for the clear, partly-cloudy and rain-shower codes.
    @Test( arguments: [
        ( 0, true, "sun.max" ),
        ( 0, false, "moon.stars" ),
        ( 1, true, "sun.max" ),
        ( 1, false, "moon.stars" ),
        ( 2, true, "cloud.sun" ),
        ( 2, false, "cloud.moon" ),
        ( 3, true, "cloud.fill" ),
        ( 45, true, "cloud.fog" ),
        ( 48, false, "cloud.fog" ),
        ( 51, true, "cloud.drizzle" ),
        ( 56, true, "cloud.sleet" ),
        ( 61, true, "cloud.rain" ),
        ( 66, true, "cloud.sleet" ),
        ( 71, true, "cloud.snow" ),
        ( 77, false, "cloud.snow" ),
        ( 80, true, "cloud.sun.rain" ),
        ( 80, false, "cloud.moon.rain" ),
        ( 85, true, "cloud.snow" ),
        ( 95, true, "cloud.bolt.rain" ),
        ( 96, false, "cloud.bolt.rain" ),
        ( 99, true, "cloud.bolt.rain" ),
    ] )
    func mapsCodeToSymbol( code: Int, isDay: Bool, expected: String ) async throws
    {
        #expect( WeatherConditions.symbolName( forWMOCode: code, isDay: isDay ) == expected )
    }

    /// An unknown code falls back to a generic cloud rather than crashing.
    @Test
    func unknownCodeFallsBack() async
    {
        #expect( WeatherConditions.symbolName( forWMOCode: 123, isDay: true ) == "cloud" )
    }

    /// Every symbol the mapping can produce resolves to a real SF Symbol.
    @Test
    func everySymbolResolves() async
    {
        let codes = [ 0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99, 123 ]

        codes.forEach
        {
            code in [ true, false ].forEach
            {
                let symbol = WeatherConditions.symbolName( forWMOCode: code, isDay: $0 )

                #expect( NSImage( systemSymbolName: symbol, accessibilityDescription: nil ) != nil, "No SF Symbol named \"\( symbol )\"" )
            }
        }
    }

    /// A representative set of WMO codes map to their documented descriptions.
    @Test( arguments: [
        ( 0, "Clear sky" ),
        ( 2, "Partly cloudy" ),
        ( 3, "Overcast" ),
        ( 45, "Fog" ),
        ( 65, "Heavy rain" ),
        ( 95, "Thunderstorm" ),
    ] )
    func mapsCodeToDescription( code: Int, expected: String ) async throws
    {
        #expect( WeatherConditions.description( forWMOCode: code ) == expected )
    }

    /// An unknown code's description is "Unknown".
    @Test
    func unknownCodeDescription() async
    {
        #expect( WeatherConditions.description( forWMOCode: 123 ) == "Unknown" )
    }
}
