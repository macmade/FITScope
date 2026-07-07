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

/// Tests for ``ImageCarouselView``'s pure helpers: the per-frame label and the
/// clamped keyboard-navigation neighbour index.
@Suite( "ImageCarouselView" )
struct ImageCarouselViewTests
{
    /// A frame with no title falls back to its 1-based position; a titled frame
    /// uses its title.
    @Test
    func labelFallsBackToFrameNumber()
    {
        #expect( ImageCarouselView.label( title: nil, index: 0 ) == "Frame 1" )
        #expect( ImageCarouselView.label( title: nil, index: 4 ) == "Frame 5" )
        #expect( ImageCarouselView.label( title: "Hα", index: 2 ) == "Hα" )
    }

    /// Keyboard navigation clamps to the ends rather than wrapping around.
    @Test
    func neighborIndexClampsToBounds()
    {
        #expect( ImageCarouselView.neighborIndex( from: 0, offset: -1, count: 3 ) == 0 )
        #expect( ImageCarouselView.neighborIndex( from: 0, offset:  1, count: 3 ) == 1 )
        #expect( ImageCarouselView.neighborIndex( from: 1, offset: -1, count: 3 ) == 0 )
        #expect( ImageCarouselView.neighborIndex( from: 2, offset:  1, count: 3 ) == 2 )
    }

    /// An empty or single-frame list yields no valid neighbour, staying put.
    @Test
    func neighborIndexHandlesDegenerateCounts()
    {
        #expect( ImageCarouselView.neighborIndex( from: 0, offset:  1, count: 1 ) == 0 )
        #expect( ImageCarouselView.neighborIndex( from: 0, offset: -1, count: 0 ) == 0 )
    }
}
