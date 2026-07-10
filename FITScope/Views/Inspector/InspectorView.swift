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
    @ObservedObject private var image: LoadedImage

    /// The adjustments the controls edit, observed directly so the per-section
    /// reset buttons in the section headers track edits made anywhere (a control,
    /// the Image menu, a Reset) and appear or disappear as each section crosses its
    /// defaults. Safe to hold: the image (and its renderer) is fixed for this
    /// view's lifetime — ``InspectorColumnView`` gives the inspector a fresh
    /// identity per image.
    @ObservedObject private var adjustments: ImageAdjustments

    /// Opens the singleton Levels editor window.
    @Environment( \.openWindow ) private var openWindow

    /// Creates the inspector.
    ///
    /// - Parameter image: The image to inspect and adjust.
    public init( image: LoadedImage )
    {
        self.image       = image
        self.adjustments = image.renderer.adjustments
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
                    // The histogram needs the first render result; until it is
                    // ready, a same-height placeholder holds the section's space so
                    // the controls below it do not shift when the histogram appears.
                    InspectorSectionView( "Histogram", identifier: AccessibilityIdentifier.InspectorView.Section.histogram )
                    {
                        if let result = self.image.renderer.result
                        {
                            HistogramControlView( histogram: result.histogram, statistics: result.statistics, original: self.image.renderer.original, options: self.image.histogramOptions )
                        }
                        else
                        {
                            HistogramPlaceholderView()
                        }
                    }

                    Divider()

                    // Orientation (framing) is surfaced near the top so the image
                    // can be squared up before any tonal work, even though the
                    // pipeline applies it last.
                    InspectorSectionView(
                        "Orientation",
                        identifier:      AccessibilityIdentifier.InspectorView.Section.orientation,
                        isModified:      self.adjustments.isModified( \.orientation ),
                        resetIdentifier: AccessibilityIdentifier.InspectorView.SectionReset.orientation,
                        onReset:         { self.reset( \.orientation ) }
                    )
                    {
                        OrientationControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                    }

                    Divider()

                    // From here down the sections follow the order the pipeline
                    // applies them (see ImageProcessor / PixelPipeline): debayer,
                    // white balance, brightness/contrast, stretch, gamma, then
                    // levels & curves, saturation and invert.
                    //
                    // The debayer controls only apply to a colour-filter-array
                    // image; a monochrome file has no Bayer pattern to act on, so
                    // the section is hidden entirely for it.
                    if self.image.isColorFilterArray
                    {
                        InspectorSectionView(
                            "Debayer",
                            identifier:      AccessibilityIdentifier.InspectorView.Section.debayer,
                            isModified:      self.adjustments.isModified( \.debayer ) || self.adjustments.isModified( \.debayerAlgorithm ),
                            resetIdentifier: AccessibilityIdentifier.InspectorView.SectionReset.debayer,
                            onReset:         self.resetDebayer
                        )
                        {
                            DebayerControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                        }

                        Divider()
                    }

                    InspectorSectionView(
                        "White Balance",
                        identifier:      AccessibilityIdentifier.InspectorView.Section.whiteBalance,
                        isModified:      self.adjustments.isModified( \.whiteBalance ),
                        resetIdentifier: AccessibilityIdentifier.InspectorView.SectionReset.whiteBalance,
                        onReset:         { self.reset( \.whiteBalance ) }
                    )
                    {
                        WhiteBalanceControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                    }

                    Divider()

                    InspectorSectionView( "Brightness & Contrast", identifier: AccessibilityIdentifier.InspectorView.Section.brightnessContrast )
                    {
                        BrightnessContrastControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                    }

                    Divider()

                    InspectorSectionView(
                        "Stretch",
                        identifier:      AccessibilityIdentifier.InspectorView.Section.stretch,
                        isModified:      self.adjustments.isModified( \.stretch ),
                        resetIdentifier: AccessibilityIdentifier.InspectorView.SectionReset.stretch,
                        onReset:         { self.reset( \.stretch ) }
                    )
                    {
                        StretchControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender, autoScreenTransfer: { await self.image.renderer.autoScreenTransfer() }, canAutoScreenTransfer: { self.image.renderer.canAutoScreenTransfer } )
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

                    // The colour-grading controls apply to any colour image — a
                    // debayered colour-filter array or combined RGB planes — but not
                    // a monochrome file, which has no colour to scale, so the sections
                    // are hidden for it.
                    if self.image.isColor
                    {
                        InspectorSectionView(
                            "Color Balance",
                            identifier:      AccessibilityIdentifier.InspectorView.Section.colorBalance,
                            isModified:      self.adjustments.isModified( \.colorBalance ),
                            resetIdentifier: AccessibilityIdentifier.InspectorView.SectionReset.colorBalance,
                            onReset:         { self.reset( \.colorBalance ) }
                        )
                        {
                            ColorBalanceControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                        }

                        Divider()

                        InspectorSectionView( "Hue & Saturation", identifier: AccessibilityIdentifier.InspectorView.Section.saturation )
                        {
                            SaturationControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
                        }

                        Divider()
                    }

                    InspectorSectionView(
                        "Color",
                        identifier:      AccessibilityIdentifier.InspectorView.Section.color,
                        isModified:      self.adjustments.isModified( \.invert ),
                        resetIdentifier: AccessibilityIdentifier.InspectorView.SectionReset.color,
                        onReset:         { self.reset( \.invert ) }
                    )
                    {
                        ColorControlView( adjustments: self.image.renderer.adjustments, reRender: self.reRender )
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
            // No reseed identity here: the controls observe the shared adjustments
            // directly, and this view observes them too (for the per-section reset
            // buttons), so a change from outside the inspector (a menu-driven Reset
            // View or Invert) updates the displayed state on its own. Per-image
            // identity is handled one level up, in InspectorColumnView.
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

    /// Resets a single adjustment field to its default and re-renders — the action
    /// behind a per-section reset button.
    ///
    /// - Parameter keyPath: The adjustment field to reset.
    private func reset< Value >( _ keyPath: ReferenceWritableKeyPath< ImageAdjustments, Value > )
    {
        self.adjustments.reset( keyPath )

        self.reRender()
    }

    /// Resets the debayer section — both the pattern selection and the demosaic
    /// algorithm — to their defaults and re-renders.
    private func resetDebayer()
    {
        self.adjustments.reset( \.debayer )
        self.adjustments.reset( \.debayerAlgorithm )

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
