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

/// The colour section of the controls panel: a hue slider and a saturation
/// slider, each centred on its neutral value. They are ordered top-to-bottom to
/// match the processing pipeline, which rotates hue before scaling saturation.
/// Shown only for colour images (see ``InspectorView``).
public struct SaturationControlView: View
{
    /// The hue slider bounds, in degrees (neutral at `0`, a full turn either way).
    static let minimumHue = -180.0
    static let maximumHue =  180.0

    /// The saturation slider bounds (neutral at `1`, `0` desaturates to gray).
    static let minimumSaturation = 0.0
    static let maximumSaturation = 2.0

    /// The shared adjustment values this control observes and writes to.
    @ObservedObject private var adjustments: ImageAdjustments

    /// Requests a debounced re-render after a change.
    private let reRender: () -> Void

    /// Creates the saturation control.
    ///
    /// - Parameters:
    ///   - adjustments: The shared adjustment values to observe and write to.
    ///   - reRender:    The closure to call after a change.
    public init( adjustments: ImageAdjustments, reRender: @escaping () -> Void )
    {
        self.adjustments = adjustments
        self.reRender    = reRender
    }

    /// The view's content.
    public var body: some View
    {
        Grid( alignment: .leading )
        {
            SliderGridRowView( value: self.$adjustments.hue, minimumValue: Self.minimumHue, maximumValue: Self.maximumHue, label: "Hue", image: "camera.filters", defaultValue: 0, resetIdentifier: AccessibilityIdentifier.SaturationControlView.hueReset )
                .accessibilityIdentifier( AccessibilityIdentifier.SaturationControlView.hueSlider )
                .help( "Hue Rotation" )

            SliderGridRowView( value: self.$adjustments.saturation, minimumValue: Self.minimumSaturation, maximumValue: Self.maximumSaturation, label: "Saturation", image: "paintpalette.fill", defaultValue: 1, resetIdentifier: AccessibilityIdentifier.SaturationControlView.reset )
                .accessibilityIdentifier( AccessibilityIdentifier.SaturationControlView.slider )
                .help( "Colour Saturation" )
        }
        // The sliders bind straight to the observed adjustments, so re-render on
        // any change to either value — from these controls or from a Reset.
        .onChange( of: self.adjustments.hue )
        {
            self.reRender()
        }
        .onChange( of: self.adjustments.saturation )
        {
            self.reRender()
        }
    }
}

#Preview( "Default" )
{
    SaturationControlView( adjustments: ImageAdjustments(), reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}

#Preview( "Modified" )
{
    let adjustments = ImageAdjustments()

    adjustments.saturation = 1.5
    adjustments.hue        = 45

    return SaturationControlView( adjustments: adjustments, reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}
