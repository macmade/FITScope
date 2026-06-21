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

import SwiftUI

/// The right inspector: a scrolling stack of styled sections wrapping the
/// existing adjustment controls plus statistics. Color-map controls are
/// deferred and shown as a placeholder.
public struct InspectorView: View
{
    /// The image whose renderer/adjustments the controls bind to.
    @ObservedObject private var image: FITSImage

    /// The controls' identity token. Reset View replaces it with a fresh value to
    /// recreate the controls so they reseed from the just-defaulted adjustments:
    /// reset mutates the adjustments in place — the same object, same image —
    /// which on its own would not refresh the controls' own `@State`.
    @State private var controlsID = UUID()

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
                        InspectorSectionView( "Histogram", identifier: AccessibilityIdentifier.InspectorView.Section.histogram )
                        {
                            HistogramControlView( histogram: result.histogram, statistics: result.statistics, original: self.image.renderer.original )
                        }

                        Divider()
                    }

                    InspectorSectionView( "Stretch", identifier: AccessibilityIdentifier.InspectorView.Section.stretch )
                    {
                        StretchControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                    }

                    Divider()

                    InspectorSectionView( "Gamma", identifier: AccessibilityIdentifier.InspectorView.Section.gamma )
                    {
                        GammaCorrectionControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                    }

                    Divider()

                    InspectorSectionView( "White Balance", identifier: AccessibilityIdentifier.InspectorView.Section.whiteBalance )
                    {
                        WhiteBalanceControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                    }

                    Divider()

                    // The debayer controls only apply to a colour-filter-array
                    // image; a monochrome file has no Bayer pattern to act on, so
                    // the section is hidden entirely for it.
                    if self.image.info.isColorFilterArray
                    {
                        InspectorSectionView( "Debayer", identifier: AccessibilityIdentifier.InspectorView.Section.debayer )
                        {
                            DebayerControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                        }

                        Divider()
                    }

                    InspectorSectionView( "Color", identifier: AccessibilityIdentifier.InspectorView.Section.color )
                    {
                        ColorControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                    }

                    Divider()

                    Button( action: self.reset )
                    {
                        Label( "Reset View", systemImage: "arrow.counterclockwise" )
                            .frame( maxWidth: .infinity )
                    }
                    .padding( 14 )
                    .accessibilityIdentifier( AccessibilityIdentifier.InspectorView.resetButton )
                }
            }
            // The controls drive the render, so lock them while one is in flight;
            // they re-enable as soon as the render commits. Applied to the content
            // stack rather than the scroll view, so it still scrolls meanwhile.
            .disabled( self.image.renderer.isRendering )
            // Reset View replaces this, recreating the controls so they reseed
            // from the freshly-defaulted adjustments.
            .id( self.controlsID )
        }
        .accessibilityIdentifier( AccessibilityIdentifier.InspectorView.container )
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
        current.invert       = defaults.invert
        current.debayer      = defaults.debayer

        // Recreate the controls so they reseed from the now-default adjustments;
        // they cache their displayed state in @State, which the in-place mutation
        // above does not refresh on its own.
        self.controlsID = UUID()

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
