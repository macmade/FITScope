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

public struct HistogramControlView: View
{
    public enum Mode: String, CaseIterable, Identifiable
    {
        case rgb       = "RGB"
        case luminance = "Luminance"

        public var id: String
        {
            self.rawValue
        }
    }

    @State private var separateChannels = false
    @State private var statistics       = false
    @State private var mode             = Mode.rgb

    public let bytes: [ UInt8 ]

    private var histogram: Histogram
    {
        switch self.mode
        {
            case .rgb:       Histogram( bytes: self.bytes, mode: .rgb )
            case .luminance: Histogram( bytes: self.bytes, mode: .luminance )
        }
    }

    public var body: some View
    {
        VStack( alignment: .leading )
        {
            Picker( "Mode", selection: $mode )
            {
                ForEach( Mode.allCases )
                {
                    Text( $0.rawValue ).tag( $0 )
                }
            }
            .labelsHidden()
            .pickerStyle( SegmentedPickerStyle() )

            HistogramView(
                histogram:        self.histogram.data,
                separateChannels: self.separateChannels && self.mode == .rgb,
                mode:             self.mode
            )
            .frame( height: 100 )

            Toggle( "Separate Channels", isOn: $separateChannels )
                .disabled( self.mode == .luminance )

            Toggle( "Statistics", isOn: $statistics )

            if self.statistics
            {
                HistogramStatisticsView( statistics: self.histogram.data.map( HistogramStatistics.init ), mode: self.mode )
                    .padding( .vertical )
            }
        }
    }
}

#Preview
{
    HistogramControlView( bytes: PreviewHelper.generateRandomRGBData( count: 1024 ) )
        .fixedSize( horizontal: false, vertical: true )
        .padding()
}
