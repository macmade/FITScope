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

import CoreGraphics
@testable import FITScope
import Testing

/// Tests for `BinaryFloatingPoint.isApproximatelyEqual(to:tolerance:)`, used to
/// decide whether an adjustment sits at its neutral value.
@Suite( "BinaryFloatingPoint" )
struct BinaryFloatingPointTests
{
    /// Values within the default tolerance compare equal; a perceptible
    /// difference does not.
    @Test
    func approximateEqualityUsesTheDefaultTolerance()
    {
        #expect( 1.0.isApproximatelyEqual( to: 1.0 ) )
        #expect( ( 1.0 + 1e-9 ).isApproximatelyEqual( to: 1.0 ) )
        #expect( ( 1.0 - 1e-9 ).isApproximatelyEqual( to: 1.0 ) )
        #expect( 0.0.isApproximatelyEqual( to: 0.0 ) )
        #expect( ( -1e-9 ).isApproximatelyEqual( to: 0.0 ) )

        #expect( 1.5.isApproximatelyEqual( to: 1.0 ) == false )
        #expect( 1.01.isApproximatelyEqual( to: 1.0 ) == false )
    }

    /// An explicit tolerance overrides the default in both directions, and the
    /// boundary itself compares equal.
    @Test
    func toleranceIsConfigurable()
    {
        #expect( 1.1.isApproximatelyEqual( to: 1.0, tolerance: 0.2 ) )
        #expect( 1.1.isApproximatelyEqual( to: 1.0, tolerance: 0.05 ) == false )
        #expect( 1.2.isApproximatelyEqual( to: 1.0, tolerance: 0.2 ) )
    }

    /// The helper is generic over the floating-point type, so it works for
    /// `Float` and `CGFloat` as well as `Double`.
    @Test
    func worksForOtherFloatingPointTypes()
    {
        let float: Float = 1.0 + 1e-7

        #expect( float.isApproximatelyEqual( to: 1.0 ) )
        #expect( CGFloat( 1.0 ).isApproximatelyEqual( to: 1.0 ) )
        #expect( Float( 1.5 ).isApproximatelyEqual( to: 1.0 ) == false )
    }
}
