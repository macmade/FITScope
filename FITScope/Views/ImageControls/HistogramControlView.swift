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

import SwiftPixel
import SwiftUI

/// The histogram section of the controls panel: a mode picker (RGB vs
/// luminance), the ``HistogramView`` itself, and toggles for separating the
/// colour channels and showing summary statistics.
public struct HistogramControlView: View
{
    /// Which histogram is displayed.
    public enum Mode: CaseIterable, CustomStringConvertible
    {
        /// The per-channel red/green/blue histogram.
        case rgb

        /// The single-channel luminance histogram.
        case luminance

        /// The picker label for the mode.
        public var description: String
        {
            switch self
            {
                case .rgb:       return "RGB"
                case .luminance: return "Luminance"
            }
        }
    }

    /// Whether the RGB channels are drawn stacked separately rather than
    /// overlaid. Has no effect in luminance mode.
    @State private var separateChannels = false

    /// Whether the summary statistics panel is shown.
    @State private var showStatistics   = false

    /// The currently displayed histogram mode.
    @State private var mode             = Mode.rgb

    /// The histograms to display.
    public let histogram:  FITSImageRenderer.Histogram

    /// The per-channel statistics shown when statistics are enabled.
    public let statistics: FITSImageRenderer.HistogramStatistics

    /// The view's content.
    public var body: some View
    {
        VStack( alignment: .leading )
        {
            SegmentedControlView( selection: self.$mode, values: Mode.allCases, title: { $0.description } )

            HistogramView(
                histogram:        self.histogram,
                separateChannels: self.separateChannels && self.mode == .rgb,
                mode:             self.mode
            )
            .frame( height: 110 )
            .padding( 6 )
            .background( Color.black.opacity( 0.35 ) )
            .clipShape( RoundedRectangle( cornerRadius: 10 ) )
            .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .white.opacity( 0.08 ), lineWidth: 1 ) )

            Toggle( "Separate Channels", isOn: $separateChannels )
                .disabled( self.mode == .luminance )

            Toggle( "Statistics", isOn: $showStatistics )

            if self.showStatistics
            {
                HStack
                {
                    HistogramStatisticsView( statistics: self.statistics, mode: self.mode )
                        .padding( 12 )
                }
                .frame( maxWidth: .infinity, alignment: .leading )
                .background( Color.black.opacity( 0.35 ) )
                .clipShape( RoundedRectangle( cornerRadius: 10 ) )
                .overlay( RoundedRectangle( cornerRadius: 10 ).strokeBorder( .white.opacity( 0.08 ), lineWidth: 1 ) )
            }
        }
    }
}

#Preview
{
    HistogramControlView( histogram: PreviewHelper.histogram(), statistics: PreviewHelper.statistics() )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}
