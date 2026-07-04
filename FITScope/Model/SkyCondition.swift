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

/// How dark the sky is, classified from the Sun's altitude — the single most
/// useful summary for an astrophotographer: was the capture made in daylight,
/// one of the twilight bands, or full astronomical darkness.
///
/// The thresholds match the standard twilight definitions the ephemeris uses:
/// the Sun's centre at −0.833° (sunrise/sunset), −6° (civil), −12° (nautical) and
/// −18° (astronomical).
enum SkyCondition: CaseIterable
{
    /// The Sun is up (altitude ≥ −0.833°).
    case day

    /// Civil twilight: the Sun is between −0.833° and −6°.
    case civilTwilight

    /// Nautical twilight: the Sun is between −6° and −12°.
    case nauticalTwilight

    /// Astronomical twilight: the Sun is between −12° and −18°.
    case astronomicalTwilight

    /// Full astronomical night: the Sun is below −18°.
    case night

    /// Classifies the sky darkness from the Sun's altitude, in degrees.
    ///
    /// - Parameter altitude: The Sun's altitude above the horizon, in degrees.
    /// - Returns: The matching condition.
    static func forSunAltitude( _ altitude: Double ) -> SkyCondition
    {
        switch altitude
        {
            case let value where value >= -0.833: return .day
            case let value where value >= -6:      return .civilTwilight
            case let value where value >= -12:     return .nauticalTwilight
            case let value where value >= -18:     return .astronomicalTwilight
            default:                                return .night
        }
    }

    /// A human-readable label, e.g. `"Astronomical Night"`.
    var label: String
    {
        switch self
        {
            case .day:                  return "Daylight"
            case .civilTwilight:        return "Civil Twilight"
            case .nauticalTwilight:     return "Nautical Twilight"
            case .astronomicalTwilight: return "Astronomical Twilight"
            case .night:                return "Astronomical Night"
        }
    }

    /// The SF Symbol depicting the condition.
    var systemImageName: String
    {
        switch self
        {
            case .day:                  return "sun.max.fill"
            case .civilTwilight:        return "sun.horizon.fill"
            case .nauticalTwilight:     return "sunset.fill"
            case .astronomicalTwilight: return "moon.fill"
            case .night:                return "moon.stars.fill"
        }
    }
}
