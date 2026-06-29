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

import Foundation

/// The Moon's phase at a given instant, computed locally from the mean synodic
/// cycle — no network or ephemeris file needed.
///
/// The model counts elapsed time since a reference new moon and reduces it
/// modulo the mean synodic month. This is the standard "mean phase" approximation
/// (it ignores the orbit's eccentricity, so the instant of an exact phase can be
/// off by several hours), which is ample for labelling a capture's moon phase and
/// illumination.
public struct MoonPhase: Equatable, Sendable
{
    /// One of the eight named lunar phases.
    public enum Phase: String, CaseIterable, Sendable
    {
        /// The unlit new moon.
        case newMoon

        /// Waxing crescent — growing, less than half lit.
        case waxingCrescent

        /// First quarter — waxing, half lit.
        case firstQuarter

        /// Waxing gibbous — growing, more than half lit.
        case waxingGibbous

        /// The fully lit full moon.
        case fullMoon

        /// Waning gibbous — shrinking, more than half lit.
        case waningGibbous

        /// Last quarter — waning, half lit.
        case lastQuarter

        /// Waning crescent — shrinking, less than half lit.
        case waningCrescent

        /// A human-readable name, e.g. `"Waxing Gibbous"`.
        public var name: String
        {
            switch self
            {
                case .newMoon:        return "New Moon"
                case .waxingCrescent: return "Waxing Crescent"
                case .firstQuarter:   return "First Quarter"
                case .waxingGibbous:  return "Waxing Gibbous"
                case .fullMoon:       return "Full Moon"
                case .waningGibbous:  return "Waning Gibbous"
                case .lastQuarter:    return "Last Quarter"
                case .waningCrescent: return "Waning Crescent"
            }
        }

        /// The name of the SF Symbol depicting this phase.
        public var systemImageName: String
        {
            switch self
            {
                case .newMoon:        return "moonphase.new.moon"
                case .waxingCrescent: return "moonphase.waxing.crescent"
                case .firstQuarter:   return "moonphase.first.quarter"
                case .waxingGibbous:  return "moonphase.waxing.gibbous"
                case .fullMoon:       return "moonphase.full.moon"
                case .waningGibbous:  return "moonphase.waning.gibbous"
                case .lastQuarter:    return "moonphase.last.quarter"
                case .waningCrescent: return "moonphase.waning.crescent"
            }
        }
    }

    /// The mean synodic month — the average new-moon-to-new-moon period, in days.
    private static let synodicMonth = 29.530588853

    /// The Julian Date of a reference new moon: 2000-01-06 18:14 UTC.
    private static let referenceNewMoon = 2451550.2597

    /// The Julian Date of the Unix epoch (1970-01-01 00:00 UTC).
    private static let unixEpochJulianDate = 2440587.5

    /// The Moon's age, in days since the most recent new moon (0…~29.53).
    public let age: Double

    /// The position in the synodic cycle, from 0 (new) through 0.5 (full) to just
    /// under 1 (back to new).
    public let fraction: Double

    /// The illuminated fraction of the disc, from 0 (new) to 1 (full).
    public let illumination: Double

    /// The named phase nearest the current ``fraction``.
    public let phase: Phase

    /// Computes the Moon's phase at a date.
    ///
    /// - Parameter date: The instant to evaluate (e.g. a frame's `DATE-OBS`).
    public init( date: Date )
    {
        let julianDate     = ( date.timeIntervalSince1970 / 86400 ) + Self.unixEpochJulianDate
        let elapsed        = julianDate - Self.referenceNewMoon
        let cycles         = elapsed / Self.synodicMonth
        let fraction       = cycles - cycles.rounded( .down )

        self.fraction      = fraction
        self.age           = fraction * Self.synodicMonth
        self.illumination  = ( 1 - cos( 2 * .pi * fraction ) ) / 2
        self.phase         = Self.phase( for: fraction )
    }

    /// The named phase nearest a cycle position, snapping to the closest of the
    /// eight equal eighths (so each quarter/syzygy owns a band centred on it).
    ///
    /// - Parameter fraction: The cycle position in 0…1.
    /// - Returns: The nearest named phase.
    private static func phase( for fraction: Double ) -> Phase
    {
        let index   = Int( ( fraction * 8 ).rounded() ) % 8
        let ordered = Phase.allCases

        return ordered[ index ]
    }
}
