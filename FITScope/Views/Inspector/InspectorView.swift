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

    /// Opens the singleton Levels editor window.
    @Environment( \.openWindow ) private var openWindow

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
                            HistogramControlView( histogram: result.histogram, statistics: result.statistics, original: self.image.renderer.original, options: self.image.histogramOptions )
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

                    InspectorSectionView( "Brightness & Contrast", identifier: AccessibilityIdentifier.InspectorView.Section.brightnessContrast )
                    {
                        BrightnessContrastControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                    }

                    Divider()

                    InspectorSectionView( "Levels & Curves", identifier: AccessibilityIdentifier.InspectorView.Section.levelsCurves )
                    {
                        HStack
                        {
                            Button
                            {
                                self.openWindow( id: "LevelsWindow" )
                            }
                            label:
                            {
                                Label( "Levels\u{2026}", systemImage: "slider.horizontal.below.rectangle" )
                                    .frame( maxWidth: .infinity )
                            }
                            .accessibilityIdentifier( AccessibilityIdentifier.InspectorView.openLevelsButton )
                            .help( "Open the Levels Editor" )

                            Button
                            {
                                self.openWindow( id: "CurvesWindow" )
                            }
                            label:
                            {
                                Label( "Curves\u{2026}", systemImage: "point.topleft.down.to.point.bottomright.curvepath" )
                                    .frame( maxWidth: .infinity )
                            }
                            .accessibilityIdentifier( AccessibilityIdentifier.InspectorView.openCurvesButton )
                            .help( "Open the Curves Editor" )
                        }
                    }

                    Divider()

                    // Saturation only applies to a colour image; a monochrome file
                    // has no colour to scale, so the section is hidden for it (as
                    // with the debayer section).
                    if self.image.info.isColorFilterArray
                    {
                        InspectorSectionView( "Saturation", identifier: AccessibilityIdentifier.InspectorView.Section.saturation )
                        {
                            SaturationControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                        }

                        Divider()
                    }

                    InspectorSectionView( "Color", identifier: AccessibilityIdentifier.InspectorView.Section.color )
                    {
                        ColorControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                    }

                    Divider()

                    InspectorSectionView( "Orientation", identifier: AccessibilityIdentifier.InspectorView.Section.orientation )
                    {
                        OrientationControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                    }

                    Divider()

                    Button( action: self.image.resetAdjustments )
                    {
                        Label( "Reset View", systemImage: "arrow.counterclockwise" )
                            .frame( maxWidth: .infinity )
                    }
                    .padding( 14 )
                    .accessibilityIdentifier( AccessibilityIdentifier.InspectorView.resetButton )
                    .help( "Reset All Adjustments to Their Defaults" )
                }
            }
            // The controls drive the render, so lock them while one is in flight;
            // they re-enable as soon as the render commits. Applied to the content
            // stack rather than the scroll view, so it still scrolls meanwhile.
            .disabled( self.image.renderer.isRendering )
            // Recreate the controls when an adjustment is changed from outside the
            // inspector (a menu-driven Reset View or Invert bumps the image's
            // controls revision), so they reseed from the changed adjustments —
            // the controls cache their displayed state in @State, which an
            // in-place mutation does not refresh on its own.
            .id( self.image.controlsRevision )
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
