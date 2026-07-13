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

/// Tests for ``ImageComparisonLayer``: the guard that keeps the before-image
/// reveal from clipping to an empty region (which makes Core Graphics log
/// "clip: empty path.").
@Suite( "ImageComparisonLayer" )
struct ImageComparisonLayerTests
{
    /// A positive divider position with a positive height has a region to reveal.
    @Test
    func revealsBeforeImageWhenThereIsARegion()
    {
        #expect( ImageComparisonLayer.revealsBeforeImage( dividerX: 120, height: 200 ) )
    }

    /// At the far-left divider position (`dividerX == 0`) there is nothing to
    /// reveal, so the clip is skipped rather than clipping to an empty rect.
    @Test
    func doesNotRevealAtTheFarLeftDivider()
    {
        #expect( ImageComparisonLayer.revealsBeforeImage( dividerX: 0, height: 200 ) == false )
    }

    /// A transient zero-height layout has no region to reveal either.
    @Test
    func doesNotRevealAtZeroHeight()
    {
        #expect( ImageComparisonLayer.revealsBeforeImage( dividerX: 120, height: 0 ) == false )
    }
}
