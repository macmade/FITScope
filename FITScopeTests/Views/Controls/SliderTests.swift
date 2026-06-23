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

/// Tests for `Slider`'s pure knob-position helper.
@Suite( "Slider" )
struct SliderTests
{
    /// A value within the bounds maps linearly to its normalized position.
    @Test
    @MainActor
    func normalizedPositionMapsValueWithinBounds() throws
    {
        #expect( Slider.normalizedPosition( value: 25, minimumValue: 0, maximumValue: 100 ) == 0.25 )
    }

    /// Equal bounds give a zero range; the normalized position must stay finite
    /// rather than dividing into `NaN`, which would leave the knob unplaceable.
    @Test
    @MainActor
    func normalizedPositionHandlesEqualBounds() throws
    {
        let position = Slider.normalizedPosition( value: 5, minimumValue: 5, maximumValue: 5 )

        #expect( position.isFinite, "equal bounds must not produce NaN" )
        #expect( position == 0 )
    }
}
