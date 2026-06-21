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

/// Tests for `HistogramView`'s pure bar-geometry helper.
@Suite( "HistogramView" )
struct HistogramViewTests
{
    /// An all-zero histogram has a maximum bin count of zero; the bar
    /// y-coordinate must stay finite rather than dividing by zero into `NaN`.
    @Test
    @MainActor
    func histogramYPositionHandlesAllZeroData() throws
    {
        #expect( HistogramView.yPosition( count: 0, maxCount: 0, height: 50 ).isFinite )
        #expect( HistogramView.yPosition( count: 0, maxCount: 0, height: 50 ) == 50 )
    }

    /// A monochrome image offers only the single "Mono" mode, so the picker shows
    /// one segment rather than the RGB-only RGB/Luminance choice.
    @Test
    @MainActor
    func monoImageOffersOnlyMonoMode() throws
    {
        #expect( HistogramControlView.Mode.availableModes( isMono: true ) == [ .mono ] )
    }

    /// A colour image offers the RGB and luminance modes, and never the mono mode.
    @Test
    @MainActor
    func colorImageOffersRGBAndLuminance() throws
    {
        #expect( HistogramControlView.Mode.availableModes( isMono: false ) == [ .rgb, .luminance ] )
    }

    /// A mono image is always shown in mono mode, whatever colour mode was stored
    /// from a previously viewed image.
    @Test
    @MainActor
    func monoImageIsAlwaysShownInMonoMode() throws
    {
        #expect( HistogramControlView.Mode.effectiveMode( stored: .rgb,       isMono: true ) == .mono )
        #expect( HistogramControlView.Mode.effectiveMode( stored: .luminance, isMono: true ) == .mono )
        #expect( HistogramControlView.Mode.effectiveMode( stored: .mono,      isMono: true ) == .mono )
    }

    /// A colour image keeps its stored colour mode, but a stale mono selection
    /// carried over from a previous mono image clamps back to RGB.
    @Test
    @MainActor
    func colorImageClampsStaleMonoSelection() throws
    {
        #expect( HistogramControlView.Mode.effectiveMode( stored: .rgb,       isMono: false ) == .rgb )
        #expect( HistogramControlView.Mode.effectiveMode( stored: .luminance, isMono: false ) == .luminance )
        #expect( HistogramControlView.Mode.effectiveMode( stored: .mono,      isMono: false ) == .rgb )
    }
}
