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

/// Maps a compass azimuth to a short, human-readable direction abbreviation.
///
/// This is the terrestrial azimuth compass (north/east/south/west), distinct from
/// ``NorthOverlay/Compass``, which is the celestial north/east direction derived
/// from an image's WCS.
enum CompassDirection
{
    /// The 16 compass points, clockwise from north.
    private static let points = [ "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW" ]

    /// The 16-point compass abbreviation for an azimuth.
    ///
    /// - Parameter azimuth: The azimuth, in degrees clockwise from north (any
    ///   value; it is normalized to `0 ..< 360`).
    /// - Returns: The abbreviation, e.g. `WSW`.
    static func abbreviation( forAzimuth azimuth: Double ) -> String
    {
        let remainder  = azimuth.truncatingRemainder( dividingBy: 360 )
        let normalized = remainder < 0 ? remainder + 360 : remainder
        let index      = Int( ( normalized / 22.5 ).rounded() ) % Self.points.count

        return Self.points[ index ]
    }
}
