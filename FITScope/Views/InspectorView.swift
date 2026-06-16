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

import SwiftUI

/// The right inspector: a scrolling stack of styled sections wrapping the
/// existing adjustment controls plus statistics. Color-map controls are
/// deferred and shown as a placeholder.
public struct InspectorView: View
{
    /// The image whose renderer/adjustments the controls bind to.
    @ObservedObject private var image: FITSImage

    /// Creates the inspector.
    ///
    /// - Parameter image: The image to inspect and adjust.
    public init( image: FITSImage )
    {
        self.image = image
    }

    /// The view's content.
    public var body: some View
    {
        ScrollView
        {
            VStack( spacing: 0 )
            {
                if self.image.renderer.error != nil
                {
                    self.errorPlaceholder
                }
                else
                {
                    if let result = self.image.renderer.result
                    {
                        InspectorSectionView( "Histogram" )
                        {
                            HistogramControlView( histogram: result.histogram, statistics: result.statistics, original: self.image.renderer.original )
                        }

                        Divider()
                    }

                    InspectorSectionView( "Stretch" )
                    {
                        StretchControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                    }

                    Divider()

                    InspectorSectionView( "Gamma" )
                    {
                        GammaCorrectionControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                    }

                    Divider()

                    InspectorSectionView( "White Balance" )
                    {
                        WhiteBalanceControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                    }

                    Divider()

                    InspectorSectionView( "Debayer" )
                    {
                        DebayerControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                    }

                    Divider()

                    InspectorSectionView( "Color" )
                    {
                        Text( "Color map, invert and high contrast are not yet available." )
                            .font( .system( size: 10 ) )
                            .foregroundStyle( .tertiary )
                            .frame( maxWidth: .infinity, alignment: .leading )
                            .padding( 10 )
                            .background( RoundedRectangle( cornerRadius: 8 ).strokeBorder( .quaternary, style: StrokeStyle( lineWidth: 1, dash: [ 3 ] ) ) )
                    }

                    Divider()

                    Button( action: self.reset )
                    {
                        Label( "Reset View", systemImage: "arrow.counterclockwise" )
                            .frame( maxWidth: .infinity )
                    }
                    .padding( 14 )
                }
            }
        }
    }

    /// Shown when the image failed to render: no controls, just a note.
    private var errorPlaceholder: some View
    {
        InspectorPlaceholderView()
    }

    /// Requests a debounced re-render after an adjustment change.
    private func reRender()
    {
        self.image.renderer.scheduleReRender()
    }

    /// Resets all adjustments to their defaults and re-renders.
    private func reset()
    {
        let defaults = ImageAdjustments()
        let current  = self.image.renderer.adjustments

        current.normalize    = defaults.normalize
        current.stretch      = defaults.stretch
        current.gamma        = defaults.gamma
        current.whiteBalance = defaults.whiteBalance
        current.debayer      = defaults.debayer

        self.reRender()
    }
}

#Preview
{
    if let image = PreviewHelper.image( file: .M42 )
    {
        InspectorView( image: image )
            .frame( width: 255 )
            .task
            {
                await image.renderer.render()
            }
    }
    else
    {
        Text( "Sample image unavailable." )
    }
}
