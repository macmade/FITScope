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
import Testing

/// Tests for ``CompassDirection``: the 16-point compass abbreviation for an
/// azimuth.
@Suite( "CompassDirection" )
struct CompassDirectionTests
{
    /// The four cardinal directions sit at 0/90/180/270°.
    @Test
    func cardinalDirections()
    {
        #expect( CompassDirection.abbreviation( forAzimuth: 0 ) == "N" )
        #expect( CompassDirection.abbreviation( forAzimuth: 90 ) == "E" )
        #expect( CompassDirection.abbreviation( forAzimuth: 180 ) == "S" )
        #expect( CompassDirection.abbreviation( forAzimuth: 270 ) == "W" )
    }

    /// The intercardinal and secondary-intercardinal points.
    @Test
    func intercardinalDirections()
    {
        #expect( CompassDirection.abbreviation( forAzimuth: 45 ) == "NE" )
        #expect( CompassDirection.abbreviation( forAzimuth: 135 ) == "SE" )
        #expect( CompassDirection.abbreviation( forAzimuth: 225 ) == "SW" )
        #expect( CompassDirection.abbreviation( forAzimuth: 315 ) == "NW" )
        #expect( CompassDirection.abbreviation( forAzimuth: 22.5 ) == "NNE" )
    }

    /// An azimuth of 360° (or just under) wraps back to north.
    @Test
    func wrapsAtFullCircle()
    {
        #expect( CompassDirection.abbreviation( forAzimuth: 360 ) == "N" )
        #expect( CompassDirection.abbreviation( forAzimuth: 359 ) == "N" )
    }

    /// A negative azimuth is normalized before mapping (−90° is due west).
    @Test
    func normalizesNegativeAzimuth()
    {
        #expect( CompassDirection.abbreviation( forAzimuth: -90 ) == "W" )
    }
}
