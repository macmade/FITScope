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

/// Tests for ``MoonPhase``: the local lunar-phase computation, checked against
/// known new / first-quarter / full moons of 2024 within tolerance.
@Suite( "MoonPhase" )
struct MoonPhaseTests
{
    /// The new moon of 2024-01-11 11:57 UTC is essentially unlit.
    @Test
    func newMoonIsDarkAndClassified() throws
    {
        let phase = MoonPhase( date: try Self.date( 2024, 1, 11, 11, 57 ) )

        #expect( phase.phase == .newMoon )
        #expect( phase.illumination < 0.05 )
    }

    /// The first quarter of 2024-01-18 03:53 UTC is roughly half lit and waxing.
    @Test
    func firstQuarterIsClassified() throws
    {
        let phase = MoonPhase( date: try Self.date( 2024, 1, 18, 3, 53 ) )

        #expect( phase.phase == .firstQuarter )
        #expect( phase.illumination > 0.35 )
        #expect( phase.illumination < 0.65 )
    }

    /// The full moon of 2024-01-25 17:54 UTC is fully lit.
    @Test
    func fullMoonIsBrightAndClassified() throws
    {
        let phase = MoonPhase( date: try Self.date( 2024, 1, 25, 17, 54 ) )

        #expect( phase.phase == .fullMoon )
        #expect( phase.illumination > 0.95 )
    }

    /// The reference new moon of 2000-01-06 18:14 UTC anchors the cycle.
    @Test
    func referenceEpochIsNewMoon() throws
    {
        let phase = MoonPhase( date: try Self.date( 2000, 1, 6, 18, 14 ) )

        #expect( phase.phase == .newMoon )
        #expect( phase.illumination < 0.02 )
        #expect( phase.age < 1.0 )
    }

    /// Illumination is always a fraction in 0…1, and the age stays within one
    /// synodic month, for dates spread across a lunation.
    @Test
    func derivedValuesStayInRange() throws
    {
        let days = [ 1, 5, 9, 13, 17, 21, 25, 29 ]

        try days.forEach
        {
            day in

            let phase = MoonPhase( date: try Self.date( 2024, 1, day, 0, 0 ) )

            #expect( phase.illumination >= 0 )
            #expect( phase.illumination <= 1 )
            #expect( phase.fraction >= 0 )
            #expect( phase.fraction < 1 )
            #expect( phase.age >= 0 )
            #expect( phase.age < 29.6 )
        }
    }

    /// Every phase has a non-empty name and an SF Symbol that resolves.
    @Test
    func everyPhaseHasANameAndResolvableSymbol()
    {
        MoonPhase.Phase.allCases.forEach
        {
            phase in

            #expect( phase.name.isEmpty == false )
            #expect( NSImage( systemSymbolName: phase.systemImageName, accessibilityDescription: nil ) != nil, "No SF Symbol named \"\( phase.systemImageName )\"" )
        }
    }

    // MARK: - Helpers

    /// Builds a UTC date from its components.
    private static func date( _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int ) throws -> Date
    {
        var components      = DateComponents()
        components.year     = year
        components.month    = month
        components.day      = day
        components.hour     = hour
        components.minute   = minute
        components.timeZone = TimeZone( identifier: "UTC" )

        var calendar      = Calendar( identifier: .gregorian )
        calendar.timeZone = try #require( TimeZone( identifier: "UTC" ) )

        return try #require( calendar.date( from: components ) )
    }
}
