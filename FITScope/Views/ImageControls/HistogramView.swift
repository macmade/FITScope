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

struct HistogramView: View
{
    let histogram:        [ [ Int ] ]
    let separateChannels: Bool
    let mode:             HistogramControlView.Mode

    var body: some View
    {
        GeometryReader
        {
            geometry in

            let maxCount = self.maxCount

            ZStack
            {
                if self.histogram.count == 3 && separateChannels && self.mode == .rgb
                {
                    VStack( spacing: 0 )
                    {
                        ForEach( 0 ..< 3, id: \.self )
                        {
                            index in

                            let color = [ Color.red, .green, .blue ][ index ]

                            Canvas
                            {
                                context, size in

                                let path = Self.path( data: histogram[ index ], size: size, maxCount: maxCount )

                                context.fill( path, with: .color( color.opacity( 0.5 ) ) )
                            }
                            .frame( height: geometry.size.height / 3 )
                        }
                    }
                }
                else
                {
                    ForEach( 0 ..< histogram.count, id: \.self )
                    {
                        index in

                        let color: Color = mode == .luminance ? .gray : [ Color.red, .green, .blue ][ index ]

                        Self.path( data: histogram[ index ], size: geometry.size, maxCount: maxCount )
                            .fill( color.opacity( 0.5 ) )
                    }
                }
            }
        }
    }

    var maxCount: Int
    {
        self.histogram.flatMap { $0 }.max() ?? 1
    }

    private static func path( data: [ Int ], size: CGSize, maxCount: Int ) -> Path
    {
        let binWidth = size.width / CGFloat( data.count )

        return Path
        {
            path in

            path.move( to: CGPoint( x: 0, y: size.height ) )

            data.enumerated().forEach
            {
                let x = CGFloat( $0.offset ) * binWidth
                let y = size.height - CGFloat( $0.element ) / CGFloat( maxCount ) * size.height
                path.addLine( to: CGPoint( x: x, y: y ))
            }

            path.addLine( to: CGPoint( x: size.width, y: size.height ))
            path.closeSubpath()
        }
    }
}

#Preview
{
    let bytes     = PreviewHelper.generateRandomRGBData( count: 1024 )
    let rgb       = Histogram( bytes: bytes, mode: .rgb )
    let luminance = Histogram( bytes: bytes, mode: .luminance )

    VStack( alignment: .leading )
    {
        HistogramView( histogram: rgb.data, separateChannels: false, mode: .rgb )
        Divider()
        HistogramView( histogram: rgb.data, separateChannels: true,  mode: .rgb )
        Divider()
        HistogramView( histogram: luminance.data, separateChannels: false, mode: .luminance )
    }
    .padding()
}
