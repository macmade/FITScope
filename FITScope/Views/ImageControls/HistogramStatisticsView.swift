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

/// A grid of histogram statistics — mean, standard deviation, median, min, max,
/// percentiles and pixel count — with one column per channel for the current
/// mode (three for RGB, one for luminance).
public struct HistogramStatisticsView: View
{
    /// One labelled statistic row, pairing a display label with a closure that
    /// extracts and formats the value from a channel's statistics.
    private struct Descriptor: Hashable
    {
        /// The label shown for the statistic (e.g. `"Mean"`).
        public let label:        String

        /// Extracts and formats the statistic from a channel's statistics.
        public let provideValue: ( HistogramStatistics ) -> String

        /// Hashes the descriptor by its label, since the closure is not
        /// hashable.
        ///
        /// - Parameter hasher: The hasher to feed.
        func hash( into hasher: inout Hasher )
        {
            hasher.combine( self.label )
        }

        /// Compares descriptors by label, since the closure is not equatable.
        ///
        /// - Parameters:
        ///   - lhs: The first descriptor.
        ///   - rhs: The second descriptor.
        /// - Returns: `true` when the labels are equal.
        static func == ( lhs: Descriptor, rhs: Descriptor ) -> Bool
        {
            lhs.label == rhs.label
        }
    }

    /// The per-channel statistics to display.
    public let statistics: FITSImageRenderer.HistogramStatistics

    /// Whether to show RGB channels or a single luminance channel.
    public let mode:       HistogramControlView.Mode

    /// The ordered statistic rows displayed in the grid.
    private let descriptors =
        [
            Descriptor( label: "Mean",    provideValue: { StatisticsFormat.decimal( $0.mean ) } ),
            Descriptor( label: "Std Dev", provideValue: { StatisticsFormat.decimal( $0.stdDev ) } ),
            Descriptor( label: "Median",  provideValue: { StatisticsFormat.integerGrouped( $0.median ) } ),
            Descriptor( label: "Min",     provideValue: { StatisticsFormat.integerGrouped( $0.min ) } ),
            Descriptor( label: "Max",     provideValue: { StatisticsFormat.integerGrouped( $0.max ) } ),
            Descriptor( label: "P1",      provideValue: { StatisticsFormat.integerGrouped( $0.percentile1 ) } ),
            Descriptor( label: "P99",     provideValue: { StatisticsFormat.integerGrouped( $0.percentile99 ) } ),
            Descriptor( label: "Count",   provideValue: { StatisticsFormat.integerGrouped( $0.count ) } ),
        ]

    /// The view's content.
    public var body: some View
    {
        Grid( alignment: .leading, horizontalSpacing: 16, verticalSpacing: 5 )
        {
            ForEach( self.descriptors, id: \.self )
            {
                descriptor in

                GridRow( alignment: .firstTextBaseline )
                {
                    Text( descriptor.label )
                        .font( .caption )
                        .foregroundStyle( .secondary )
                        .gridColumnAlignment( .leading )

                    let statistics =
                    {
                        switch self.mode
                        {
                            case .rgb:       return [ self.statistics.red, self.statistics.green, self.statistics.blue ]
                            case .luminance: return [ self.statistics.luminance ]
                        }
                    }()

                    ForEach( statistics.indices, id: \.self )
                    {
                        index in

                        let value        = descriptor.provideValue( statistics[ index ] )
                        let color: Color = mode == .luminance ? .primary : [ Color.red, .green, .blue ][ index ]

                        Text( value )
                            .font( .system( .caption2, design: .monospaced ) )
                            .foregroundStyle( color )
                            .gridColumnAlignment( .trailing )
                    }
                }
            }
        }
    }
}

#Preview
{
    let statistics = PreviewHelper.statistics()

    VStack( alignment: .leading )
    {
        HistogramStatisticsView( statistics: statistics, mode: .rgb )
        Divider()
        HistogramStatisticsView( statistics: statistics, mode: .luminance )
    }
    .frame( maxWidth: .infinity, alignment: .leading )
    .frame( maxHeight: .infinity, alignment: .top )
    .padding()
}
