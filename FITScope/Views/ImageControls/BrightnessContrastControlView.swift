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

/// The brightness/contrast section of the controls panel: a brightness slider
/// and a contrast slider, both centred on their neutral value.
public struct BrightnessContrastControlView: View
{
    /// The brightness slider bounds (neutral at `0`).
    static let minimumBrightness = -1.0
    static let maximumBrightness =  1.0

    /// The contrast slider bounds (neutral at `1`, `0` flattens to mid-gray).
    static let minimumContrast = 0.0
    static let maximumContrast = 2.0

    /// The shared adjustment values this control observes and writes to.
    @ObservedObject private var adjustments: ImageAdjustments

    /// Requests a debounced re-render after a change.
    private let reRender: () -> Void

    /// Creates the brightness/contrast control.
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
            SliderGridRowView( value: self.$adjustments.brightness, minimumValue: Self.minimumBrightness, maximumValue: Self.maximumBrightness, label: "Brightness", image: "sun.max.fill", defaultValue: 0, resetIdentifier: AccessibilityIdentifier.BrightnessContrastControlView.brightnessReset )
                .accessibilityIdentifier( AccessibilityIdentifier.BrightnessContrastControlView.brightnessSlider )
                .help( "Brightness Offset" )

            SliderGridRowView( value: self.$adjustments.contrast, minimumValue: Self.minimumContrast, maximumValue: Self.maximumContrast, label: "Contrast", image: "circle.lefthalf.filled", defaultValue: 1, resetIdentifier: AccessibilityIdentifier.BrightnessContrastControlView.contrastReset )
                .accessibilityIdentifier( AccessibilityIdentifier.BrightnessContrastControlView.contrastSlider )
                .help( "Contrast Around the Midpoint" )
        }
        // The sliders bind straight to the observed adjustments, so re-render on
        // any change to either value — from this control or from a Reset.
        .onChange( of: [ self.adjustments.brightness, self.adjustments.contrast ] )
        {
            self.reRender()
        }
    }
}

#Preview
{
    BrightnessContrastControlView( adjustments: ImageAdjustments(), reRender: {} )
        .frame( maxWidth: .infinity, alignment: .leading )
        .frame( maxHeight: .infinity, alignment: .top )
        .padding()
}
