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
        #expect( HistogramView.yPosition( count: 0, maxCount: 0, height: 50, logScale: false ).isFinite )
        #expect( HistogramView.yPosition( count: 0, maxCount: 0, height: 50, logScale: false ) == 50 )
        #expect( HistogramView.yPosition( count: 0, maxCount: 0, height: 50, logScale: true ).isFinite )
        #expect( HistogramView.yPosition( count: 0, maxCount: 0, height: 50, logScale: true ) == 50 )
    }

    /// An empty bin is at the baseline (fraction 0) and the tallest bin fills the
    /// height (fraction 1), in both linear and logarithmic scaling.
    @Test
    @MainActor
    func barFractionPinsEndpoints() throws
    {
        #expect( HistogramView.barFraction( count: 0,   maxCount: 100, logScale: false ) == 0 )
        #expect( HistogramView.barFraction( count: 100, maxCount: 100, logScale: false ) == 1 )
        #expect( HistogramView.barFraction( count: 0,   maxCount: 100, logScale: true )  == 0 )
        #expect( abs( HistogramView.barFraction( count: 100, maxCount: 100, logScale: true ) - 1 ) < 1e-12 )
    }

    /// Bar height is monotonic in the bin count for both scalings.
    @Test
    @MainActor
    func barFractionIsMonotonic() throws
    {
        for logScale in [ false, true ]
        {
            let fractions = [ 0, 1, 10, 50, 200, 1000 ].map { HistogramView.barFraction( count: $0, maxCount: 1000, logScale: logScale ) }

            #expect( zip( fractions, fractions.dropFirst() ).allSatisfy { $0 <= $1 }, "non-monotonic for logScale=\( logScale ): \( fractions )" )
        }
    }

    /// Logarithmic scaling lifts a small bin far higher than linear scaling does —
    /// the point of the option when a few bins dominate.
    @Test
    @MainActor
    func logScaleEmphasizesSmallBins() throws
    {
        let linear = HistogramView.barFraction( count: 10, maxCount: 1000, logScale: false )
        let log    = HistogramView.barFraction( count: 10, maxCount: 1000, logScale: true )

        #expect( log > linear )
    }

    /// An all-zero histogram yields a zero, finite fraction in both scalings
    /// (no divide-by-zero into `NaN`).
    @Test
    @MainActor
    func barFractionHandlesAllZeroData() throws
    {
        #expect( HistogramView.barFraction( count: 0, maxCount: 0, logScale: false ) == 0 )
        #expect( HistogramView.barFraction( count: 0, maxCount: 0, logScale: true ) == 0 )
        #expect( HistogramView.barFraction( count: 0, maxCount: 0, logScale: true ).isFinite )
    }

    /// The vertical scale ignores the clipped end bins (0 and 255): a Screen
    /// Transfer clips the background into bin 0, and that spike must not set the
    /// scale — otherwise the real distribution collapses into an invisible sliver.
    @Test
    @MainActor
    func interiorMaxIgnoresClippedEndBins() throws
    {
        // Big clip spikes at both ends, a modest real distribution in between.
        var channel = [ Int ]( repeating: 0, count: 256 )
        channel[ 0 ]   = 100_000
        channel[ 255 ] = 50_000
        channel[ 40 ]  = 200
        channel[ 41 ]  = 300
        channel[ 42 ]  = 250

        // The scale is the interior peak (300), not the 100k bin-0 clip spike.
        #expect( HistogramView.interiorMax( [ channel ] ) == 300 )
        #expect( HistogramView.interiorMax( [ channel, channel, channel ] ) == 300 )
    }

    /// A clipped end bin whose count exceeds the interior scale is capped at the
    /// top (fraction 1) rather than producing an off-screen bar.
    @Test
    @MainActor
    func barFractionCapsAnOverscaleBin() throws
    {
        #expect( HistogramView.barFraction( count: 100_000, maxCount: 300, logScale: false ) == 1 )
        #expect( HistogramView.barFraction( count: 100_000, maxCount: 300, logScale: true )  == 1 )
    }

    /// An empty or single-bin channel yields a finite scale of at least `1`, so a
    /// degenerate histogram never divides by zero.
    @Test
    @MainActor
    func interiorMaxFloorsAtOne() throws
    {
        #expect( HistogramView.interiorMax( [] ) == 1 )
        #expect( HistogramView.interiorMax( [ [] ] ) == 1 )
        #expect( HistogramView.interiorMax( [ [ 5 ] ] ) == 1 )
        #expect( HistogramView.interiorMax( [ [ 0, 0, 0 ] ] ) == 1 )
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
