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

/// A geographic coordinate pair — the observing site's latitude and longitude,
/// in decimal degrees. Format-neutral: any image format that records where it was
/// captured supplies one.
public struct Coordinate: Equatable, Sendable
{
    /// The latitude, in decimal degrees (positive north).
    public let latitude: Double

    /// The longitude, in decimal degrees (positive east).
    public let longitude: Double

    /// Creates a coordinate.
    ///
    /// - Parameters:
    ///   - latitude:  The latitude, in decimal degrees.
    ///   - longitude: The longitude, in decimal degrees.
    public init( latitude: Double, longitude: Double )
    {
        self.latitude  = latitude
        self.longitude = longitude
    }

    /// Creates an observing-site coordinate, treating an all-zero pair as *no
    /// location*.
    ///
    /// A latitude and longitude of exactly `0°, 0°` — "Null Island" in the Gulf of
    /// Guinea — is the sentinel many cameras and metadata parsers emit when they
    /// have no GPS fix, not a real observing site, so it is rejected. A site
    /// genuinely on the equator *or* the prime meridian (only one component zero) is
    /// kept, since exactly one zero is a legitimate position.
    ///
    /// - Parameters:
    ///   - latitude:  The latitude, in decimal degrees.
    ///   - longitude: The longitude, in decimal degrees.
    /// - Returns: The coordinate, or `nil` when both components are zero.
    public static func location( latitude: Double, longitude: Double ) -> Coordinate?
    {
        guard latitude != 0 || longitude != 0
        else
        {
            return nil
        }

        return Coordinate( latitude: latitude, longitude: longitude )
    }
}
