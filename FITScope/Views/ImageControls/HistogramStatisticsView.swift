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

public struct HistogramStatisticsView: View
{
    private struct Descriptor: Hashable
    {
        public let label:        String
        public let provideValue: ( HistogramStatistics ) -> String

        func hash( into hasher: inout Hasher )
        {
            hasher.combine( self.label )
        }

        static func == ( lhs: Descriptor, rhs: Descriptor ) -> Bool
        {
            lhs.label == rhs.label
        }
    }

    public let statistics: [ HistogramStatistics ]
    public let mode:       HistogramControlView.Mode

    private let descriptors =
        [
            Descriptor( label: "Mean",   provideValue: { String( format: "%.1f", $0.mean ) } ),
            Descriptor( label: "StdDev", provideValue: { String( format: "%.1f", $0.stdDev ) } ),
            Descriptor( label: "Median", provideValue: { "\( $0.median )" } ),
            Descriptor( label: "Min",    provideValue: { "\( $0.min )" } ),
            Descriptor( label: "Max",    provideValue: { "\( $0.max )" } ),
            Descriptor( label: "P1",     provideValue: { "\( $0.percentile1 )" } ),
            Descriptor( label: "P99",    provideValue: { "\( $0.percentile99 )" } ),
            Descriptor( label: "Count",  provideValue: { "\( $0.count )" } ),
        ]

    public var body: some View
    {
        Grid( alignment: .leading )
        {
            ForEach( self.descriptors, id: \.self )
            {
                descriptor in

                GridRow
                {
                    Text( descriptor.label + ":" )
                        .font( .caption )
                        .gridColumnAlignment( .trailing )

                    ForEach( self.statistics.indices, id: \.self )
                    {
                        index in

                        let value        = descriptor.provideValue( self.statistics[ index ] )
                        let color: Color = mode == .luminance ? .gray : [ Color.red, .green, .blue ][ index ]

                        Text( value )
                            .font( .caption2 )
                            .foregroundColor( color )
                    }
                }
            }
        }
    }
}

#Preview
{
    let bytes          = PreviewHelper.generateRandomRGBData( count: 1024 )
    let rgb            = Histogram( bytes: bytes, mode: .rgb )
    let luminance      = Histogram( bytes: bytes, mode: .luminance )
    let statsRed       = HistogramStatistics( data: rgb.data[ 0 ] )
    let statsGreen     = HistogramStatistics( data: rgb.data[ 1 ] )
    let statsBlue      = HistogramStatistics( data: rgb.data[ 2 ] )
    let statsLuminance = HistogramStatistics( data: luminance.data[ 0 ] )

    VStack( alignment: .leading )
    {
        HistogramStatisticsView( statistics: [ statsRed, statsGreen, statsBlue ], mode: .rgb )
        Divider()
        HistogramStatisticsView( statistics: [ statsLuminance ], mode: .luminance )
    }
    .padding()
}
