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

import SwiftFITS
import SwiftUI

/// The scrollable sidebar gathering every image-adjustment control — histogram,
/// debayer, stretch, gamma and white balance — into one panel.
public struct ImageControlsView: View
{
    /// The shared adjustment values the controls bind to.
    private let adjustments: ImageAdjustments

    /// Requests a debounced re-render after an adjustment changes.
    private let reRender:    () -> Void

    /// The histograms shown at the top of the panel.
    private let histogram:   FITSImageRenderer.Histogram

    /// The per-channel statistics shown alongside the histograms.
    private let statistics:  FITSImageRenderer.HistogramStatistics

    /// Creates the controls panel.
    ///
    /// - Parameters:
    ///   - adjustments: The shared adjustment values to bind to.
    ///   - reRender:    The closure to call after an adjustment changes.
    ///   - histogram:   The histograms to display.
    ///   - statistics:  The per-channel statistics to display.
    public init( adjustments: ImageAdjustments, reRender: @escaping () -> Void, histogram: FITSImageRenderer.Histogram, statistics: FITSImageRenderer.HistogramStatistics )
    {
        self.adjustments = adjustments
        self.reRender    = reRender
        self.histogram   = histogram
        self.statistics  = statistics
    }

    /// The view's content.
    public var body: some View
    {
        ScrollView
        {
            HistogramControlView( histogram: self.histogram, statistics: self.statistics )

            Divider().padding( .vertical )

            ImageControlContainer( label: "Debayer" )
            {
                DebayerControlView( adjustments: self.adjustments, reRender: self.reRender )
            }

            Divider().padding( .vertical )

            ImageControlContainer( label: "Stretch" )
            {
                StretchControlView( adjustments: self.adjustments, reRender: self.reRender )
            }

            Divider().padding( .vertical )

            ImageControlContainer( label: "Gamma Correction" )
            {
                GammaCorrectionControlView( adjustments: self.adjustments, reRender: self.reRender )
            }

            Divider().padding( .vertical )

            ImageControlContainer( label: "White Balance" )
            {
                WhiteBalanceControlView( adjustments: self.adjustments, reRender: self.reRender )
            }
        }
    }
}

#Preview
{
    ImageControlsView( adjustments: ImageAdjustments(), reRender: {}, histogram: PreviewHelper.histogram(), statistics: PreviewHelper.statistics() )
        .padding()
}
