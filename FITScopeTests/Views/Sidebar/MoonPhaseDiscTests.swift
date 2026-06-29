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
import SwiftUI
import Testing

/// Tests for ``MoonPhaseDisc``'s lit-region geometry: that the illuminated side
/// and extent track the phase (the crescent/gibbous shaping is verified visually).
@Suite( "MoonPhaseDisc" )
struct MoonPhaseDiscTests
{
    /// A 100×100 disc: centre (50, 50), radius 50.
    private static let rect = CGRect( x: 0, y: 0, width: 100, height: 100 )

    /// The full moon's lit region covers the whole disc.
    @Test
    func fullMoonCoversTheDisc()
    {
        let box = MoonPhaseDisc.litPath( in: Self.rect, fraction: 0.5 ).boundingRect

        #expect( box.minX < 1 )
        #expect( box.maxX > 99 )
        #expect( box.height > 99 )
    }

    /// The first quarter is lit on the right half (terminator down the centre).
    @Test
    func firstQuarterIsLitOnTheRight()
    {
        let box = MoonPhaseDisc.litPath( in: Self.rect, fraction: 0.25 ).boundingRect

        #expect( box.minX > 49 )
        #expect( box.maxX > 99 )
        #expect( box.height > 99 )
    }

    /// The last quarter is lit on the left half.
    @Test
    func lastQuarterIsLitOnTheLeft()
    {
        let box = MoonPhaseDisc.litPath( in: Self.rect, fraction: 0.75 ).boundingRect

        #expect( box.maxX < 51 )
        #expect( box.minX < 1 )
        #expect( box.height > 99 )
    }

    /// The new moon's shadow covers the whole disc.
    @Test
    func newMoonShadowCoversTheDisc()
    {
        let box = MoonPhaseDisc.shadowPath( in: Self.rect, fraction: 0 ).boundingRect

        #expect( box.minX < 1 )
        #expect( box.maxX > 99 )
        #expect( box.height > 99 )
    }

    /// At the first quarter the shadow is on the left — opposite the lit right.
    @Test
    func firstQuarterShadowIsOnTheLeft()
    {
        let box = MoonPhaseDisc.shadowPath( in: Self.rect, fraction: 0.25 ).boundingRect

        #expect( box.maxX < 51 )
        #expect( box.minX < 1 )
        #expect( box.height > 99 )
    }
}
