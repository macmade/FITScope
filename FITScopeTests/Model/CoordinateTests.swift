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
import Testing

/// Tests ``Coordinate/location(latitude:longitude:)``, the shared observing-site
/// factory that treats an all-zero pair as no location — the single rule every
/// format's GPS/site-coordinate extraction routes through.
@Suite( "Coordinate" )
struct CoordinateTests
{
    /// An all-zero pair is the "no fix" sentinel and yields no location.
    @Test
    func zeroPairIsNoLocation()
    {
        #expect( Coordinate.location( latitude: 0, longitude: 0 ) == nil )
    }

    /// A site on the equator (zero latitude only) is a real location.
    @Test
    func equatorIsALocation()
    {
        #expect( Coordinate.location( latitude: 0, longitude: 12.5 ) == Coordinate( latitude: 0, longitude: 12.5 ) )
    }

    /// A site on the prime meridian (zero longitude only) is a real location.
    @Test
    func primeMeridianIsALocation()
    {
        #expect( Coordinate.location( latitude: 48.85, longitude: 0 ) == Coordinate( latitude: 48.85, longitude: 0 ) )
    }

    /// A fully non-zero pair passes through unchanged.
    @Test
    func nonZeroPairIsKept()
    {
        #expect( Coordinate.location( latitude: -33.87, longitude: 151.2 ) == Coordinate( latitude: -33.87, longitude: 151.2 ) )
    }
}
