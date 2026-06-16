/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2025, Jean-David Gadina - www.xs-labs.com
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
import Testing
@testable import FITScope

/// Tests for `CursorReadout` value formatting.
@Suite( "CursorReadout" )
struct CursorReadoutTests
{
    @Test
    func formatsValueWithPercentWhenFractionPresent() throws
    {
        let readout = CursorReadout( x: 3120, y: 2080, value: 1823, fraction: 1823.0 / 65535.0 )

        #expect( readout.xText == "x: 3120" )
        #expect( readout.yText == "y: 2080" )
        #expect( readout.valueText == "Value: 1823 (2.78%)" )
    }

    @Test
    func formatsValueWithoutPercentWhenFractionNil() throws
    {
        let readout = CursorReadout( x: 0, y: 0, value: 0.5, fraction: nil )

        #expect( readout.valueText == "Value: 0.5" )
    }

    @Test
    func emptyReadoutShowsPlaceholders() throws
    {
        let readout = CursorReadout.empty

        #expect( readout.xText == "x: —" )
        #expect( readout.yText == "y: —" )
        #expect( readout.valueText == "Value: —" )
    }
}
