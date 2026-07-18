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

import Foundation
import SwiftPixel
import SwiftUI

/// Draws a histogram as filled area curves, either overlaying the RGB channels
/// (semi-transparent) or stacking them in three separate strips.
public struct HistogramView: View
{
    /// The histograms to draw.
    public let histogram: ImageRenderer.Histogram

    /// Whether to draw the RGB channels in separate stacked strips rather than
    /// overlaid. Only honoured in RGB mode.
    public let separateChannels: Bool

    /// Which histogram (RGB, luma or mono) to draw.
    public let mode: HistogramControlView.Mode

    /// Whether to scale bar heights logarithmically, lifting small bins so detail
    /// is visible when a few bins dominate. Linear when `false`.
    public let logScale: Bool

    /// Whether to draw the faint reference grid behind the curves. Turn it off
    /// when the histogram is used as a backdrop over a view that already draws its
    /// own grid (e.g. the Curves editor), so the two grids don't overlap.
    public let showsGrid: Bool

    /// Creates a histogram view.
    ///
    /// - Parameters:
    ///   - histogram:        The histograms to draw.
    ///   - separateChannels: Whether to stack the RGB channels in separate strips
    ///                       rather than overlaying them (RGB mode only).
    ///   - mode:             Which histogram (RGB, luma or mono) to draw.
    ///   - logScale:         Whether to scale bar heights logarithmically.
    ///   - showsGrid:        Whether to draw the reference grid (default `true`);
    ///                       pass `false` when overlaying another grid.
    public init( histogram: ImageRenderer.Histogram, separateChannels: Bool, mode: HistogramControlView.Mode, logScale: Bool, showsGrid: Bool = true )
    {
        self.histogram        = histogram
        self.separateChannels = separateChannels
        self.mode             = mode
        self.logScale         = logScale
        self.showsGrid        = showsGrid
    }

    /// The view's content.
    public var body: some View
    {
        GeometryReader
        {
            geometry in

            let data     = self.data
            let maxCount = Self.interiorMax( data )

            ZStack
            {
                if self.showsGrid
                {
                    HistogramGridView()
                }

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
    /// stroke so the curve reads clearly against the histogram background in both
    /// light and dark appearance.
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
            Self.path( data: data, size: size, maxCount: maxCount, logScale: self.logScale )
                .fill(
                    LinearGradient(
                        colors:     [ base.opacity( self.fillTopOpacity ), base.opacity( 0.04 ) ],
                        startPoint: .top,
                        endPoint:   .bottom
                    )
                )

            Self.linePath( data: data, size: size, maxCount: maxCount, logScale: self.logScale )
                .stroke( base.opacity( 0.9 ), style: StrokeStyle( lineWidth: 1, lineJoin: .round ) )
        }
    }

    /// The opacity of the area fill at the top of the curve: lower for overlaid
    /// RGB channels so their overlaps stay legible.
    private var fillTopOpacity: Double
    {
        switch self.mode
        {
            case .luma: return 0.5
            case .rgb:  return self.separateChannels ? 0.5 : 0.35
            case .mono: return 0.5
        }
    }

    /// The fill colour for a channel by index.
    ///
    /// - Parameter index: The channel index (0…2 for red/green/blue).
    /// - Returns: Grey in luma and mono modes, the matching RGB colour in
    ///   RGB mode, or `.clear` for an out-of-range index.
    private func color( index: Int ) -> Color
    {
        guard index <= 2
        else
        {
            return .clear
        }

        switch self.mode
        {
            case .luma: return .gray
            case .rgb:  return [ .red, .green, .blue ][ index ]
            case .mono: return .gray
        }
    }

    /// The per-channel bin counts for the current mode.
    private var data: [ [ Int ] ]
    {
        switch self.mode
        {
            case .luma: return self.histogram.luma.data
            case .rgb:  return self.histogram.rgb.data
            case .mono: return self.histogram.mono.data
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
    static func path( data: [ Int ], size: CGSize, maxCount: Int, logScale: Bool ) -> Path
    {
        let binWidth = size.width / CGFloat( data.count )

        return Path
        {
            path in

            path.move( to: CGPoint( x: 0, y: size.height ) )

            data.enumerated().forEach
            {
                let x = CGFloat( $0.offset ) * binWidth
                let y = Self.yPosition( count: $0.element, maxCount: maxCount, height: size.height, logScale: logScale )
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
    static func linePath( data: [ Int ], size: CGSize, maxCount: Int, logScale: Bool ) -> Path
    {
        let binWidth = size.width / CGFloat( data.count )

        return Path
        {
            path in

            data.enumerated().forEach
            {
                let x     = CGFloat( $0.offset ) * binWidth
                let y     = Self.yPosition( count: $0.element, maxCount: maxCount, height: size.height, logScale: logScale )
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

    /// The y-coordinate of a histogram bar, measured from the top, for a bin
    /// count normalized against the largest bin.
    ///
    /// - Parameters:
    ///   - count:    The bin's count.
    ///   - maxCount: The largest bin count across all channels.
    ///   - height:   The drawing height.
    ///   - logScale: Whether to scale logarithmically.
    /// - Returns: The bar's top y-coordinate.
    static func yPosition( count: Int, maxCount: Int, height: CGFloat, logScale: Bool ) -> CGFloat
    {
        height - Self.barFraction( count: count, maxCount: maxCount, logScale: logScale ) * height
    }

    /// The vertical scale for the curves: the tallest *interior* bin count across
    /// all channels, excluding the two end bins (0 and 255).
    ///
    /// Clipped shadows and highlights pile into those end bins — a Screen Transfer
    /// clips the background to black, so bin 0 spikes — and if that spike set the
    /// scale it would crush the entire real distribution into an invisible sliver.
    /// The end bars are instead capped at the top by ``barFraction(count:maxCount:logScale:)``,
    /// so clipping still reads without flattening everything else. Floored at `1`
    /// so an all-zero (or one-bin-per-channel) histogram yields a finite scale.
    ///
    /// - Parameter data: The per-channel bin counts.
    /// - Returns: The largest interior bin count, at least `1`.
    static func interiorMax( _ data: [ [ Int ] ] ) -> Int
    {
        max( 1, data.flatMap { $0.dropFirst().dropLast() }.max() ?? 1 )
    }

    /// The bar height as a fraction (`0…1`) of the drawing height, for a bin
    /// count normalized against the largest bin.
    ///
    /// Linear scaling is `count / maxCount`; logarithmic scaling is
    /// `ln(1 + count) / ln(1 + maxCount)`, which lifts small bins so detail stays
    /// visible when a few bins dominate. Both map an empty bin to `0` and the
    /// tallest bin to `1`. The maximum is floored at `1` so an all-zero histogram
    /// yields a finite `0` rather than dividing by zero.
    ///
    /// The result is clamped to `1`: because `maxCount` excludes the clipped end
    /// bins, an end bin's count can exceed it, and the bar is capped at the top
    /// rather than shooting off-screen.
    ///
    /// - Parameters:
    ///   - count:    The bin's count.
    ///   - maxCount: The largest interior bin count across all channels.
    ///   - logScale: Whether to scale logarithmically.
    /// - Returns: The normalized bar height in `0…1`.
    static func barFraction( count: Int, maxCount: Int, logScale: Bool ) -> CGFloat
    {
        let maxCount = max( 1, maxCount )
        let fraction = logScale
            ? log( 1.0 + Double( count ) ) / log( 1.0 + Double( maxCount ) )
            : Double( count ) / Double( maxCount )

        return CGFloat( Swift.min( 1.0, fraction ) )
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
            .stroke( Color.primary.opacity( 0.08 ), lineWidth: 0.5 )
        }
    }
}

#Preview
{
    let histogram = PreviewHelper.histogram()

    VStack( alignment: .leading )
    {
        HistogramView( histogram: histogram, separateChannels: false, mode: .rgb, logScale: false )
        Divider()
        HistogramView( histogram: histogram, separateChannels: true,  mode: .rgb, logScale: false )
        Divider()
        HistogramView( histogram: histogram, separateChannels: false, mode: .luma, logScale: true )
    }
    .frame( maxWidth: .infinity, alignment: .leading )
    .frame( maxHeight: .infinity, alignment: .top )
    .padding()
}
