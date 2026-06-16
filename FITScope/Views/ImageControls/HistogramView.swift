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
                HistogramGridView()

                if self.separateChannels && self.mode == .rgb
                {
                    VStack( spacing: 0 )
                    {
                        ForEach( 0 ..< 3, id: \.self )
                        {
                            index in

                            self.channel( data: data[ index ], index: index, maxCount: maxCount, size: CGSize( width: geometry.size.width, height: geometry.size.height / 3 ) )
                                .frame( height: geometry.size.height / 3 )
                        }
                    }
                }
                else
                {
                    ForEach( 0 ..< data.count, id: \.self )
                    {
                        index in

                        self.channel( data: data[ index ], index: index, maxCount: maxCount, size: geometry.size )
                    }
                }
            }
        }
    }

    /// One channel's area, drawn as a vertical gradient fill beneath a crisp top
    /// stroke so the curve reads clearly against the dark background.
    ///
    /// - Parameters:
    ///   - data:     The bin counts for the channel.
    ///   - index:    The channel index (0…2 for red/green/blue).
    ///   - maxCount: The largest bin count across all channels.
    ///   - size:     The drawing area.
    /// - Returns: The composited fill-and-stroke for the channel.
    @ViewBuilder
    private func channel( data: [ Int ], index: Int, maxCount: Int, size: CGSize ) -> some View
    {
        let base = self.color( index: index )

        ZStack
        {
            Self.path( data: data, size: size, maxCount: maxCount )
                .fill(
                    LinearGradient(
                        colors:     [ base.opacity( self.fillTopOpacity ), base.opacity( 0.04 ) ],
                        startPoint: .top,
                        endPoint:   .bottom
                    )
                )

            Self.linePath( data: data, size: size, maxCount: maxCount )
                .stroke( base.opacity( 0.9 ), style: StrokeStyle( lineWidth: 1, lineJoin: .round ) )
        }
    }

    /// The opacity of the area fill at the top of the curve: lower for overlaid
    /// RGB channels so their overlaps stay legible.
    private var fillTopOpacity: Double
    {
        switch self.mode
        {
            case .luminance: return 0.5
            case .rgb:       return self.separateChannels ? 0.5 : 0.35
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

    /// Builds an open path tracing only the top of one channel's bin counts,
    /// without the baseline closure, so it can be stroked as a clean outline.
    ///
    /// - Parameters:
    ///   - data:     The bin counts for one channel.
    ///   - size:     The drawing area.
    ///   - maxCount: The largest bin count across all channels.
    /// - Returns: The open histogram outline.
    static func linePath( data: [ Int ], size: CGSize, maxCount: Int ) -> Path
    {
        let binWidth = size.width / CGFloat( data.count )

        return Path
        {
            path in

            data.enumerated().forEach
            {
                let x     = CGFloat( $0.offset ) * binWidth
                let y     = Self.yPosition( count: $0.element, maxCount: maxCount, height: size.height )
                let point = CGPoint( x: x, y: y )

                if $0.offset == 0
                {
                    path.move( to: point )
                }
                else
                {
                    path.addLine( to: point )
                }
            }
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

/// A faint reference grid drawn behind the histogram curves: four columns and
/// four rows of hairlines, kept subtle so they read as guides, not chrome.
struct HistogramGridView: View
{
    /// The number of equal columns and rows the grid is divided into.
    private let divisions = 4

    /// The view's content.
    var body: some View
    {
        GeometryReader
        {
            geometry in

            Path
            {
                path in

                ( 1 ..< self.divisions ).forEach
                {
                    let x = geometry.size.width * CGFloat( $0 ) / CGFloat( self.divisions )

                    path.move( to: CGPoint( x: x, y: 0 ) )
                    path.addLine( to: CGPoint( x: x, y: geometry.size.height ) )
                }

                ( 1 ..< self.divisions ).forEach
                {
                    let y = geometry.size.height * CGFloat( $0 ) / CGFloat( self.divisions )

                    path.move( to: CGPoint( x: 0, y: y ) )
                    path.addLine( to: CGPoint( x: geometry.size.width, y: y ) )
                }
            }
            .stroke( Color.white.opacity( 0.06 ), lineWidth: 0.5 )
        }
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
