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

/// Pure formatting helpers for statistics values.
public enum StatisticsFormat
{
    /// Formats a value with two fractional digits (e.g. `567.32`).
    public static func decimal( _ value: Double ) -> String
    {
        String( format: "%.2f", value )
    }

    /// Formats an integer with locale grouping (e.g. `25,958,400`).
    public static func integerGrouped( _ value: Int ) -> String
    {
        let formatter = NumberFormatter()

        formatter.numberStyle = .decimal

        return formatter.string( from: NSNumber( value: value ) ) ?? String( value )
    }
}

/// The statistics section: mean, median, standard deviation, min, max and pixel
/// count for the luminance channel of the rendered image.
public struct StatisticsView: View
{
    /// The per-channel statistics; the luminance channel is shown.
    public let statistics: FITSImageRenderer.HistogramStatistics

    /// Creates the statistics view.
    ///
    /// - Parameter statistics: The statistics to display.
    public init( statistics: FITSImageRenderer.HistogramStatistics )
    {
        self.statistics = statistics
    }

    /// The view's content.
    public var body: some View
    {
        let stats = self.statistics.luminance

        VStack( spacing: 5 )
        {
            self.row( "Mean",    StatisticsFormat.decimal( stats.mean ) )
            self.row( "Median",  String( stats.median ) )
            self.row( "Std Dev", StatisticsFormat.decimal( stats.stdDev ) )
            self.row( "Min",     String( stats.min ) )
            self.row( "Max",     String( stats.max ) )
            self.row( "Pixels",  StatisticsFormat.integerGrouped( stats.count ) )
        }
    }

    /// A label/value row.
    private func row( _ label: String, _ value: String ) -> some View
    {
        HStack
        {
            Text( label )
                .foregroundStyle( .secondary )

            Spacer()

            Text( value )
                .font( .system( .body, design: .monospaced ) )
        }
        .font( .system( size: 11 ) )
    }
}

#Preview
{
    StatisticsView( statistics: PreviewHelper.statistics() )
        .frame( width: 255 )
        .padding()
}
