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

/// Draws a histogram as filled area curves, either overlaying the RGB channels
/// (semi-transparent) or stacking them in three separate strips.
public struct HistogramView: View
{
    /// The histograms to draw.
    public let histogram:        FITSImageRenderer.Histogram

    /// Whether to draw the RGB channels in separate stacked strips rather than
    /// overlaid. Only honoured in RGB mode.
    public let separateChannels: Bool

    /// Which histogram (RGB or luminance) to draw.
    public let mode:             HistogramControlView.Mode

    /// The view's content.
    public var body: some View
    {
        GeometryReader
        {
            geometry in

            let data     = self.data
            let maxCount = max( 1, data.flatMap { $0 }.max() ?? 1 )

            ZStack
            {
                if self.separateChannels && self.mode == .rgb
                {
                    VStack( spacing: 0 )
                    {
                        ForEach( 0 ..< 3, id: \.self )
                        {
                            index in

                            Canvas
                            {
                                context, size in

                                let path = Self.path( data: data[ index ], size: size, maxCount: maxCount )

                                context.fill( path, with: .color( self.color( index: index ) ) )
                            }
                            .frame( height: geometry.size.height / 3 )
                        }
                    }
                }
                else
                {
                    ForEach( 0 ..< data.count, id: \.self )
                    {
                        index in

                        Self.path( data: data[ index ], size: geometry.size, maxCount: maxCount )
                            .fill( self.color( index: index ).opacity( self.opacity ) )
                    }
                }
            }
        }
    }

    /// The fill colour for a channel by index.
    ///
    /// - Parameter index: The channel index (0…2 for red/green/blue).
    /// - Returns: Grey in luminance mode, the matching RGB colour otherwise, or
    ///   `.clear` for an out-of-range index.
    private func color( index: Int ) -> Color
    {
        guard index <= 2
        else
        {
            return .clear
        }

        switch self.mode
        {
            case .luminance: return .gray
            case .rgb:       return [ .red, .green, .blue ][ index ]
        }
    }

    /// The fill opacity for the curves: fully opaque except for overlaid RGB
    /// channels, which are made translucent so overlaps stay visible.
    private var opacity: Double
    {
        switch self.mode
        {
            case .luminance: return 1
            case .rgb:       return self.separateChannels ? 1 : 0.5
        }
    }

    /// The per-channel bin counts for the current mode.
    private var data: [ [ Int ] ]
    {
        switch self.mode
        {
            case .luminance: return self.histogram.luminance.data
            case .rgb:       return self.histogram.rgb.data
        }
    }

    /// Builds a closed area path tracing one channel's bin counts across the
    /// given size, with the baseline along the bottom edge.
    ///
    /// - Parameters:
    ///   - data:     The bin counts for one channel.
    ///   - size:     The drawing area.
    ///   - maxCount: The largest bin count across all channels, used to scale
    ///               the heights consistently.
    /// - Returns: The filled histogram path.
    static func path( data: [ Int ], size: CGSize, maxCount: Int ) -> Path
    {
        let binWidth = size.width / CGFloat( data.count )

        return Path
        {
            path in

            path.move( to: CGPoint( x: 0, y: size.height ) )

            data.enumerated().forEach
            {
                let x = CGFloat( $0.offset ) * binWidth
                let y = Self.yPosition( count: $0.element, maxCount: maxCount, height: size.height )
                path.addLine( to: CGPoint( x: x, y: y ))
            }

            path.addLine( to: CGPoint( x: size.width, y: size.height ))
            path.closeSubpath()
        }
    }

    /// The y-coordinate of a histogram bar, with the bin count normalized
    /// against the largest bin. Guards against an all-zero histogram, where the
    /// maximum count is `0`, to avoid a divide-by-zero producing `NaN`.
    static func yPosition( count: Int, maxCount: Int, height: CGFloat ) -> CGFloat
    {
        height - CGFloat( count ) / CGFloat( max( 1, maxCount ) ) * height
    }
}

#Preview
{
    let histogram = PreviewHelper.histogram()

    VStack( alignment: .leading )
    {
        HistogramView( histogram: histogram, separateChannels: false, mode: .rgb )
        Divider()
        HistogramView( histogram: histogram, separateChannels: true,  mode: .rgb )
        Divider()
        HistogramView( histogram: histogram, separateChannels: false, mode: .luminance )
    }
    .frame( maxWidth: .infinity, alignment: .leading )
    .frame( maxHeight: .infinity, alignment: .top )
    .padding()
}
